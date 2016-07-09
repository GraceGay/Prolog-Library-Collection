:- module(
  http11_extra,
  [
    'HTTP-version'//1 % -Version:dict
  ]
).

/** <module> HTTP 1.1 extra

HTTP 1.1 grammar rules that are not actually used.

@author Wouter Beek
@version 2016/01-2016/02
*/

:- use_module(library(apply)).
:- use_module(library(dcg/dcg_ext)).
:- use_module(library(http/http1, [
     'header-field'//1 % -Header:pair
   ]).
:- use_module(library(uri/rfc3986), [
     'absolute-URI'//1, % -AbsoluteUri:dict
     authority//1, % -Authority:dict
     'path-abempty'//1, % -Segments:list(string)
     segment//1 % -Segment:string
   ]).





%! 'absolute-form'(-Uri:dict)// is det.
% ```abnf
% absolute-form = absolute-URI
% ```

'absolute-form'(Uri) --> 'absolute-URI'(Uri).



%! 'absolute-path'(-Path:list(string))// is det.
% ```abnf
% absolute-path = 1*( "/" segment )
% ```

'absolute-path'(L) --> +(sep_segment, L).

sep_segment(S) --> "/", segment(S).



%! 'asterisk-form'// is det.
% ```abnf
% asterisk-form = "*"
% ```

'asterisk-form' --> "*".



%! 'authority-form'(-Authority:dict)// is det.
% ```abnf
% authority-form = authority
% ```

'authority-form'(D) --> authority(D).



%! 'chunked-body'(-ChunkedBody:dict)// is det.
% ```abnf
% chunked-body = *chunk last-chunk trailer-part CRLF
% ```

'chunked-body'(_{
  '@type': 'llo:ChunkedBody',
  'llo:chunks': Chunks,
  'llo:last_chunk': Exts,
  'llo:trailer_part': Headers
}) -->
  *(chunk, Chunks),
  'last-chunk'(Exts),
  'trailer-part'(Headers),
  'CRLF'.



%! 'HTTP-message'(-Message:dict)// is det.
% ```abnf
% HTTP-message = start-line *( header-field CRLF ) CRLF [ message-body ]
% ```

'HTTP-message'(D) -->
  'start-line'(D0),
  *(header_field_eol, L),
  'CRLF',
  def('message-body', Cs, []),
  {D = D0.put([body-Cs,headers-L])},
  'CRLF'.



%! 'HTTP-name'// is det.
% ```abnf
% HTTP-name = %x48.54.54.50   ; "HTTP", case-sensitive
% ```

'HTTP-name' --> [0x48,0x54,0x54,0x50].



%! 'http-URI'(-Uri:dict)// is det.
% ```abnf
% http-URI = "http:" "//" authority path-abempty [ "?" query ] [ "#" fragment ]
% ```

'http-URI'(D) -->
  "http://",
  authority(Auth),
  'path-abempty'(Path),
  ("?" -> query(Query) ; ""),
  ("#" -> fragment(Frag) ; ""),
  {
    L1 = [authority-Auth,fragment-Frag,path-Path,query-Query],
    exclude(pair_has_var_value, L1, L2),
    dict_pairs(D, http_uri, L2)
  }.



%! 'HTTP-version'(-Version:dict)// is det.
% ```abnf
% HTTP-version = HTTP-name "/" DIGIT "." DIGIT
% ```

'HTTP-version'(_{
  '@type': 'llo:Version',
  'llo:major': _{'@type': 'xsd:nonNegativeInteger', '@value': Major},
  'llo:minor': _{'@type': 'xsd:nonNegativeInteger', '@value': Minor}
}) -->
  'HTTP-name', "/",
  digit(Major), ".",
  digit(Minor).



%! 'https-URI'(-Uri:dict)// is det.
% ```abnf
% https-URI = "https:" "//" authority path-abempty [ "?" query ] [ "#" fragment ]
% ```

'https-URI'(D) -->
  atom_ci('https://'),
  authority(Auth),
  'path-abempty'(Path),
  ("?" -> query(Query) ; ""),
  ("#" -> fragment(Frag) ; ""),
  {
    L1 = [authority-Auth,fragment-Frag,path-Path,query-Query],
    exclude(pair_has_var_value, L1, L2),
    dict_pairs(D, http_uri, L2)
  }.



%! 'origin-form'(-Uri:dict)// is det.
% ```abnf
% origin-form = absolute-path [ "?" query ]
% ```

'origin-form'(D) -->
  'absolute-path'(D0),
  ("?" -> query(Query), {D = D0.put(query, Query)} ; {D = D0}).



%! 'reason-phrase'(-Reason:string)// is det.
% ```abnf
% reason-phrase = *( HTAB | SP | VCHAR | obs-text )
% ```

'reason-phrase'(S) --> *(reason_phrase_code, Cs), {string_codes(S, Cs)}.

reason_phrase_code(C) --> 'HTAB'(C).
reason_phrase_code(C) --> 'SP'(C).
reason_phrase_code(C) --> 'VCHAR'(C).
reason_phrase_code(C) --> 'obs-text'(C).



%! 'request-line'(-Message:dict)// is det.
% ```abnf
% request-line = method SP request-target SP HTTP-version CRLF
% ```

'request-line'(_{
  '@type': 'llo:HttpRequest',
  'llo:method': Method,
  'llo:request_target': Iri,
  'llo:version': Version
}) -->
  method(Method),
  'SP',
  'request-target'(Iri),
  'SP',
  'HTTP-version'(Version),
  'CRLF'.



%! 'request-target'(-RequestTarget:dict)// is det.
% ```abnf
% request-target = origin-form
%                | absolute-form
%                | authority-form
%                | asterisk-form
% ```

'request-target'(D) --> 'origin-form'(D).
'request-target'(D) --> 'absolute-form'(D).
'request-target'(D) --> 'authority-form'(D).
'request-target'(D) --> 'asterisk-form'.



%! 'start-line'(-StartLine:dict)// is det.
% ```abnf
% start-line = request-line | status-line
% ```

'start-line'(D) --> 'request-line'(D), !.
'start-line'(D) --> 'status-line'(D).



%! 'status-code'(-Status:between(0,999))// is det.
% ```abnf
% status-code = 3DIGIT
% ```
%
% @tbd Define an XSD to the limit [100,599].

'status-code'(_{'@type': 'xsd:nonNegativeInteger', '@value': N}) -->
  #(3, 'DIGIT', Ds), {pos_sum(Ds, N)}.



%! 'status-line'(-Message:dict)// is det.
% ```abnf
% status-line = HTTP-version SP status-code SP reason-phrase CRLF
% ```

'status-line'(_{
  reason: Reason,
  status: Status,
  '@type': 'HttpResponse',
  version: Version
}) -->
  'HTTP-version'(Version), 'SP',
  'status-code'(Status), 'SP',
  'reason-phrase'(Reason), 'CRLF'.



%! 'trailer-part'(-Headers:list(pair(string)))// is det.
% ```abnf
% trailer-part = *( header-field CRLF )
% ```

'trailer-part'(Headers) --> *(header_field_eol, Headers).





% HELPERS %

header_field_eol(Header) -->
  'header-field'(Header),
  'CRLF'.
