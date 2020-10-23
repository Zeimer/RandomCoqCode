Require Export Sorting.Sort.

Set Implicit Arguments.

Function extractMin {A : LinDec} (l : list A) : option (A * list A) :=
match l with
    | [] => None
    | h :: t =>
        match extractMin t with
            | None => Some (h, [])
            | Some (m, l') =>
                if h <=? m then Some (h, m :: l') else Some (m, h :: l')
        end
end.

Function ss {A : LinDec} (l : list A) {measure length l} : list A :=
match extractMin l with
    | None => []
    | Some (m, l') => m :: ss l'
end.
Proof.
  induction l as [| h t]; cbn; intros.
    inv teq.
    destruct (extractMin t) eqn: Heq.
      destruct p0. dec; inv teq; cbn; apply lt_n_S; eapply IHt; eauto.
      inv teq. cbn. apply le_n_S, le_0_n.
Defined.

Lemma Permutation_extractMin :
  forall (A : LinDec) (l l' : list A) (m : A),
    extractMin l = Some (m, l') -> Permutation (m :: l') l.
Proof.
  intros A l. functional induction extractMin l; cbn; inv 1.
    destruct t; cbn in e0.
      reflexivity.
      destruct (extractMin t).
        destruct p. 1-2: dec.
    rewrite Permutation.perm_swap. auto.
Qed.

Lemma Permutation_ss :
  forall (A : LinDec) (l : list A),
    Permutation (ss A l) l.
Proof.
  intros. functional induction @ss A l.
    destruct l; cbn in e.
      reflexivity.
      destruct (extractMin l); try destruct p; dec.
    apply Permutation_extractMin in e. rewrite <- e, IHl0. reflexivity.
Qed.

Lemma extractMin_spec :
  forall (A : LinDec) (l l' : list A) (m : A),
    extractMin l = Some (m, l') -> forall x : A, In x l' -> leq m x.
Proof.
  intros A l.
  functional induction extractMin l; inv 1; cbn; intros; destruct H; subst; dec.
Qed.

Lemma Sorted_ss :
  forall (A : LinDec) (l : list A),
    Sorted A (ss A l).
Proof.
  intros. functional induction @ss A l.
    destruct l; dec.
    apply Sorted_cons.
      intros. assert (In x l').
        apply Permutation_in with (ss A l').
          apply Permutation_ss.
          assumption.
        eapply extractMin_spec; eauto.
      assumption.
Qed.

(** Da ultimate selection sort! *)

Require Import TrichDec.

Function mins'
  {A : TrichDec} (l : list A) : list A * list A :=
match l with
    | [] => ([], [])
    | h :: t =>
        let
          (mins, rest) := mins' t
        in
          match mins with
              | [] => ([h], rest)
              | m :: ms =>
                  match h <?> m with
                      | Lt => ([h], mins ++ rest)
                      | Eq => (h :: mins, rest)
                      | Gt => (mins, h :: rest)
                  end
          end
end.

Lemma mins'_nil :
  forall (A : TrichDec) (l rest : list A),
    mins' l = ([], rest) -> rest = [].
Proof.
  intros. functional induction mins' l; inv H.
Qed.

Lemma mins'_length :
  forall (A : TrichDec) (l mins rest : list A),
    mins' l = (mins, rest) -> length l = length mins + length rest.
Proof.
  intros A l. functional induction mins' l; inv 1; cbn in *.
    destruct t; cbn in e0.
      inv e0.
      destruct (mins' t), l.
        inv e0.
        destruct (c <?> c0); inv e0.
    1-3: f_equal; rewrite (IHp _ _ e0), ?app_length; cbn; lia.
Qed.

Function ss_mins'
  {A : TrichDec} (l : list A) {measure length l} : list A :=
match mins' l with
    | ([], _) => []
    | (mins, rest) => mins ++ ss_mins' rest
end.
Proof.
  intros. functional induction mins' l; inv teq; cbn in *.
    apply mins'_nil in e0. subst. cbn. apply le_n_S, le_0_n.
    all: apply mins'_length in e0; cbn in e0;
      rewrite e0, ?app_length; lia.
Defined.

(** Time to prove something *)

Class Select (A : LinDec) : Type :=
{
    select : list A -> list A * list A * list A;
    select_mins :
      forall l mins rest maxes : list A,
        select l = (mins, rest, maxes) ->
          forall x y : A, In x mins -> In y l -> x ≤ y;
    select_maxes :
      forall l mins rest maxes : list A,
        select l = (mins, rest, maxes) ->
          forall x y : A, In x l -> In y maxes -> x ≤ y;
    select_Permutation :
      forall l mins rest maxes : list A,
        select l = (mins, rest, maxes) ->
          Permutation l (mins ++ rest ++ maxes);
    select_length_rest :
      forall l mins rest maxes : list A,
        select l = (mins, rest, maxes) ->
          mins = [] /\ rest = [] /\ maxes = [] \/
          length rest < length l;
}.

Coercion select : Select >-> Funclass.

Function gss
  {A : LinDec} (s : Select A) (l : list A)
  {measure length l} : list A :=
match select l with
    | ([], [], []) => []
    | (mins, rest, maxes) =>
        mins ++ gss s rest ++ maxes
end.
Proof.
  all: intros; subst;
  apply select_length_rest in teq;
  decompose [and or] teq; clear teq;
  try congruence; try assumption.
Defined.

Lemma Permutation_gss :
  forall (A : LinDec) (s : Select A) (l : list A),
    Permutation (gss s l) l.
Proof.
  intros. functional induction @gss A s l.
    apply select_Permutation in e. cbn in e. symmetry. assumption.
    rewrite IHl0. symmetry. apply select_Permutation. assumption.
Qed.

Lemma select_In :
  forall (A : LinDec) (s : Select A) (l mins rest maxes : list A) (x : A),
    select l = (mins, rest, maxes) ->
      In x mins \/ In x rest \/ In x maxes -> In x l.
Proof.
  intros. eapply Permutation_in.
    symmetry. apply select_Permutation. eassumption.
    apply in_or_app. decompose [or] H0; clear H0.
      left. assumption.
      right. apply in_or_app. left. assumption.
      right. apply in_or_app. right. assumption.
Qed.

Lemma select_mins_maxes :
  forall (A : LinDec) (s : Select A) (l mins rest maxes : list A),
    select l = (mins, rest, maxes) ->
      forall x y : A, In x mins -> In y maxes -> x ≤ y.
Proof.
  intros. eapply select_mins; try eassumption.
  eapply select_In; eauto.
Qed.

Lemma select_mins_same :
  forall (A : LinDec) (s : Select A) (l mins rest maxes : list A),
    select l = (mins, rest, maxes) ->
      forall x y : A, In x mins -> In y mins -> x = y.
Proof.
  intros. apply leq_antisym.
    eapply select_mins; eauto. eapply select_In; eauto.
    eapply select_mins; eauto. eapply select_In; eauto.
Qed.

Lemma select_maxes_same :
  forall (A : LinDec) (s : Select A) (l mins rest maxes : list A),
    select l = (mins, rest, maxes) ->
      forall x y : A, In x maxes -> In y maxes -> x = y.
Proof.
  intros. apply leq_antisym.
    eapply select_maxes; eauto. eapply select_In; eauto.
    eapply select_maxes; eauto. eapply select_In; eauto.
Qed.

Lemma same_Sorted :
  forall (A : LinDec) (x : A) (l : list A),
    (forall y : A, In y l -> x = y) ->
      Sorted A l.
Proof.
  intros A x.
  induction l as [| h t]; cbn; intros.
    constructor.
    specialize (IHt ltac:(auto)). change (Sorted A ([h] ++ t)).
      apply Sorted_app.
        constructor.
        assumption.
        assert (x = h) by auto. inv 1. intro. rewrite (H y).
          dec.
          right. assumption.
Qed.

Lemma Sorted_select_mins :
  forall (A : LinDec) (s : Select A) (l mins rest maxes : list A),
    select l = (mins, rest, maxes) -> Sorted A mins.
Proof.
  destruct mins; intros.
    constructor.
    apply same_Sorted with c. intros. eapply select_mins_same.
      exact H.
      left. reflexivity.
      assumption.
Qed.

Lemma Sorted_select_maxes :
  forall (A : LinDec) (s : Select A) (l mins rest maxes : list A),
    select l = (mins, rest, maxes) -> Sorted A maxes.
Proof.
  destruct maxes; intros.
    constructor.
    apply same_Sorted with c. intros. eapply select_maxes_same.
      exact H.
      left. reflexivity.
      assumption.
Qed.

Lemma gss_In :
  forall (A : LinDec) (s : Select A) (x : A) (l : list A),
    In x (gss s l) <-> In x l.
Proof.
  intros. split; intros.
    eapply Permutation_in.
      apply Permutation_gss.
      assumption.
    eapply Permutation_in.
      symmetry. apply Permutation_gss.
      assumption.
Qed.

Lemma gSorted_ss :
  forall (A : LinDec) (s : Select A) (l : list A),
    Sorted A (gss s l).
Proof.
  intros. functional induction @gss A s l; try clear y.
    constructor.
    apply Sorted_app.
      eapply Sorted_select_mins. eassumption.
      apply Sorted_app.
        assumption.
        eapply Sorted_select_maxes. eassumption.
        intros. rewrite gss_In in H. eapply select_maxes; eauto.
          eapply select_In; eauto.
      intros. apply in_app_or in H0. destruct H0.
        rewrite gss_In in H0. eapply select_mins; try eassumption.
          eapply select_In; eauto.
        eapply select_mins_maxes; eauto.
Qed.

#[refine]
Instance Sort_gss (A : LinDec) (s : Select A) : Sort A :=
{
    sort := gss s;
    Sorted_sort := gSorted_ss s;
}.
Proof.
  intros. apply Permutation_gss.
Defined.

(*Require Import SortSpec.*)

(*
Lemma min_In :
  forall (A : LinDec) (m : A) (l : list A),
    min l = Some m -> In m l.
Proof.
  intros. functional induction min l; cbn; inv H.
Qed.

Lemma lengthOrder_removeFirst_min :
  forall (A : LinDec) (m : A) (l : list A),
    min l = Some m -> lengthOrder (removeFirst m l) l.
Proof.
  intros. functional induction min l; inv H; dec; red; cbn; try lia.
    apply lt_n_S. apply IHo. assumption.
Qed.

#[refine]
Instance Select_min (A : LinDec) : Select A :=
{
    select l :=
      match min l with
          | None => ([], [], [])
          | Some m => ([m], removeFirst m l, [])
      end;
}.
Proof.
  all: intros; destruct (min l) eqn: Hc; inv H.
    inv H0. eapply min_spec; eauto.
    rewrite app_nil_r. cbn.
      apply perm_Permutation, removeFirst_In_perm, min_In, Hc.
    destruct l; cbn in *.
      reflexivity.
      destruct (min l); inv Hc.
    right. apply lengthOrder_removeFirst_min. assumption.
Defined.
*)