:- module(
  rfc5322,
  [
    mailbox//1 % -Mailbox:compound
  ]
).

/** <module> RFC 5322: Internet Message Format

@author Wouter Beek
@compat RFC 5322
@see https://tools.ietf.org/html/rfc5322
@version 2015/12-2016/02, 2017/01
*/

:- use_module(library(dcg/dcg_ext), except([
     atom//1
   ])).
:- use_module(library(dcg/rfc2234), [
     'ALPHA'//1,  % ?Code
     'CR'//0,
     'CR'//1,     % ?Code
     'CRLF'//0,
     'CRLF'//1,   % ?Code
     'DIGIT'//1,  % ?Weight:between(0,9)
     'DQUOTE'//0,
     'HTAB'//0,
     'LF'//0,
     'LF'//1,     % ?Code
     'SP'//0,
     'VCHAR'//1,  % ?Code
     'WSP'//0,
     'WSP'//1     % ?Code
   ]).
:- use_module(library(sgml)).





%! 'addr-spec'(-LocalPart:string, -Domain:string)// is det.
%
% ```abnf
% addr-spec = local-part "@" domain
% ```

'addr-spec'(LocalPart, Domain) -->
  'local-part'(LocalPart),
  "@",
  domain(Domain).



%! address(-Address:pair(list(string),list(compound)))// is det.
%
% ```abnf
% address = mailbox / group
% ```

address([]-Mailboxes) -->
  mailbox(Mailboxes).
address(Name-Mailboxes) -->
  group(Name, Mailboxes).



%! 'angle-addr'(
%!   -Route:list(string),
%!   -LocalPart:string,
%!   -Domain:string
%! )// is det.
%
% ```abnf
% angle-addr = [CFWS] "<" addr-spec ">" [CFWS] / obs-angle-addr
% ```

'angle-addr'([], LocalPart, Domain) -->
  ?('CFWS'),
  "<",
  'addr-spec'(LocalPart, Domain),
  ">",
  ?('CFWS').
'angle-addr'(Route, LocalPart, Domain) -->
  'obs-angle-addr'(Route, LocalPart, Domain).



