:- module(
  xml_stream,
  [
    xml_stream_record/3 % +Source, +RecordNames, :Goal_1
  ]
).

/** <module> XML stream

@author Wouter Beek
@version 2016/06
*/

:- use_module(library(os/io)).
:- use_module(library(sgml)).

:- meta_predicate
    xml_stream_record(+, +, 2).





%! xml_stream_record(+Source, +RecordNames, :Goal_1) is det.
%
% Call Goal_1 on an XML stream, where the argument supplied to Goal_1
% is a subtree that starts with an elements within RecordNames.

xml_stream_record(Source, RecordNames, Goal_1) :-
  b_setval(xml_stream_goal, Goal_1),
  b_setval(xml_stream_record_names, RecordNames),
  call_on_stream(Source, xml_stream_record_stream0).


xml_stream_record_stream0(In, Meta, Meta) :-
  setup_call_cleanup(
    new_sgml_parser(Parser, []),
    (
      set_sgml_parser(Parser, space(remove)),
      sgml_parse(Parser, [source(In),call(begin,on_begin0)])
    ),
    free_sgml_parser(Parser)
  ).


on_begin0(Elem, Attr, Parser) :-
  b_getval(xml_stream_goal, Goal_1),
  b_getval(xml_stream_record_names, RecordNames),
  memberchk(Elem, RecordNames), !,
  sgml_parse(Parser, [document(Content),parse(content)]),
  call(Goal_1, [element(Elem, Attr, Content)]).
