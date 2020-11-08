Require Import ListLemmas.
Require Export RedBlack.
Require Import Sorting.Sort.

(** Sorting with red-black trees. *)

Definition redblackSort
  {A : Type} (leb : A -> A -> bool) (l : list A) : list A :=
    toList (fromList leb l).

(** Sortedness properties *)

Lemma Sorted_toList :
  forall (A : Ord) (t : RBTree A),
    isBST t -> Sorted trich_le (toList t).
Proof.
  induction t as [| c l Hl v r Hr]; cbn; intros.
    constructor.
    inv H. apply Sorted_app_all; auto.
      case_eq (toList r); intros; subst; auto. constructor.
        apply H6. rewrite <- Elem_toList. rewrite H. cbn. auto.
        rewrite <- H. auto.
      intros. apply Elem_toList in H. auto.
Qed.

Lemma Sorted_redblackSort :
  forall (A : Ord) (l : list A),
    Sorted trich_le (redblackSort trich_leb l).
Proof.
  intros. unfold redblackSort. apply Sorted_toList, isBST_fromList.
Qed.

(** Permutation properties (proved directly). *)

Lemma Permutation_toList_balance :
  forall (A : Type) (c : color) (v : A) (l r : RBTree A),
    Permutation (toList (balance c l v r)) (toList (N c l v r)).
Proof.
  intros.
  functional induction balance c l v r;
  cbn; rewrite <- ?app_assoc; cbn;
  try reflexivity.
    rewrite <- !app_assoc. cbn. reflexivity.
Qed.

Lemma Permutation_toList_ins :
  forall {A : Type} (leb : A -> A -> bool) (x : A) (t : RBTree A),
    Permutation (toList (ins leb x t)) (x :: toList t).
Proof.
  intros. functional induction ins leb x t.
    cbn. reflexivity.
    rewrite Permutation_toList_balance. cbn. rewrite IHr. cbn. reflexivity.
    rewrite Permutation_toList_balance. cbn. rewrite IHr.
      rewrite Permutation_middle. apply Permutation_app.
        reflexivity.
        constructor.
Qed.

Lemma Permutation_toList_insert :
  forall {A : Type} (leb : A -> A -> bool) (x : A) (t : RBTree A),
    Permutation (toList (insert leb x t)) (x :: toList t).
Proof.
  intros. unfold insert. destruct (ins leb x t) eqn: Heq; cbn.
    apply (f_equal (Elem x)) in Heq. cut (@Elem color A x E).
      inv 1.
      rewrite <- Heq. rewrite Elem_ins. left. reflexivity.
    rewrite <- (Permutation_toList_ins leb x t). rewrite Heq.
      cbn. reflexivity.
Qed.

Lemma Permutation_redblackSort :
  forall {A : Type} (leb : A -> A -> bool) (l : list A),
    Permutation (redblackSort leb l) l.
Proof.
  intros. unfold redblackSort.
  induction l as [| h t]; cbn.
    reflexivity.
    rewrite Permutation_toList_insert, IHt. reflexivity.
Qed.

Instance Sort_redblackSort (A : Ord) : Sort trich_le :=
{
    sort := redblackSort trich_leb;
    Sorted_sort := @Sorted_redblackSort A;
    Permutation_sort := @Permutation_redblackSort A trich_leb;
}.

(** Permutation properties proved by way of counting. *)

Lemma countEBT_balance :
  forall (A : Type) (p : A -> bool) (c : color) (v : A) (l r : RBTree A),
    countEBT p (balance c l v r) = countEBT p (N c l v r).
Proof.
  intros.
  functional induction balance c l v r;
  cbn;
  repeat match goal with
      | |- context [if ?p then _ else _] => destruct p
  end;
  lia.
Qed.

Lemma countEBT_makeBlack :
  forall (A : Type) (p : A -> bool) (t : RBTree A),
    countEBT p (makeBlack t) = countEBT p t.
Proof.
  destruct t; reflexivity.
Qed.

Lemma countEBT_ins :
  forall {A : Type} (leb : A -> A -> bool) (p : A -> bool) (x : A) (t : RBTree A),
    countEBT p (ins leb x t) = (if p x then 1 else 0) + countEBT p t.
Proof.
  induction t; cbn;
  try destruct (leb x a);
  rewrite ?countEBT_balance; cbn; rewrite ?IHt1, ?IHt2;
  repeat match goal with
      | |- context [if ?p then _ else _] => destruct p
  end;
  lia.
Qed.

Lemma countEBT_insert :
  forall {A : Type} (leb : A -> A -> bool) (p : A -> bool) (x : A) (t : RBTree A),
    countEBT p (insert leb x t) = (if p x then 1 else 0) + countEBT p t.
Proof.
  intros. unfold insert.
  rewrite countEBT_makeBlack, countEBT_ins. reflexivity.
Qed.

Lemma toList_countEBT :
  forall (A : Type) (p : A -> bool) (t : RBTree A),
    countEBT p t = count p (toList t).
Proof.
  induction t; cbn.
    reflexivity.
    rewrite count_app, IHt1, IHt2.
      cbn. destruct (p a); lia.
Qed.

Lemma countEBT_fromList :
  forall {A : Type} (leb : A -> A -> bool) (p : A -> bool) (l : list A),
    countEBT p (fromList leb l) = count p l.
Proof.
  induction l as [| h t]; cbn; trich;
  rewrite countEBT_insert, IHt.
  destruct (p h); reflexivity.
Qed.

Lemma perm_redblackSort :
  forall {A : Type} (leb : A -> A -> bool) (l : list A),
    perm l (redblackSort leb l).
Proof.
  unfold perm, redblackSort. intros.
  rewrite <- toList_countEBT, countEBT_fromList. reflexivity.
Qed.