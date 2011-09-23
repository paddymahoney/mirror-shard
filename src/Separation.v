Require Import String.
Require Import Data List.
Require Import SepTheory.

Set Implicit Arugments.
Set Strict Implicit.

Fixpoint prod (ls : list Type) : Type :=
  match ls with
    | nil => unit
    | a :: b => a * prod b
  end%type.

Fixpoint prodN (T : Type) (n : nat) : Type :=
  match n with
    | 0 => unit
    | S n => T * prodN T n
  end%type.

(** Base Types **)
(*
Inductive Typ :=
| List : Typ -> Typ
| Prod : Typ -> Typ -> Typ
| Nat  : Typ
.

Fixpoint denoteTyp (t : Typ) : Type :=
  match t with
    | List t => list (denoteTyp t)
    | Prod l r => denoteTyp l * denoteTyp r
    | Nat => nat
  end%type.

Definition Teq_dec : forall (t1 t2 : Typ), {t1 = t2} + {t1 <> t2}.
decide equality.
Defined.
*)

(** Syntax of Expressions **)
Class Typ : Type :=
{ type : Type }.

Global Instance FunTyp (T1 T2 : Typ) : Typ :=
{ type := @type T1 -> @type T2 }.

Inductive Mem (T : Typ) : list Typ -> Type :=
| MHere : forall R, Mem T (T :: R)
| MNext : forall T' R, Mem T R -> Mem T (T' :: R)
.

Section Expressions.
  Variable Sym : Type.
  Variable Sym_type : Sym -> Typ.

  Inductive Expr (G : list Typ) : Typ -> Type := 
  | Var  : forall T, Mem T G -> Expr G T
  | App  : forall T1 T2, Expr G (FunTyp T1 T2) -> Expr G T1 -> Expr G T2
  | Lit  : forall S : Sym, Expr G (Sym_type S)
  .

  Section Denote.
    Variable Sym_denote : forall S : Sym, @type (Sym_type S).
    
    Fixpoint Env (g : list Typ) : Type :=
      match g with
        | nil => unit
        | a :: b => type * Env b
      end%type.
    
    Fixpoint lookup T (g : list Typ) (m : Mem T g) : Env g -> @type T :=
      match m in Mem _ g return Env g -> @type T with
        | MHere _ => fun x => fst x
        | MNext _ _ r => fun x => lookup T _ r (snd x)
      end.

    Fixpoint denoteExpr G (E : Env G) (T : Typ) (e : Expr G T) : type :=
      match e in Expr _ T return @type T with
        | Var _ v => lookup _ G v E
        | App _ _ f a => (denoteExpr G E _ f) (denoteExpr G E _ a)
        | Lit s => Sym_denote s
      end.
  
  End Denote.
End Expressions.

Definition Expr_dec T g (e1 e2 : Expr g T) : {e1 = e2} + {e1 <> e2}.
decide equality. decide equality. decide equality.
Defined.

(** Separation Formula Syntax **)
Fixpoint vaFun (ls : list Typ) (R : Type) : Type :=
  match ls with
    | nil => R
    | a :: b => denoteTyp a -> vaFun b R
  end.
Fixpoint vaApply (g : list { x : Typ & denoteTyp x }) {ls : list Typ} {R : Type} : vaFun ls R -> list Expr -> option R :=
  match ls as ls return vaFun ls R -> list Expr -> option R with
    | nil => fun f x => match x with 
                          | nil => Some f
                          | _ => None
                        end
    | t :: tr => fun f x => match x with
                              | nil => None
                              | v :: vr => match denoteExpr g t v with
                                             | None => None
                                             | Some v => @vaApply g tr R (f v) vr
                                           end
                            end
  end.

Record Terminal : Type :=
{ types : list Typ
; defn  : vaFun types sprop
}.

Inductive Sep :=
| Emp  : Sep                          (** empty heap **)
| Star : Sep -> Sep -> Sep            (** star **)
| ExS  : Sep -> Sep                   (** existential quantification over separation logic formula **)
| VarS : nat -> Sep                   (** variables of type separation logic formula **)
| ExE  : Typ -> Sep -> Sep            (** variables of expression types **)
| Term : string -> list Expr -> Sep   (** terminals **)
.

Section Denotation.
  Variable G : fmap string (fun _ => Terminal).

  Fixpoint Sep_denote (g : list sprop) (gv : list { x : Typ & denoteTyp x }) (s : Sep) : sprop :=
    match s with
      | Emp => semp
      | Star l r => star (Sep_denote g gv l) (Sep_denote g gv r)
      | Term t args => 
        match lookup _ _ string_dec t G with
          | None => fun _ => False
          | Some t =>
            match vaApply gv (@defn t) args with
              | None => fun _ => False
              | Some x => x
            end
        end
      | ExS b => fun h => exists x : sprop, Sep_denote (x :: g) gv b h
      | ExE t b => fun h => exists x : denoteTyp t, Sep_denote g (@existT _ (fun x => denoteTyp x) t x :: gv) b h
      | VarS n => match nth_error g n with
                    | None => fun _ => False
                    | Some x => x
                  end
    end.
End Denotation.

Definition Terminal_foo : Terminal :=
{| types := Nat :: nil 
 ; defn  := fun v => fun h => h v = Some v
|}.

Definition Terminal_bar : Terminal :=
{| types := nil 
 ; defn  := Sep_denote nil nil nil Emp
|}.

Definition Econs := insert string (fun _ => Terminal) string_dec.

(*
Eval compute in Sep_denote (Econs "foo" Terminal_foo (Econs "bar" Terminal_bar nil))%string nil nil
  (ExS (ExE Nat (Star (VarS 0) (Star (Term "foo" (Var 0 :: nil)) (Term "bar" nil))))).
*)








(*
Record SepState : Type :=
{ stars : mmap SepTerm vaFun ( }.

Parameter SepState_denote : SepState -> Prop.

Fixpoint reflect (s : Sep) (acc : SepState) : SepState :=
  match s with
    | Emp => acc
    | Start l r => 
      reflect r (reflect l acc)
    | App t a =>
  end.
*)