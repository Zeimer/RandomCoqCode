Require Export Coq.Program.Wf.
Require Export Recdef.
Require Export FunInd.

Require Export FunctionalExtensionality.

Require Export Bool.

Require Export Arith.
Require Export Lia.
Require Export Nat.

Require Export Equality.
Require Export Eqdep.

Require Export Permutation.

Require Export List.
Export ListNotations.

Set Implicit Arguments.
Set Universe Polymorphism.

Hint Constructors reflect : core.

(* General useful tactics. *)

Ltac clear_useless :=
repeat match goal with
    | H : ?x = ?x |- _ => clear H
    | H : True |- _ => clear H
    | x : unit |- _ => destruct x
end.

Ltac inv_aux H :=
  inversion H; subst; clear H; auto; try congruence; clear_useless.

Tactic Notation "inv" ident(H) := inv_aux H.

Tactic Notation "inv" integer(n) :=
  intros until n;
match goal with
    | H : _ |- _ => inv_aux H
end.

Ltac gen x := generalize dependent x.

(*Ltac ext x := extensionality x.*)

Tactic Notation "ext" ident(x) := extensionality x.

(* Tactics for easier induction. *)
Ltac term_contains t x :=
match t with
    | x => idtac
    | ?f x => idtac
    | ?f _ => term_contains f x
    | _ => fail
end.

Ltac gen_IH H :=
match reverse goal with
    | H : _ |- _ => fail
    | x : ?Tx |- _ =>
        match type of H with
            | ?TH => term_contains TH x
            | _ => generalize dependent x
        end
end.

Ltac gen_ind H :=
  try intros until H; gen_IH H; induction H; cbn; auto.

Ltac invs := repeat
match goal with
    | H : ?f ?x1 ?x2 ?x3 = ?f ?x1' ?x2' ?x3' |- _ => inv H
    | H : ?f ?x1 ?x2 = ?f ?x1' ?x2' |- _ => inv H
    | H : ?f ?x1 = ?f ?x1' |- _ => inv H
end.

Ltac replace_nonvars H :=
match H with
    | ?f ?x1 => is_var x1; replace_nonvars f
    | ?f ?x1 =>
        let x1' := fresh "x1" in
        let H1 := fresh "H1" in remember x1 as x1' eqn: H1; replace_nonvars f
    | _ => idtac
end.

