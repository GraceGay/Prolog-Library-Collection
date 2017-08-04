:- module(
  equiv,
  [
    equiv/2, % +Partial:ordset(pair)
             % -EquicalenceRelation:ugraph
    equiv_class/3, % +EquivalenceRelation:ugraph
                   % +Element
                   % -EquivalenceClass:ordset
    equiv_partition/2, % +EquivalenceRelation:ugraph
                       % -Partition:ordset(ordset)
    is_equiv/1, % +Relation:ugraph
    quotient_set/3 % +EquivalenceRelation:ugraph
                   % +Set:ordset
                   % -QuotientSet:ordset(ordset)
  ]
).

/** <module> Equivalence

@author Wouter Beek
@version 2015/10, 2015/12-2016/01
*/

:- use_module(library(aggregate)).
:- use_module(library(apply)).
:- use_module(library(closure)).
:- use_module(library(graph/s/s_graph)).
:- use_module(library(graph/s/s_test)).
:- use_module(library(list_ext)).
:- use_module(library(plunit)).
:- use_module(library(set/equiv_closure)).
:- use_module(library(set/relation)).
:- use_module(library(yall)).





%! equiv(+Partial:ordset(pair), -EquivalenceRelation:ugraph) is det.

equiv(L1, G):-
  equiv_closure(L1, L2),
  s_edges(G, L2).



%! equiv_class(
%!   +EquivalenceRelation:ugraph,
%!   +Element,
%!   -EquivalenceClass:ordset
%! ) is det.
% Returns the equivalence class of Element relative to
% the given EquivalenceRelation.
%
% The function that maps from elements onto their equivalence classes is
% sometimes called the *|canonical projection map|*.
%
% @arg EquivalenceRelation An binary relation that is reflexive,
%      symmetric and transitive, represented as a directed graph.
% @arg Element The element whose equivalence class is returned.
% @arg EquivalenceClass The equivalence class of `Element`.
%      This is an ordered set.

equiv_class(EqRel, X, EqClass):-
  closure0_set(
    % Since an equivalence relation is symmetric,
    % we do not need to use e.g. adjacent/3 here.
    {EqRel}/[X,Y]>>relation_pair(EqRel, X-Y),
    X,
    EqClass
  ).

:- begin_tests('equiv_class/3').

test(
  'equiv_class(+,+,-) is det. TRUE',
  [forall(equiv_class_test(GName,X,EqClass))]
):-
  s_test_graph(GName, EqRel),
  equiv_class(EqRel, X, EqClass).

equiv_class_test(equiv(1), 1, [1,2,3,4]).
equiv_class_test(equiv(1), 2, [1,2,3,4]).
equiv_class_test(equiv(1), 3, [1,2,3,4]).
equiv_class_test(equiv(1), 4, [1,2,3,4]).

:- end_tests('equiv_class/3').



%! equiv_partition(+EquivRelation:ugraph, -Partition:ordset(ordset)) is det.
%! equiv_partition(-EquivRelation:ugraph, +Partition:ordset(ordset)) is det.

equiv_partition(EqRel, Part):-
  nonvar(EqRel), !,
  relation_components(EqRel, S, _),
  quotient_set(EqRel, S, Part).
equiv_partition(EqRel, Part):-
  nonvar(Part), !,
  aggregate_all(set(X-Y), (member(QSet, Part), member(X, Y, QSet)), Es),
  s_edges(EqRel, Es).

:- begin_tests('equiv_partition/2').

test(
  'equiv_partition(+,-) is det. TRUE',
  [forall(equiv_partition_test(GName,Part))]
):-
  s_test_graph(GName, G),
  equiv_partition(G, Part).

% Base case.
equiv_partition_test(equiv(1), [[1,2,3,4]]).
equiv_partition_test(equiv(2), []).
equiv_partition_test(equiv(3), [[a,b]]).
equiv_partition_test(equiv(4), [[a]]).
equiv_partition_test(equiv(5), [[a,b]]).
equiv_partition_test(equiv(6), [[a,b],[c,d]]).
equiv_partition_test(equiv(7), [[a,b,c,d]]).

:- end_tests('equiv_partition/2').



%! is_equiv(+Relation:ugraph) is semidet.
% Succeeds if the given relation is an equivalence relation.

is_equiv(Rel):-
  is_reflexive(Rel),
  is_symmetric(Rel),
  is_transitive(Rel).



%! quotient_set(
%!   +EquivalenceRelation:ugraph,
%!   +Set:ordset,
%!   -QuotientSet:ordset(ordset)
%! ) is det.
% Returns the quotient set for `Set`,
% closed under equivalence relation `EquivalenceRelation`.
%
% The quotient set of a set `Set` is the set of all equivalence sets of
% elements in `Set`.
%
% A quotient set of `Set` is also a partition of `Set`.
%
% The standard notation for a quotient set is $S / \approx$.
%
% @arg EquivalenceRelation A (binary) equivalence relation.
%      Represented as a directed graph (see [ugraph]).
% @arg Set An ordered set.
% @arg QuotientSet The quotient set of `Set`.
%      An ordered set.

quotient_set(EqRel, Set, QSet):-
  maplist(equiv_class(EqRel), Set, EqClasses),
  sort(EqClasses, QSet).
