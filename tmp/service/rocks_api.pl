:- module(
  rocks_api,
  [
    rocks_ls/0,
    rocks_ls/1,        % +PageOpts
    rocks_merge_sum/5, % +Mode, +Key, +Left, +Right, -Result
    rocks_nullify/1,   % +RocksDB
    rocks_pull/3       % +RocksDB, -Key, -Val
  ]
).

:- use_module(library(apply)).
:- use_module(library(debug)).
:- use_module(library(file_ext)).
:- use_module(library(lists)).
:- use_module(library(ordsets)).
:- use_module(library(pagination_cli)).
:- use_module(library(settings)).

  


%! rocks_ls is det.
%! rocks_ls(+PageOpts) is det.
%
% Prints the existing RocksDB indices to stdout.

rocks_ls :-
  rocks_ls(_{}).


rocks_ls(PageOpts) :-
  pagination(Alias, rocks_alias(Alias), PageOpts, Result),
  cli_pagination_result(Result, pp_aliases).

pp_aliases(Aliases) :-
  maplist(writeln, Aliases).



%! rocks_merge_sum(+Mode, +Key, +Left, +Right, -Result) is det.

rocks_merge_sum(partial, _, X, Y, Z) :-
  Z is X + Y.
rocks_merge_sum(full, _, Initial, Additions, Sum) :-
  sum_list([Initial|Additions], Sum).



%! rocks_nullify(+RocksDB) is det.

rocks_nullify(RocksDB) :-
  forall(
    rocks_key(RocksDB, Key),
    rocks_merge(RocksDB, Key, 0)
  ).



%! rocks_pull(+RocksDB, -Key, -Val) is nondet.

rocks_pull(RocksDB, Key, Val) :-
  rocks_enum(RocksDB, Key, Val),
  rocks_delete(RocksDB, Key).