Ltac clean_eqs := repeat
match goal with
    | H : ?x = ?x |- _ => clear H
    | H : ?x = ?x -> _ |- _ => specialize (H eq_refl)
    | H : forall x, ?y = ?y -> ?P |- _ =>
        assert (H' := fun x => H x eq_refl); clear H; rename H' into H
end.

Ltac ind' H :=
match type of H with
    | ?T => replace_nonvars T; induction H; subst; try congruence;
        invs; clean_eqs; eauto
end.

Ltac ind H := try intros until H; gen_IH H; ind' H.

(* Tactics for reification. *)
Ltac inList x l :=
match l with
    | [] => false
    | x :: _ => true
    | _ :: ?l' => inList x l'
end.

Ltac addToList x l :=
  let b := inList x l in
match b with
    | true => l
    | false => constr:(x :: l)
end.

Ltac lookup x l :=
match l with
    | x :: _ => constr:(0)
    | _ :: ?l' => let n := lookup x l' in constr:(S n)
end.

(* Environments. *)
Definition Env (X : Type) : Type := list X.

Definition holds (n : nat) (env : Env Prop) : Prop := nth n env False.

Definition Proofs : Type := list nat.

Fixpoint allTrue (env : Env Prop) (proofs : Proofs) : Prop :=
match proofs with
    | [] => True
    | h :: t => holds h env /\ allTrue env t
end.

Theorem find_spec :
  forall (n : nat) (env : Env Prop) (proofs : Proofs),
    allTrue env proofs -> In n proofs -> holds n env.
Proof.
  induction proofs as [| h t]; cbn.
    inversion 2.
    do 2 destruct 1; subst.
      unfold holds in H. apply H.
      apply IHt; assumption.
Qed.

(* A type for solving formulas. *)
Inductive solution (P : Prop) : Type :=
    | Yes' : P -> solution P
    | No' : solution P.

Arguments Yes' [P] _.
Arguments No' {P}.

Notation "'Yes'" := (Yes' _).
Notation "'No'" := No'.

Notation "'Reduce' x" := (if x then Yes else No) (at level 50).
Notation "x &&& y" := (if x then Reduce y else No).
Notation "x ||| y" := (if x then Yes else Reduce y).

Definition unwrap {P : Prop} (s : solution P) :=
match s return if s then P else Prop with
    | Yes' p => p
    | _ => True
end.

Ltac inj := repeat
match goal with
    | H : existT _ _ _ = existT _ _ _ |- _ =>
        apply inj_pair2 in H
end; subst.

(* A nice coercion that reconciles three-way and two-way comparisons. *)
Definition comparison2bool (c : comparison) : bool :=
match c with
    | Lt => true
    | Eq => true
    | Gt => false
end.

Coercion comparison2bool : comparison >-> bool.

(* A nice coercion for treating booleans as propositions. *)
Definition bool2Prop (b : bool) : Prop := b = true.

Coercion bool2Prop : bool >-> Sortclass.

Class cmp_spec (A : Type) : Type :=
{
    cmpr      : A -> A -> comparison;
    cmpr_spec :
      forall x y : A, CompareSpec (x = y) (cmpr y x = Gt) (cmpr y x = Lt) (cmpr x y);
    cmp_spec1 :
      forall x y : A, cmpr x y = Eq -> x = y;
    cmp_spec2 :
      forall x y : A, cmpr x y = Lt <-> cmpr y x = Gt;
    cmp_spec3 :
      forall x : A, cmpr x x = Eq;
}.

Coercion cmpr : cmp_spec >-> Funclass.

Lemma cmp_spec_antirefl :
  forall {A : Type} (cmp : A -> A -> comparison),
    (forall x y : A, CompareSpec (x = y) (cmp y x = Gt) (cmp y x = Lt) (cmp x y)) ->
      forall x : A, cmp x x = Lt -> False.
Proof.
  intros. specialize (H x x). inv H.
Qed.

Lemma cmp_spec_asym :
  forall {A : Type} (cmp : A -> A -> comparison),
    (forall x y : A, CompareSpec (x = y) (cmp y x = Gt) (cmp y x = Lt) (cmp x y)) ->
      forall x y : A, cmp x y = Lt -> cmp y x <> Lt.
Proof.
  intros. specialize (H x y). inv H.
Qed.

Lemma cmp_spec_trans :
  forall {A : Type} (cmp : A -> A -> comparison),
    (forall x y : A, CompareSpec (x = y) (cmp y x = Gt) (cmp y x = Lt) (cmp x y)) ->
      forall x y z : A, cmp x y = Lt -> cmp y z = Lt -> cmp x z = Lt.
Proof.
  intros A cmp H x y z Hxy Hyz.
  pose (H' := H x z). inv H'.
    pose (H' := H y z). inv H'.
(*    pose (H' := H y z). inv H'.*)
Abort.

Lemma cmp_spec_comparison :
  forall {A : Type} (cmp : A -> A -> comparison),
    (forall x y : A, CompareSpec (x = y) (cmp y x = Gt) (cmp y x = Lt) (cmp x y)) ->
      forall x y z : A, cmp x z = Lt -> cmp x y = Lt \/ cmp y z = Lt.
Proof.
  intros A cmp H x y z Hxz.
  pose (H' := H x y). inv H'. right.
  pose (H' := H y z). inv H'.
  pose (H' := H x z). inv H'.
Abort.

Lemma cmp_spec_connectedness :
  forall {A : Type} (cmp : A -> A -> comparison),
    (forall x y : A, CompareSpec (x = y) (cmp y x = Gt) (cmp y x = Lt) (cmp x y)) ->
      forall x y : A, cmp x y <> Lt -> cmp y x <> Lt -> cmp x y = Eq.
Proof.
  intros A cmp H x y Hxy Hyx.
  pose (H' := H x y). inv H'.
Qed.