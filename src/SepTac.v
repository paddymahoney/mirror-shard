Require Import IL SepIL SymIL.
Require Import Word Memory.
Import List.
Require Import DepList EqdepClass.

Require Expr SepExpr.
Require Import Provers.
Module SEP := SymIL.BedrockEvaluator.SEP.

(** TODO : this isn't true **)
Lemma ApplyCancelSep : forall types funcs,
  forall (prover : ProverT types), ProverT_correct prover funcs ->
    forall pcT stT uvars (hyps : list (Expr.expr types)) sfuncs
  (l r : SEP.sexpr types pcT stT),
  Expr.AllProvable funcs uvars nil hyps ->
  forall cs, 
  match SEP.CancelSep sfuncs prover hyps l r with
    | {| SepExpr.r_vars := vars; 
         SepExpr.r_lhs := lhs; SepExpr.r_rhs_ex := rhs_ex; 
         SepExpr.r_rhs := rhs; SepExpr.r_SUBST := SUBST |} =>
      SEP.forallEach vars
        (fun VS : Expr.env types =>
          SEP.exists_subst funcs VS uvars
          (ExprUnify.env_of_Subst SUBST rhs_ex 0)
          (fun rhs_ex0 : Expr.env types =>
            SEP.himp funcs sfuncs nil rhs_ex0 VS cs lhs rhs))
  end ->
  himp cs (@SEP.sexprD _ funcs _ _ sfuncs nil nil l)
          (@SEP.sexprD _ funcs _ _ sfuncs uvars nil r).
Proof.
  intros; eapply SEP.ApplyCancelSep; eauto.
Qed.

Require Import PropX.

Lemma interp_interp_himp : forall cs P Q stn_st,
  interp cs (![ P ] stn_st) ->
  (himp cs P Q) ->
  interp cs (![ Q ] stn_st).
Proof.
  unfold himp. intros. destruct stn_st.
  rewrite sepFormula_eq in *. unfold sepFormula_def in *. simpl in *.
  eapply Imply_E; eauto. 
Qed.

Theorem change_Imply_himp : forall (specs : codeSpec W (settings * state)) p q s,
  himp specs p q
  -> interp specs (![p] s ---> ![q] s)%PropX.
Proof.
  rewrite sepFormula_eq.
  unfold himp, sepFormula_def.
  eauto.
Qed.

Lemma ignore_regs : forall p specs stn st rs,
  interp specs (![ p ] (stn, st))
  -> interp specs (![ p ] (stn, {| Regs := rs; Mem := Mem st |})).
Proof.
  rewrite sepFormula_eq; auto.
Qed.

Ltac change_to_himp := try apply ignore_regs;
  match goal with
    | [ H : interp ?specs (![ _ ] ?X)
      |- interp ?specs (![ _ ] ?X) ] =>
    eapply (@interp_interp_himp _ _ _ _ H)
    | _ => apply change_Imply_himp
  end.

(** The parameters are the following.
 ** - [isConst] is an ltac [* -> bool]
 ** - [prover] is a value of type [forall ts (fs : functions ts), ProverT_correct ts P fs]
 ** - [simplifier] is an ltac that simplifies the goal after the cancelation
 ** - [Ts] is a value of type [list Type] or [tt]
 **)
Ltac sep_canceler isConst prover simplifier Ts :=
  (try change_to_himp) ;
  match goal with 
    | [ |- himp ?cs ?L ?R ] =>
      let pcT := constr:(W) in
      let stateT := constr:(prod settings state) in
      let all_props := Expr.collect_props ltac:(fun _ => true) in
      let pures := Expr.props_types all_props in
       let L := eval unfold starB exB hvarB in L in
      let R := eval unfold starB exB hvarB in R in
      (** collect types **)
      let Ts := 
        match Ts with
          | tt => constr:(@nil Type) 
          | _ => Ts
        end
      in
      let Ts := Expr.collectTypes_exprs ltac:(isConst) pures Ts in
      SEP.collectTypes_sexpr ltac:(isConst) L Ts ltac:(fun Ts =>
      SEP.collectTypes_sexpr ltac:(isConst) R Ts ltac:(fun Ts =>
      (** check for potential universe inconsistencies **)
      match Ts with
        | context [ PropX.PropX ] => 
          fail 1000 "found PropX in types list"
            "(this causes universe inconsistencies)"
        | context [ PropX.spec ] => 
          fail 1000 "found PropX in types list"
            "(this causes universe inconsistencies)"
        | _ => idtac
      end ;
      (** elaborate the types **)
      let types_ := eval unfold bedrock_types in bedrock_types in
      let types_ := Expr.extend_all_types Ts types_ in
      let typesV := fresh "types" in
      pose (typesV := types_);
(*
      let types_ext := eval simpl in (bedrock_ext types_) in
      let types_extV := fresh "types_ext" in
      pose (types_extV := types_ext);
*)
      (** build the variables **)
      let uvars := eval simpl in (@nil _ : Expr.env typesV) in
      let vars := eval simpl in (@nil _ : Expr.env typesV) in
      (** build the funcs **)
      let funcs := 
        eval unfold SymIL.BedrockEvaluator.bedrock_funcs in (SymIL.BedrockEvaluator.bedrock_funcs typesV)
      in
      let funcs := eval simpl in funcs in
      let pcT := constr:(SymIL.BedrockEvaluator.pcT) in
      let stT := constr:(SymIL.BedrockEvaluator.stT) in
      (** build the base sfunctions **)
      let sfuncs := constr:(@nil (@SEP.ssignature typesV pcT stT)) in
      Expr.reify_exprs ltac:(isConst) pures typesV funcs uvars vars ltac:(fun uvars funcs pures =>
        let proofs := Expr.props_proof all_props in
      SEP.reify_sexpr ltac:(isConst) L typesV funcs pcT stT sfuncs uvars vars ltac:(fun uvars funcs sfuncs L =>
      SEP.reify_sexpr ltac:(isConst) R typesV funcs pcT stT sfuncs uvars vars ltac:(fun uvars funcs sfuncs R =>
        let proverC := prover typesV funcs in
        (idtac "trying to apply" ;
          (** TODO: for some reason the partial application to proofs doesn't always work... **)
         apply (@ApplyCancelSep typesV funcs _ proverC pcT stT uvars pures sfuncs L R proofs);
         subst typesV ;
         idtac "goign to simplify" ;
         simplifier ;
         idtac "done simplify" ;
         repeat match goal with
                  | [ |- _ = _ /\ _ ] => split; [ reflexivity | ]
                  | _ => reflexivity
                end)
        || (idtac "failed to apply, generalizing instead!" ; 
            first [ generalize (@ApplyCancelSep typesV funcs _ proverC pcT stT uvars pures sfuncs L R proofs)
              | generalize (@ApplyCancelSep typesV funcs _ proverC pcT stT uvars pures sfuncs L R); generalize proofs
              | generalize (@ApplyCancelSep typesV funcs _ proverC pcT stT uvars pures sfuncs)
              | generalize (@ApplyCancelSep typesV funcs _ proverC pcT stT uvars pures)
              | generalize (@ApplyCancelSep typesV funcs _ proverC pcT stT uvars)
              | generalize (@ApplyCancelSep typesV funcs _ proverC pcT stT) ])
        )))))
    | [ |- ?G ] => 
      idtac "no match" G 
  end.

Ltac cancel_simplifier :=
  cbv beta iota zeta delta 
      [ SEP.CancelSep
        SEP.hash SEP.hash' SEP.sepCancel

        SepExpr.FM.fold

        Provers.Facts Provers.Summarize Provers.Prove Provers.Learn

        ExprUnify.Subst

        SymIL.bedrock_types SymIL.bedrock_types_r
        SymIL.BedrockEvaluator.bedrock_funcs SymIL.BedrockEvaluator.bedrock_funcs_r
        app map fold_right nth_error value error

        fst snd

        SepExpr.impures SEP.star_SHeap SepExpr.FM.empty SEP.liftSHeap
        SEP.sheapSubstU ExprUnify.empty_Subst

        SepExpr.pures SepExpr.impures SepExpr.other

        SEP.exists_subst ExprUnify.env_of_Subst

        SEP.multimap_join SepExpr.FM.add SepExpr.FM.find SepExpr.FM.map

        SEP.unify_remove_all SEP.unify_remove

        SEP.unifyArgs
        ExprUnify.fold_left_2_opt ExprUnify.fold_left_3_opt
        Compare_dec.lt_eq_lt_dec nat_rec nat_rect 

        ExprUnify.exprUnify SEP.substV length
        Expr.liftExpr Expr.exprSubstU
        Peano_dec.eq_nat_dec EquivDec.equiv_dec 
        Expr.EqDec_tvar
        Expr.tvar_rec Expr.tvar_rect
        sumbool_rec sumbool_rect
        eq_rec_r eq_rect eq_rec f_equal eq_sym
        ExprUnify.get_Eq
        Expr.Eq
        EquivDec.nat_eq_eqdec
        Provers.inSameGroup Provers.eqD Provers.eqD_seq Provers.transitivityEqProver
        Provers.groupsOf
        Provers.addEquality
        Provers.in_seq orb
        Expr.typeof 
        Expr.expr_seq_dec
        Expr.tvarD
        Expr.tvar_val_sdec 
        Provers.groupWith
        Expr.Range Expr.Domain Expr.Denotation
(*      Expr.well_typed  *)
        Expr.all2

        SEP.forallEach
        SEP.sheapD SEP.sexprD
        SEP.starred SEP.himp
        Expr.Impl Expr.Impl_ Expr.is_well_typed

        hd hd_error value error tl
        Env.repr_combine Env.default Env.footprint Env.repr' Env.updateAt 
        Expr.Default_signature Env.nil_Repr Expr.EmptySet_type SEP.Default_ssignature

        orb SymIL.BedrockEvaluator.pcT SymIL.BedrockEvaluator.stT
      ].

(*
Require Unfolder.
Module U := Unfolder.Make BedrockHeap ST.
*)

Definition smem_read stn := SepIL.ST.HT.smem_get_word (IL.implode stn).
Definition smem_write stn := SepIL.ST.HT.smem_set_word (IL.explode stn).
