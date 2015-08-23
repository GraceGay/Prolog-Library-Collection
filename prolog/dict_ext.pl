:- module(
  dict_ext,
  [
    dict_tag/3, % +Dict1:dict
                % +Tag:atom
                % ?Dict2:dict
    merge_dict/3, % +Dict1:dict
                  % +Dict2:dict
                  % -Dict:dict
    print_dict/1, % +Dict:dict
    print_dict/2 % +Dict:dict
                 % +Indent:nonneg
  ]
).

/** <module> Dictionary extensions

@author Wouter Beek
@version 2015/08
*/

:- use_module(library(apply)).
:- use_module(library(dcg/dcg_phrase)).
:- use_module(library(dcg/dcg_pl_term)).
:- use_module(library(lambda)).
:- use_module(library(lists)).
:- use_module(library(pairs)).





%! dict_tag(+Dict1:dict, +Tag:atom, +Dict2:dict) is semidet.
%! dict_tag(+Dict1:dict, +Tag:atom, -Dict2:dict) is det.
% Converts between dictionaries that differ only in their outer tag name.

dict_tag(Dict1, Tag, Dict2):-
  dict_pairs(Dict1, _, Ps),
  dict_pairs(Dict2, Tag, Ps).



%! merge_dict(+Dict1:dict, +Dict2:dict, -Dict:dict) is det.
% Merges two dictionaries into one new dictionary.
% If Dict1 and Dict2 contain the same key then the value from Dict1 is used.
% If Dict1 and Dict2 do not have the same tag then the tag of Dict1 is used.

merge_dict(D1, D2, D):-
  dict_pairs(D1, Tag1, Ps1),
  dict_pairs(D2, Tag2, Ps2Dupl),
  pairs_keys(Ps1, Ks1),
  exclude(\K^memberchk(K, Ks1), Ps2Dupl, Ps2),
  append(Ps1, Ps2, Ps),
  (Tag1 = Tag2 -> true ; Tag = Tag1),
  dict_pairs(D, Tag, Ps).



%! print_dict(Dict:dict) is det.
% Wrapper around print_dict/2 with no indentation.

print_dict(D):-
  print_dict(D, 0).

%! print_dict(Dict:dict, +Indent:nonneg) is det.

print_dict(D, I):-
  dcg_with_output_to(user_output, pl_term(D, I)).
