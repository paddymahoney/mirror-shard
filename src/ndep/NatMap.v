Require Import OrderedType. 

Module Ordered_nat <: OrderedType with Definition t := nat.
  Definition t := nat.
  Definition eq := @eq nat. 
  Definition lt := @lt.

  About OrderedType.OrderedType.

  Theorem eq_refl : forall x, eq x x.
    reflexivity.
  Qed.

  Theorem eq_sym : forall a b, eq a b -> eq b a.
    intros; symmetry; auto.
  Qed.    

  Theorem eq_trans : forall a b c, eq a b -> eq b c -> eq a c.
    intros; etransitivity; eauto.
  Qed.

  Require Import Omega.
  Theorem lt_trans : forall a b c, lt a b -> lt b c -> lt a c.
    intros. unfold lt in *. omega.
  Qed.
     
  Theorem lt_not_eq : forall a b, lt a b -> ~(eq a b).
    unfold eq, lt. intros; omega.
  Qed.

  Definition compare (x y : t) : OrderedType.Compare lt eq x y :=
    match Compare_dec.lt_eq_lt_dec x y with 
      | inleft (left pf) => OrderedType.LT _ pf
      | inleft (right pf) => OrderedType.EQ _ pf
      | inright pf => OrderedType.GT _ pf
    end.

  Definition eq_dec : forall x y : nat, {x = y} + {x <> y} := 
    Peano_dec.eq_nat_dec.

End Ordered_nat.

Require Bedrock.FMapAVL.

Require ZArith.Int.

(*Module IntMap := Bedrock.FMapAVL.Raw ZArith.Int.Z_as_Int Ordered_nat. *)

Module IntMap.

  Section parametric.
    Inductive t (T : Type) : Type := 
    | MLeaf
    | MBranch : t T -> nat -> T -> t T -> t T.

    Context {T : Type}.

    Definition empty : t T := MLeaf _.

    Section add.
      Variable s : nat.
      Variable v : T.

      Fixpoint add m : t T :=
        match m with
          | MLeaf => MBranch _ (MLeaf _) s v (MLeaf _)
          | MBranch l k v' r =>
            match Compare_dec.lt_eq_lt_dec s k with
              | inleft (left _) => MBranch _ (add l) k v' r 
              | inleft (right _) => MBranch _ l k v r 
              | inright _ => MBranch _ l k v' (add r)
            end
        end.
    End add.

    Fixpoint find (s : nat) (m : t T) : option T :=
      match m with
        | MLeaf => None
        | MBranch l k v r =>
          match Compare_dec.lt_eq_lt_dec s k with
            | inleft (left _) => find s l
            | inleft (right _) => Some v
            | inright _ => find s r
          end
      end.

    Fixpoint insert_at_right (m i : t T) : t T :=
      match m with
        | MLeaf => i
        | MBranch l k v r =>
          MBranch _ l k v (insert_at_right r i)
      end.

    Fixpoint remove (s : nat) (m : t T) : t T :=
      match m with
        | MLeaf => m
        | MBranch l k v r =>
          match Compare_dec.lt_eq_lt_dec s k with
            | inleft (left _) => MBranch _ (remove s l) k v r
            | inleft (right _) => insert_at_right l r
            | inright _ => MBranch _ l k v (remove s r)
          end
      end.
  End parametric.
    
  Section Map.
    Context {T U : Type}.
    Variable f : T -> U.

    Fixpoint map (m : t T) : t U :=
      match m with
        | MLeaf => MLeaf _
        | MBranch l k v r =>
          MBranch _ (map l) k (f v) (map r)
      end.
  End Map.

  Section Fold.
    Context {T U : Type}.
    Variable f : nat -> T -> U -> U.

    Fixpoint fold (m : @t T) (acc : U) : U :=
      match m with
        | MLeaf => acc
        | MBranch l k v r =>
          fold r (f k v (fold l acc))
      end.
  End Fold.
End IntMap.