%! atext(?Code)// .
%
% ```abnf
% atext = ALPHA / DIGIT   ; Printable US-ASCII
%       / "!" / "#"       ;  characters not including
%       / "$" / "%"       ;  specials.  Used for atoms.
%       / "&" / "'"
%       / "*" / "+"
%       / "-" / "/"
%       / "=" / "?"
%       / "^" / "_"
%       / "`" / "{"
%       / "|" / "}"
%       / "~"
% ```

atext(C)   --> 'ALPHA'(C).
atext(C)   --> 'DIGIT'(C).
atext(0'!) --> "!".
atext(0'#) --> "#".
atext(0'$) --> "$".
atext(0'%) --> "%".
atext(0'&) --> "&".
atext(0'') --> "'".
atext(0'*) --> "*".
atext(0'+) --> "+".
atext(0'-) --> "-".
atext(0'/) --> "/".
atext(0'=) --> "=".
atext(0'?) --> "?".
atext(0'^) --> "^".
atext(0'_) --> "_".
atext(0'`) --> "`".
atext(0'{) --> "{".
atext(0'|) --> "|".
atext(0'}) --> "}".
atext(0'~) --> "~".



%! atom(-Atom:string)// is det.
%
% ```abnf
% atom = [CFWS] 1*atext [CFWS]
% ```

atom(Atom) -->
  ?('CFWS'),
  +(atext, Cs),
  ?('CFWS'),
  {string_codes(Atom, Cs)}.



%! ccontent// .
%
% ```abnf
% ccontent = ctext / quoted-pair / comment
% ```

ccontent --> ctext(_).
ccontent --> 'quoted-pair'(_).
ccontent --> comment.



%! 'CFWS'// .
%
% ```abnf
% CFWS = (1*([FWS] comment) [FWS]) / FWS
% ```

'CFWS' -->
  +(sep_comment),
  ?('FWS').
'CFWS' -->
  'FWS'.

sep_comment -->
  ?('FWS'),
  comment.



%! comment// .
%
% ```abnf
% comment = "(" *([FWS] ccontent) [FWS] ")"
% ```

comment -->
  "(",
  *(sep_ccontent),
  ?('FWS'),
  ")".

sep_ccontent -->
  ?('FWS'),
  ccontent.



%! ctext(-Code)// .
%
% ```abnf
% ctext = %d33-39     ; Printable US-ASCII
%       / %d42-91     ;  characters not including
%       / %d93-126    ;  "(", ")", or "\"
%       / obs-ctext
% ```

ctext(C) -->
  [C],
  {once((
    between(33, 39, C)
  ; between(42, 91, C)
  ; between(93, 126, C)
  ))}.
ctext(C) -->
  'obs-ctext'(C).



%! date(-Year:nonneg, -Month:bewtween(0,99), -Day:between(0,99))// is det.
%
% ```abnf
% date = day month year
% ```

date(Y, Mo, D) -->
  day(D),
  month(Mo),
  year(Y).



%! 'date-time'(-Lex:string)// is det.
%
% ```abnf
% date-time = [ day-of-week "," ] date time [CFWS]
% ```

'date-time'(Lex) -->
  ('day-of-week'(D) -> "," ; ""),
  date(Y, Mo, D),
  time(H, Mi, S, Off),
  ?('CFWS'),
  {
    rdf_equal(xsd:dateTime, D),
    xsd_time_string(date_time(Y,Mo,D,H,Mi,S,Off), D, Lex)
  }.



%! day(-Day:between(0,99))// is det.
%
% ```abnf
% day = ([FWS] 1*2DIGIT FWS) / obs-day
% ```

day(D) -->
  ?('FWS'),
  'm*n'(1, 2, 'DIGIT', Ds),
  'FWS',
  {pos_sum(Ds, D)}.
day(D) -->
  'obs-day'(D).



%! 'day-name'(-Day:between(1,7))// is det.
%
% ```abnf
% day-name = "Mon" / "Tue" / "Wed" / "Thu" / "Fri" / "Sat" / "Sun"
% ```

'day-name'(1) --> "Mon".
'day-name'(2) --> "Tue".
'day-name'(3) --> "Wed".
'day-name'(4) --> "Thu".
'day-name'(5) --> "Fri".
'day-name'(6) --> "Sat".
'day-name'(7) --> "Sun".



%! 'day-of-week'(-Day:between(1,7))// is det.
%
% ```abnf
% day-of-week = ([FWS] day-name) / obs-day-of-week
% ```

'day-of-week'(D) --> ?('FWS'), 'day-name'(D).
'day-of-week'(D) --> 'obs-day-of-week'(D).



%! 'display-name'(-Name:list(string))// is det.
%
% ```abnf
% display-name = phrase
% ```

'display-name'(Name) -->
  phrase0(Name).



%! domain(-Domain:string)// is det.
%
% ```abnf
% domain = dot-atom / domain-literal / obs-domain
% ```

domain(Domain) --> 'dot-atom'(Domain), !.
domain(Domain) --> 'domain-literal'(Domain), !.
domain(Domain) --> 'obs-domain'(Domain).



%! 'domain-literal'(-DomainLiteral:string)// is det.
%
% ```abnf
% domain-literal = [CFWS] "[" *([FWS] dtext) [FWS] "]" [CFWS]
% ```

'domain-literal'(DomainLiteral) -->
  ?('CFWS'),
  "[",
  *(spc_dtext, Cs),
  ?('FWS'),
  "]",
  ?('CFWS'),
  {string_codes(DomainLiteral, Cs)}.

spc_dtext(C) -->
  ?('FWS'),
  dtext(C).



%! 'dot-atom'(-Atom:string)// is det.
%
% ```abnf
% dot-atom = [CFWS] dot-atom-text [CFWS]
% ```

'dot-atom'(Atom) -->
  ?('CFWS'),
  'dot-atom-text'(Atom),
  ?('CFWS').



%! 'dot-atom-text'(-Atom:string)// is det.
%
% ```abnf
% dot-atom-text = 1*atext *("." 1*atext)
% ```

'dot-atom-text'(Atom) -->
  atext(H),
  *(dot_or_atext, T),
  {string_codes(Atom, [H|T])}.

dot_or_atext(0'.) --> ".".
dot_or_atext(C) --> atext(C).



%! dtext(?Code)// .
%
% ```abnf
% dtext = %d33-90     ; Printable US-ASCII
%       / %d94-126    ;  characters not including
%       / obs-dtext   ;  "[", "]", or "\"
% ```

dtext(C) -->
  [C],
  {once(
    between(33, 90, C)
  ; between(94, 126, C)
  )}.
dtext(C) -->
  'obs-dtext'(C).



%! 'FWS'// .
%
% Folding white space.
%
% ```abnf
% FWS = ([*WSP CRLF] 1*WSP) / obs-FWS   ; Folding white space
% ```

'FWS' -->
  ?(fws_prefix),
  +('WSP').
'FWS' -->
  'obs-FWS'.

fws_prefix -->
  *('WSP'),
  'CRLF'.



%! group(-Name:list(string), -Mailboxes:list(compound))// is det.
%
% ```abnf
% group = display-name ":" [group-list] ";" [CFWS]
% ```

group(Name, Mailboxes) -->
  'display-name'(Name),
  ":",
  ('group-list'(Mailboxes) -> "" ; {Mailboxes = []}),
  ";",
  ?('CFWS').



%! 'group-list'(-Mailboxes:list(compound))// is det.
%
% ```abnf
% group-list = mailbox-list / CFWS / obs-group-list
% ```

'group-list'(Mailboxes) --> 'mailbox-list'(Mailboxes).
'group-list'([]) --> 'CFWS'.
'group-list'([]) --> 'obs-group-list'.



%! hour(-Hour:between(0,99))// is det.
%
% ```abnf
% hour = 2DIGIT / obs-hour
% ```

hour(H) -->
  #(2, 'DIGIT', Ds), !,
  {pos_sum(Ds, H)}.
hour(H) -->
  'obs-hour'(H).



%! 'local-part'(-LocalPart:string)// is det.
%
% ```abnf
% local-part = dot-atom / quoted-string / obs-local-part
% ```

'local-part'(LocalPart) --> 'dot-atom'(LocalPart).
'local-part'(LocalPart) --> 'quoted-string'(LocalPart).
'local-part'(LocalPart) --> 'obs-local-part'(LocalPart).



%! mailbox(-Mailbox:compound)// is det.
%
% ```abnf
% mailbox = name-addr / addr-spec
% ```

mailbox(mailbox(Name,Route,LocalPart,Domain)) -->
  'name-addr'(Name, Route, LocalPart, Domain).
mailbox(mailbox([],[],LocalPart,Domain)) -->
  'addr-spec'(LocalPart, Domain).



%! 'mailbox-list'(-Mailboxes:list(compound))// is det.
%
% ```abnf
% mailbox-list = (mailbox *("," mailbox)) / obs-mbox-list
% ```

'mailbox-list'([H|T]) -->
  mailbox(H),
  *(sep_mailbox, T), !.
'mailbox-list'(L) -->
  'obs-mbox-list'(L).

sep_mailbox(Mailbox) -->
  ",",
  mailbox(Mailbox).



%! minute(-Minute:between(0,99))// is det.
%
% ```abnf
% minute = 2DIGIT / obs-minute
% ```

minute(Mi) -->
  #(2, 'DIGIT', Ds), !,
  {pos_sum(Ds, Mi)}.
minute(Mi) -->
  'obs-minute'(Mi).



%! month(-Month:between(1,12))// is det.
%
% ```abnf
% month = "Jan" / "Feb" / "Mar" / "Apr"
%       / "May" / "Jun" / "Jul" / "Aug"
%       / "Sep" / "Oct" / "Nov" / "Dec"
% ```

month(1)  --> "Jan".
month(2)  --> "Feb".
month(3)  --> "Mar".
month(4)  --> "Apr".
month(5)  --> "May".
month(6)  --> "Jun".
month(7)  --> "Jul".
month(8)  --> "Aug".
month(9)  --> "Sep".
month(10) --> "Oct".
month(11) --> "Nov".
month(12) --> "Dec".



%! 'name-addr'(
%!   -Name:list(string),
%!   -Route:list(string),
%!   -LocalPart:string,
%!   -Domain:string
%! )// is det.
%
% ```abnf
% name-addr = [display-name] angle-addr
% ```

'name-addr'(Name, Route, LocalPart, Domain) -->
  ('display-name'(Name) -> "" ; {Name = []}),
  'angle-addr'(Route, LocalPart, Domain).



%! 'obs-addr-list'(
%!   -Addresses:list(pair(list(string),list(compound)))
%! )// is det.
%
% ```abnf
% obs-addr-list = *([CFWS] ",") address *("," [address / CFWS])
% ```

'obs-addr-list'([H|T]) -->
  *(obs_list_prefix),
  address(H),
  obs_addr_list_tail(T).

obs_addr_list_tail(L) -->
  ",", !,
  (address(H) -> {L = [H|T]} ; ?('CFWS'), {L = T}),
  obs_addr_list_tail(T).
obs_addr_list_tail([]) --> "".



%! 'obs-angle-addr'(
%!   -Route:list(string),
%!   -LocalPart:string,
%!   -Domain:list(string)
%! )// is det.
%
% ```abnf
% obs-angle-addr = [CFWS] "<" obs-route addr-spec ">" [CFWS]
% ```

'obs-angle-addr'(Route, LocalPart, Domain) -->
  ?('CFWS'),
  "<",
  'obs-route'(Route),
  'addr-spec'(LocalPart, Domain),
  ">",
  ?('CFWS').



%! 'obs-body'(-Body:list(code))// is det.
%
% ```abnf
% obs-body = *((*LF *CR *((%d0 / text) *LF *CR)) / CRLF)
% ```

'obs-body'([H1,H2|T]) -->
  'CRLF'([H1,H2]), !,
  'obs-body'(T).
'obs-body'(L) -->
  *('LF', L1),
  *('CR', L2),
  obs_body_codes(L3),
  {append([L1,L2,L3], L0), L0 \== []}, !,
  'obs-body'(L6),
  {append(L3, L6, L)}.
'obs-body'([]) --> "".

obs_body_codes([0|T]) --> [0],     !, *('LF'), *('CR'), obs_body_codes(T).
obs_body_codes([H|T]) --> text(H), !, *('LF'), *('CR'), obs_body_codes(T).
obs_body_codes([])    --> "".



%! 'obs-ctext'(?Code)// .
%
% ```abnf
% obs-ctext = obs-NO-WS-CTL
% ```

'obs-ctext'(C) -->
  'obs-NO-WS-CTL'(C).



%! 'obs-day'(-Day:bewtween(0,99))// is det.
%
% ```abnf
% obs-day = [CFWS] 1*2DIGIT [CFWS]
% ```

'obs-day'(D) -->
  ?('CFWS'),
  'm*n'(1, 2, 'DIGIT', Ds),
  {pos_sum(Ds, D)}.



%! 'obs-day-of-week'(-Day:between(1,7))// is det.
%
% ```abnf
% obs-day-of-week = [CFWS] day-name [CFWS]
% ```

'obs-day-of-week'(D) -->
  ?('CFWS'),
  'day-name'(D),
  ?('CFWS').



%! 'obs-domain'(-Domain:list(string))// is det.
%
% ```abnf
% obs-domain = atom *("." atom)
% ```

'obs-domain'([H|T]) -->
  atom(H),
  *(sep_atom, T).

sep_atom(X) -->
  ",",
  atom(X).



%! 'obs-domain-list'(-Domains:list(string))// is det.
%
% ```abnf
% obs-domain-list = *(CFWS / ",") "@" domain *("," [CFWS] ["@" domain])
% ```

'obs-domain-list'([H|T]) -->
  *(obs_domain_list_prefix),
  "@",
  domain(H),
  obs_domain_list_tail(T).

obs_domain_list_prefix --> 'CFWS'.
obs_domain_list_prefix --> ",".

obs_domain_list_tail(L) -->
  ",",
  ?('CFWS'),
  ("@" -> domain(H), {L = [H|T]} ; {L = T}),
  obs_domain_list_tail(T).
obs_domain_list_tail([]) --> "".



%! 'obs-dtext'(?Code)// is det.
%
% ```abnf
% obs-dtext = obs-NO-WS-CTL / quoted-pair
% ```

'obs-dtext'(C) --> 'obs-NO-WS-CTL'(C).
'obs-dtext'(C) --> 'quoted-pair'(C).



%! 'obs-FWS'// is det.
%
% ```abnf
% obs-FWS = 1*WSP *(CRLF 1*WSP)
% ```

'obs-FWS' -->
  +('WSP'),
  *(obs_fws_part).

obs_fws_part -->
  'CRLF',
  +('WSP').



%! 'obs-group-list'// is det.
%
% ```abnf
% obs-group-list = 1*([CFWS] ",") [CFWS]
% ```

'obs-group-list' -->
  +(obs_list_prefix),
  ?('CFWS').



%! 'obs-hour'(-Hour:between(0,99))// is det.
%
% ```abnf
% obs-hour = [CFWS] 2*DIGIT [CFWS]
% ```

'obs-hour'(H) -->
  ?('CFWS'),
  'm*n'(1, 2, 'DIGIT', Ds),
  {pos_sum(Ds, H)}.



%! 'obs-local-part'(-Words:list)// is det.
%
% ```abnf
% obs-local-part = word *("." word)
% ```

'obs-local-part'([H|T]) -->
  word(H),
  *(sep_word, T).

sep_word(X) -->
  ".",
  word(X).



%! 'obs-mbox-list'(-Mailboxes:list(compound))// is det.
%
% ```abnf
% obs-mbox-list = *([CFWS] ",") mailbox *("," [mailbox / CFWS])
% ```

'obs-mbox-list'([H|T]) -->
  *(obs_list_prefix),
  mailbox(H),
  obs_mbox_list_tail(T).

obs_mbox_list_tail(L) -->
  ",", !,
  (mailbox(H) -> {L = [H|T]} ; ?('CFWS'), {L = T}),
  obs_mbox_list_tail(T).
obs_mbox_list_tail([]) --> "".



%! 'obs-minute'(-Minute:between(0,99))// is det.
%
% ```abnf
% obs-minute = [CFWS] 2*DIGIT [CFWS]
% ```

'obs-minute'(Mi) -->
  ?('CFWS'),
  'm*n'(1, 2, 'DIGIT', Ds),
  {pos_sum(Ds, Mi)}.



%! 'obs-NO-WS-CTL'(?Code)// .
%
% ```abnf
% obs-NO-WS-CTL = %d1-8     ; US-ASCII control
%               / %d11      ; characters that do not
%               / %d12      ; include the carriage
%               / %d14-31   ; return, line feed, and
%               / %d127     ; white space characters
% ```

'obs-NO-WS-CTL'(C) -->
  [C],
  {once((
    between(1, 8, C)
  ; between(11, 12, C)
  ; between(14, 31, C)
  ; C =:= 127
  ))}.



%! 'obs-phrase'(-Words:list(string))// is det.
%
% ```abnf
% obs-phrase = word *(word / "." / CFWS)
% ```

'obs-phrase'([H|T]) -->
  word(H),
  obs_phrase_tail0(T).

obs_phrase_tail0([H|T]) --> word(H), !, obs_phrase_tail(T).
obs_phrase_tail0(L)     --> ".", !, obs_phrase_tail(L).
obs_phrase_tail0(L)     --> 'CFWS', !, obs_phrase_tail(L).
obs_phrase_tail0([])    --> "".



%! 'obs-phrase-list'// is det.
%
% ```abnf
% obs-phrase-list = [phrase / CFWS] *("," [phrase / CFWS])
% ```
%
% @tbd

'obs-phrase-list' -->
  phrase_cfws_empty,
  *(sep_phrase_cfws_empty).

sep_phrase_cfws_empty -->
  ",",
  phrase_cfws_empty.

phrase_cfws_empty --> phrase0(_), !.
phrase_cfws_empty --> 'CFWS', !.
phrase_cfws_empty --> "".



%! 'obs-qp'(?Code)// .
%
% ```abnf
% obs-qp = "\" (%d0 / obs-NO-WS-CTL / LF / CR)
% ```

'obs-qp'(C) -->
  "\\",
  obs_qp_code(C).

obs_qp_code(0) --> [0].
obs_qp_code(C) --> 'obs-NO-WS-CTL'(C).
obs_qp_code(C) --> 'LF'(C).
obs_qp_code(C) --> 'CR'(C).



%! 'obs-qtext'(?Code)// .
%
% ```abnf
% obs-qtext = obs-NO-WS-CTL
% ```

'obs-qtext'(C) -->
  'obs-NO-WS-CTL'(C).



%! 'obs-route'(-Route:list(string))// is det.
%
% ```abnf
% obs-route = obs-domain-list ":"
% ```

'obs-route'(Route) -->
  'obs-domain-list'(Route),
  ":".



%! 'obs-second'(-Second:between(0,99))// is det.
%
% ```abnf
% obs-second = [CFWS] 2*DIGIT [CFWS]
% ```

'obs-second'(S) -->
  ?('CFWS'),
  'm*n'(1, 2, 'DIGIT', Ds),
  {pos_sum(Ds, S)}.



%! 'obs-utext'(?Code)// .
%
% ```abnf
% obs-utext = %d0 / obs-NO-WS-CTL / VCHAR
% ```

'obs-utext'(0) --> [0].
'obs-utext'(C) --> 'obs-NO-WS-CTL'(C).
'obs-utext'(C) --> 'VCHAR'(C).



%! 'obs-unstruct'(-Cs)// is det.
%
% ```abnf
% obs-unstruct = *((*LF *CR *(obs-utext *LF *CR)) / FWS)
% ```

'obs-unstruct'(Cs) -->
  'FWS', !,
  'obs-unstruct'(Cs).
'obs-unstruct'(Cs) -->
  *('LF', Cs1),
  *('CR', Cs2),
  obs_unstruct_codes(Cs3),
  {append([Cs1,Cs2,Cs3], Cs0), Cs0 \== []}, !,
  'obs-unstruct'(Cs4),
  {append(Cs3, Cs4, Cs)}.
'obs-unstruct'([]) --> "".

obs_unstruct_codes([H|T]) -->
  'obs-utext'(H), !,
  *('LF'),
  *('CR'),
  obs_unstruct_codes(T).
obs_unstruct_codes([]) --> "".



%! 'obs-year'(-Year:between(0,99))// is det.
%
% ```abnf
% obs-year = [CFWS] 2*DIGIT [CFWS]
% ```

'obs-year'(Y) -->
  ?('CFWS'),
  'm*n'(1, 2, 'DIGIT', Ds),
  {pos_sum(Ds, Y)}.



%! 'obs-zone'(-TZ:string)// is det.
%
% ```abnf
% obs-zone = "UT"            ; Universal Time
%          / "GMT"           ; North American UT
%          / "EST" / "EDT"   ; Eastern:  - 5/ - 4
%          / "CST" / "CDT"   ; Central:  - 6/ - 5
%          / "MST" / "MDT"   ; Mountain: - 7/ - 6
%          / "PST" / "PDT"   ; Pacific:  - 8/ - 7
%          / %d65-73         ; Military zones - "A"
%          / %d75-90         ; through "I" and "K"
%          / %d97-105        ; through "Z", both
%          / %d107-122       ; upper and lower case
% ```

'obs-zone'("Universal Time") --> "UT", !.
'obs-zone'("North American UT") --> "GMT", !.
'obs-zone'("Eastern") --> ("EST" ; "EDT"), !.
'obs-zone'("Central") --> ("CST" ; "CDT"), !.
'obs-zone'("Mountain") --> ("MST" ; "MDT"), !.
'obs-zone'("Pacific") --> ("PST" ; "PDT"), !.
'obs-zone'("Military") -->
  [C],
  {once((
    between(65, 73, C) ;
    between(75, 90, C) ;
    between(97, 105, C) ;
    between(107, 122, C)
  ))}.



%! phrase0(-Words:list(string))// is det.
%
% ```abnf
% phrase = 1*word / obs-phrase
% ```

phrase0(Words) --> +(word, Words), !.
phrase0(Words) --> 'obs-phrase'(Words).



%! qcontent(?Code)// .
%
% ```abnf
% qcontent = qtext / quoted-pair
% ```

qcontent(C) --> qtext(C).
qcontent(C) --> 'quoted-pair'(C).



%! qtext(?Code)// .
%
% ```abnf
% qtext = %d33        ; Printable US-ASCII
%       / %d35-91     ;  characters not including
%       / %d93-126    ;  "\" or the quote character
%       / obs-qtext
% ```

qtext(33) --> [33].
qtext(C)  --> [C], {once(between(35, 91, C) ; between(93, 126, C))}.
qtext(C)  --> 'obs-qtext'(C).



%! 'quoted-pair'(?Code)// .
%
% ```abnf
% quoted-pair = ("\" (VCHAR / WSP)) / obs-qp
% ```

'quoted-pair'(C) --> "\\", 'VCHAR'(C).
'quoted-pair'(C) --> "\\", 'WSP'(C).
'quoted-pair'(C) --> 'obs-qp'(C).



%! 'quoted-string'(-String)// is det.
%
% ```abnf
% quoted-string = [CFWS] DQUOTE *([FWS] qcontent) [FWS] DQUOTE [CFWS]
% ```

'quoted-string'(Str) -->
  ?('CFWS'),
  'DQUOTE',
  *(quoted_string_code, Cs),
  ?('FWS'),
  'DQUOTE',
  ?('CFWS'),
  {string_codes(Str, Cs)}.

quoted_string_code(C) -->
  ?('FWS'),
  qcontent(C).



%! second(-Second:between(0,99))// is det.
%
% ```abnf
% second = 2DIGIT / obs-second
% ```

second(S) -->
  #(2, 'DIGIT', Ds), !,
  {pos_sum(Ds, S)}.
second(S) -->
  'obs-second'(S).



%! specials(?Code)// .
%
% ```abnf
% specials = "(" / ")"   ; Special characters that do
%          / "<" / ">"   ;  not appear in atext
%          / "[" / "]"
%          / ":" / ";"
%          / "@" / "\"
%          / "," / "."
%          / DQUOTE
% ```

specials(0'()  --> "(".
specials(0'))  --> ")".
specials(0'<)  --> "<".
specials(0'>)  --> ">".
specials(0'[)  --> "[".
specials(0'])  --> "]".
specials(0':)  --> ":".
specials(0';)  --> ";".
specials(0'@)  --> "@".
specials(0'\\) --> "\\".
specials(0',)  --> ",".
specials(0'.)  --> ".".
specials(0'")  --> 'DQUOTE'.   %"



%! text(?Code)// .
%
% ```abnf
% text = %d1-9      ; Characters excluding CR
%      / %d11       ;  and LF
%      / %d12 
%      / %d14-127
% ```

text(C) -->
  [C],
  {once((
    between(1, 9, C)
  ; between(11, 12, C)
  ; between(14, 127, C)
  ))}.



%! time(
%!   -Hour:between(0,99),
%!   -Minute:between(0,99),
%!   -Second:between(0,99),
%!   -Offset:between(-9999,9999)
%! )// is det.
%
% ```abnf
% time = time-of-day zone
% ```

time(H, Mi, S, Off) -->
  'time-of-day'(H, Mi, S),
  zone(Off).



%! 'time-of-day'(
%!   -Hour:between(0,99),
%!   -Minute:between(0,99),
%!   -Second:between(0,99)
%! )// is det.
%
% ```abnf
% time-of-day = hour ":" minute [ ":" second ]
% ```

'time-of-day'(H, Mi, S) -->
  hour(H),
  ":",
  minute(Mi),
  (":" -> second(S) ; {S = 0}).



%! unstructured(-String)// is det.
%
% ```abnf
% unstructured = (*([FWS] VCHAR) *WSP) / obs-unstruct
% ```

unstructured(Str) -->
  *(unstructured_code, Cs),
  *('WSP'),
  {string_codes(Str, Cs)}.
unstructured(Str) -->
  'obs-unstruct'(Str).

unstructured_code(C) -->
  ?('FWS'),
  'VCHAR'(C).



%! word(-Word)// is det.
%
% ```abnf
% word = atom / quoted-string
% ```

word(S) --> atom(S).
word(S) --> 'quoted-string'(S).



%! year(-Year:nonneg)// is det.
%
% ```abnf
% year = (FWS 4*DIGIT FWS) / obs-year
% ```

year(Y) -->
  'FWS',
  'm*'(4, 'DIGIT', Ds),
  'FWS',
  {pos_sum(Ds, Y)}.
year(Y) -->
  'obs-year'(Y).



%! zone(-Offset:between(-9999,9999))// is det.
%
% ```abnf
% zone = (FWS ( "+" / "-" ) 4DIGIT) / obs-zone
% ```

zone(N) -->
  'FWS',
  ("+" -> {Sg = 1} ; "-" -> {Sg = -1}),
  #(4, 'DIGIT', Ds), !,
  {pos_sum(Ds, N0), N is Sg * N0}.
zone(N) --> 'obs-zone'(N).





% HELPERS %

obs_list_prefix -->
  ?('CFWS'),
  ",".
