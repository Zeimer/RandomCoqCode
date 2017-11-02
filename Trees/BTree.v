Require Import Coq.Program.Wf.
Require Export Compare_dec.
Require Export Arith.
Require Export Classes.EquivDec.
Require Import List.
Import ListNotations.

Set Implicit Arguments.

Inductive BTree (A : Type) : Type :=
    | empty : BTree A
    | node : A -> BTree A -> BTree A -> BTree A.

Arguments empty [A].
Arguments node [A] _ _ _.

Fixpoint len {A : Type} (bt : BTree A) : nat :=
match bt with
    | empty => 0
    | node _ l r => S (len l + len r)
end.

Lemma len_swap :
  forall (A : Type) (v : A) (l r : BTree A),
    len (node v l r) = len (node v r l).
Proof.
  intros. cbn. rewrite plus_comm. trivial.
Qed.

Definition root {A : Type} (bt : BTree A) : option A :=
match bt with
    | empty => None
    | node v l r => Some v
end.

Fixpoint map {A B : Type} (f : A -> B) (bt : BTree A) : BTree B :=
match bt with
    | empty => empty
    | node v l r => node (f v) (map f l) (map f r)
end.

From mathcomp Require Import ssreflect.

Theorem map_pres_len : forall (A B : Type) (f : A -> B) (bt : BTree A),
    len bt = len (map f bt).
Proof.
  induction bt as [| v l Hl r Hr]; intros.
    trivial.
    simpl. f_equal. rewrite <- Hl, <- Hr. trivial.
Restart.
  intros. elim: bt => //= v l -> r -> //=. 
Qed.

Fixpoint combine {A B : Type} (ta : BTree A) (tb : BTree B)
    : BTree (A * B) :=
match ta, tb with
    | empty, _ => empty
    | _, empty => empty
    | node v1 l1 r1, node v2 l2 r2 => node (v1, v2) (combine l1 l2) (combine r1 r2)
end.

Definition l1 := [3; 0; 1; 34; 19; 44; 21; 65; 5].
Definition l2 := [4; 6; 0; 99; 3; 12].

Fixpoint fold {A B : Set} (op : A -> B -> B -> B) (b : B) (bt : BTree A)
    : B :=
match bt with
    | empty => b
    | node v l r => op v (fold op b l) (fold op b r)
end.

Definition bool_to_nat (b : bool) : nat :=
match b with
    | true => 1
    | false => 0
end.

Definition len_fold {A : Set} := @fold A nat (fun _ l r => 1 + l + r) 0.
Definition sum_fold := fold (fun v l r => v + l + r) 0.
Definition find_fold (n : nat) : BTree nat -> bool :=
    fold (fun v l r => orb (beq_nat v n) (orb l r)) false.
Definition count_fold (n : nat) : BTree nat -> nat :=
    fold (fun v l r => bool_to_nat (beq_nat v n) + l + r) 0.
Definition map_fold {A B : Set} (f : A -> B) : BTree A -> BTree B :=
    fold (fun v l r => node (f v) l r) empty.

(*Definition t1 : BTree nat := fromList leb l1.

Eval compute in l1.
Eval compute in length l1.
Eval compute in t1.
Eval compute in map (fun x => x + 1) t1.
Eval compute in map_fold (fun x => x + 1) t1.
Eval compute in len_fold t1.
Eval compute in sum_fold t1.
Eval compute in find_fold 0 t1.
Eval compute in count_fold 0 t1.*)

Inductive elem {A : Type} (a : A) : BTree A -> Prop :=
    | elem_root : forall l r : BTree A, elem a (node a l r)
    | elem_left : forall (v : A) (l r : BTree A),
        elem a l -> elem a (node v l r)
    | elem_right : forall (v : A) (l r : BTree A),
        elem a r -> elem a (node v l r).

Hint Constructors elem.

Theorem elem_dec :
  forall {A : Type} {dec : EqDec A eq} (a : A) (t : BTree A),
    {elem a t} + {~ elem a t}.
Proof.
  induction t as [| v l IHl r IHr].
    right. intro. inversion H.
    case (dec a v); intro.
      left. rewrite <- e. constructor.
      destruct IHl as [IHl1 | IHl2].
        left. apply elem_left. assumption.
        destruct IHr as [IHr1 | IHr2].
          left. apply elem_right; assumption.
          right. intro. inversion H; contradiction.
Restart.
  intros. elim: t => [| v l [Hl | Hl] r [Hr | Hr]]; auto.
    right. inversion 1.
    case: (dec a v) => H; [left | right].
      by rewrite H.
      by inversion 1.
Defined.

Fixpoint toList {A : Type} (t : BTree A) : list A :=
match t with
    | empty => []
    | node v l r => toList l ++ v :: toList r
end.

Lemma elem_In :
  forall (A : Type) (x : A) (t : BTree A),
    In x (toList t) <-> elem x t.
Proof.
  split.
    elim: t x => [| v l Hl r Hr] x H.
      inversion H.
      cbn in H. apply in_app_or in H. do 2 (destruct H; subst; auto).
    elim: t x => [| v l Hl r Hr] x H //=; inversion H; subst;
    apply in_or_app; cbn; eauto.
Qed.