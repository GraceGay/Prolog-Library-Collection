:- module(
  thread_ext,
  [
    create_detached_thread/1, % :Goal_0
    create_detached_thread/2, % +Alias, :Goal_0
    thread_list/0,
    thread_monitor/0,
    thread_name/2,            % ?Id:handle, ?Name:atom
    thread_self_property/1    % ?Property
  ]
).
:- reexport(library(thread)).

/** <module> Thread extensions

@author Wouter Beek
@version 2017/12-2018/01
*/

:- use_module(library(aggregate)).
:- use_module(library(lists)).

:- meta_predicate
    create_detached_thread(0),
    create_detached_thread(+, 0).





%! create_detached_thread(:Goal_0) is det.
%! create_detached_thread(+Alias:atom, :Goal_0) is det.

create_detached_thread(Goal_0) :-
  thread_create(Goal_0, _, [detached(true)]).


create_detached_thread(Alias, Goal_0) :-
  thread_create(Goal_0, _, [alias(Alias),detached(true)]).



%! thread_list is det.

thread_list :-
  aggregate_all(
    set(Name-Status),
    (
      thread_property(Id, status(Status)),
      thread_name(Id, Name)
    ),
    Pairs
  ),
  forall(
    member(Name-Status, Pairs),
    format(user_output, "~a\t~a\n", [Name,Status])
  ).



%! thread_monitor is det.
%
% Wrapper that starts the thread monitor.

thread_monitor :-
  prolog_ide(thread_monitor).



%! thread_name(+Id:handle, -Alias:atom) is det.

thread_name(Id, Alias) :-
  thread_property(Id, alias(Alias)), !.
thread_name(Id, Id).



%! thread_self_property(+Property:compound) is semidet.
%! thread_self_property(-Property:compound) is multi.

thread_self_property(Property) :-
  thread_self(Thread),
  thread_property(Thread, Property).
