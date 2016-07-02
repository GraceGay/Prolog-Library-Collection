:- module(
  http_io,
  [
    http_get/1,                  % +Iri
    http_get/2,                  % +Iri, :Goal_3
    http_get/3,                  % +Iri, :Goal_3, +Opts
    http_get_dict/3,             % +Key, +Meta, -Val
    http_header/3,               % +Key, +Meta, -Val
    http_is_scheme/1,            % ?Scheme
    http_post/2,                 % +Iri, +Data
    http_post/3,                 % +Iri, +Data, :Goal_3
    http_post/4,                 % +Iri, +Data, :Goal_3, +Opts
    http_retry_until_success/1,  % :Goal_0
    http_retry_until_success/2,  % :Goal_0, +Timeout
    http_status_is_auth_error/1, % +Status
    http_status_is_error/1,      % +Status
    http_status_is_redirect/1,   % +Status
    http_status_label/2          % +Status, -Lbl
  ]
).

/** <module> HTTP I/O

This module extends the functionality of open_any/5 in module
iostream.

The following additional options are supported:

  * compression(+oneof([deflate,gzip,none])) Whether or not
  compression is used on the opened stream.  Default is `none`.

  * max_redirects(+positive_integer) The maximum number of redirects
  that is followed when opening a stream over HTTP.  Default is 5.

  * max_retries(+positive_integer) The maximum number of retries that
  is performed when opening a stream over HTTP.  A retry is made
  whenever a 4xx- or 5xx-range HTTP status code is returned.  Default
  is 1.

  * parse_headers(+boolean) Whether HTTP headers are parsed according
  to HTTP 1.1 grammars.  Default is `false`.

@author Wouter Beek
@version 2016/07
*/

:- use_module(library(apply)).
:- use_module(library(debug)).
:- use_module(library(http/http_cookie)).     % HTTP cookie support
:- use_module(library(http/http_io)).         % Extend open hook
:- use_module(library(http/http_json)).       % JSON support
:- use_module(library(http/http_open)).       % HTTP support
:- use_module(library(http/http_ssl_plugin)). % HTTPS support
:- use_module(library(http/http11)).
:- use_module(library(iri/iri_ext)).
:- use_module(library(option)).
:- use_module(library(print_ext)).
:- use_module(library(ssl)).                  % SSL support
:- use_module(library(uri)).

:- meta_predicate
    http_get(+, 1),
    http_get(+, 1, +),
    http_post(+, +, 1),
    http_post(+, +, 1, +),
    http_retry_until_success(0),
    http_retry_until_success(0, +).

:- multifile
    iostream:open_hook/6.

:- public
    ssl_verify/5.

ssl_verify(_SSL, _ProblemCertificate, _AllCertificates, _FirstCertificate, _Error).





%! deb_http_error(+Iri, +Status, +In, +Opts) is det.

deb_http_error(Iri, Status, In, Opts) :-
  debugging(open_any(http(error))), !,
  option(raw_headers(Headers), Opts),
  http_error_msg(Iri, Status, Headers, In).
deb_http_error(_, _, _, _).



%! deb_http_headers(+Lines) is det.

deb_http_headers(Lines) :-
  debugging(io(http(headers))), !,
  maplist(deb_http_header, Lines).
deb_http_headers(_).


deb_http_header(Line) :-
  string_codes(Str, Line),
  msg_notification("~s~n", [Str]).



%! http_default_success(+In, +M1, -M2) is det.

http_default_success(In, M, _) :-
  print_dict(M),
  copy_stream_data(In, user_output).



%! http_get(+Iri) is det.
%! http_get(+Iri, :Goal_3) is det.
%! http_get(+Iri, :Goal_3, +Opts) is det.

http_get(Iri) :-
  http_get(Iri, http_default_success).

http_get(Iri, Goal_3) :-
  http_get(Iri, Goal_3, []).

http_get(Iri, Goal_3, Opts0) :-
  merge_options([method(get)], Opts0, Opts),
  call_on_stream(Iri, Goal_3, Opts).



%! http_error_msg(+Iri, +Status, +Lines, +In) is det.

http_error_msg(Iri, Status, Lines, In) :-
  maplist([Cs,Header]>>phrase('header-field'(Header), Cs), Lines, Headers),
  create_grouped_sorted_dict(Headers, http_headers, MetaHeaders),
  (http_status_label(Status, Lbl) -> true ; Lbl = "No Label"),
  dcg_with_output_to(string(Str1), dict(MetaHeaders, 2)),
  read_input_to_string(In, Str2),
  msg_warning(
    "HTTP ERROR:~n  Response:~n    ~d (sa)~n  Final IRI:~n    ~a~n  Parsed headers:~n~s~nMessage content:~n~s~n",
    [Status,Lbl,Iri,Str1,Str2]
  ).



%! http_get_dict(+Key, +Meta, -Val) is nondet.

http_get_dict(Key, Meta, Val) :-
  get_dict(http_communication, Meta, Metas),
  last(Metas, Meta0),
  get_dict(Key, Meta0, Val).



%! http_header(+Key, +Meta, -Val) is nondet.

http_header(Key, Meta, Val) :-
  http_get_dict(headers, Meta, Headers),
  get_dict(Key, Headers, Vals),
  member(Val, Vals).



%! http_is_redirect_limit_exceeded(+State) is semidet.

http_is_redirect_limit_exceeded(State) :-
  State.max_redirects == inf, !,
  fail.
http_is_redirect_limit_exceeded(State) :-
  length(State.visited, Len),
  Len > State.max_redirects.



%! http_is_redirect_loop(+Iri, +State) is semidet.

http_is_redirect_loop(Iri, State) :-
  include(==(Iri), State.visited, L),
  length(L, Len),
  Len >= 2.



%! http_is_scheme(+Scheme) is semidet.

http_is_scheme(http).
http_is_scheme(https).



iostream:open_hook(Iri, read, In, Close_0, Opts1, Opts2) :-
  option(max_redirects(MaxRedirect), Opts1, 5),
  option(max_retries(MaxRetry), Opts1, 1),
  State = _{
    max_redirects: MaxRedirect,
    max_retries: MaxRetry,
    redirects: 0,
    retries: 0,
    visited: []
  },
  http_open1(Iri, State, In, Close_0, MetaHttps, Opts1),
  (   option(base_iri(BaseIri), Opts1)
  ->  true
  ;   iri_remove_fragment(Iri, BaseIri)
  ),
  Meta = _{base_iri: BaseIri, http_communication: MetaHttps},
  % Make sure the metadata is accessible even in case of an HTTP error
  % code.
  (   MetaHttps = [Meta0|_],
      http_get_dict(status, Meta0, Status),
      http_status_is_error(Status)
  ->  existence_error(http_open, Meta)
  ;   true
  ),
  merge_options([meta(Meta)], Opts1, Opts2).


http_open1(Iri, State, In3, Close2_0, Metas, Opts0) :-
  copy_term(Opts0, Opts1),
  Opts2 = [
    authenticate(false),
    cert_verify_hook(cert_accept_any),
    header(location,Location),
    raw_headers(Lines),
    redirect(false),
    status_code(Status),
    version(Major-Minor)
  ],
  merge_options(Opts1, Opts2, Opts3),
  call_time(catch(http_open(Iri, In1, Opts3), E, true), Time),
  (   var(E)
  ->  deb_http_headers(Lines),
      http_parse_headers(Lines, Groups, Opts0),
      dict_pairs(Headers, Groups),
      Meta = _{
        headers: Headers,
        iri: Iri,
        status: Status,
        time: Time,
        version: _{major: Major, minor: Minor}
      },
      http_open2(Iri, State, Location, In1, In2, Close1_0, Meta, Metas, Opts0)
  ;   throw(E)
  ),
  merge_options(Opts0, [mode(read)], Opts4),
  stream_compression(In2, In3, Opts4),
  (In2 == In3 -> Close2_0 = Close1_0 ; Close2_0 = close(In3)).


% Authentication error.
http_open2(Iri, State, _, In1, In2, Close_0, Meta, [Meta|Metas], Opts) :-
  http_auth_error(Meta.status),
  option(raw_headers(Lines), Opts),
  http_open:parse_headers(Lines, Headers),
  http:authenticate_client(Iri, auth_reponse(Headers, Opts, AuthOpts)), !,
  close(In1),
  http_open1(Iri, State, In2, Close_0, Metas, AuthOpts).
% Non-authentication error.
http_open2(Iri, State, _, In1, In2, Close_0, Meta, [Meta|Metas], Opts) :-
  http_error(Meta.status), !,
  call_cleanup(
    deb_http_error(Iri, Meta.status, In1, Opts),
    close(In1)
  ),
  dict_inc(retries, State),
  (   State.retries >= State.max_retries
  ->  Close_0 = true,
      Metas = []
  ;   http_open1(Iri, State, In2, Close_0, Metas, Opts)
  ).
% Redirect.
http_open2(Iri0, State, Location, In1, In2, Close_0, Meta, [Meta|Metas], Opts) :-
  http_redirect(Meta.status), !,
  close(In1),
  uri_resolve(Location, Iri0, Iri),
  dict_prepend(visited, State, Iri),
  (   http_is_redirect_limit_exceeded(State)
  ->  http_throw_max_redirect_error(Iri, State.max_redirects)
  ;   http_is_redirect_loop(Iri, State)
  ->  http_throw_looping_redirect_error(Iri)
  ;   true
  ),
  http_open:redirect_options(Opts, RedirectOpts),
  http_open1(Iri, State, In2, Close_0, Metas, RedirectOpts).
% Success.
http_open2(_, _, _, In, In, close(In), Meta, [Meta], _).




%! http_parse_headers(+Lines, -Groups, +Opts) is det.

http_parse_headers(Lines, Groups, Opts) :-
  maplist(http_parse_header1(Opts), Lines, Pairs),
  keysort(Pairs, SortedPairs),
  group_pairs_by_key(SortedPairs, Groups).


http_parse_header1(Opts, Line, Key-Val) :-
  option(parse_headers(true), Opts), !,
  phrase('header-field'(Key-Val), Line).
http_parse_header1(_, Line, Key-Val) :-
  phrase(http_parse_header2(Key, Val), Line).


http_parse_header2(Key, Val) -->
  http11:'field-name'(Key0),
  ":",
  http11:'OWS',
  rest(Val0),
  {
    atom_codes(Key, Key0),
    string_codes(Val, Val0)
  }.



%! http_post(+Iri, +Data:compound) is det.
%! http_post(+Iri, +Data:compound, :Goal_3) is det.
%! http_post(+Iri, +Data:compound, :Goal_3, +Opts) is det.

http_post(Iri, Data) :-
  http_post(Iri, Data, http_default_success).


http_post(Iri, Data, Goal_3) :-
  http_post(Iri, Data, Goal_3, []).


http_post(Iri, Data, Goal_3, Opts0) :-
  merge_options([method(post),post(Data)], Opts0, Opts),
  call_on_stream(Iri, Goal_3, Opts).



%! http_retry_until_success(:Goal_0) is det.
%! http_retry_until_success(:Goal_0, +Timeout) is det.
%
% Retry Goal_0 that uses HTTP communication until the HTTP
% communication succeeds.
%
% Timeout is the number of seconds in between consecutive calls of
% Goal_0.  The default timeout is 10 seconds.

http_retry_until_success(Goal_0) :-
  http_retry_until_success(Goal_0, 10).


http_retry_until_success(Goal_0, Timeout) :-
  catch(Goal_0, E, true),
  (   % HTTP success status code
      var(E)
  ->  true
  ;   % HTTP error status code
      E = error(existence_error(_,M),_),
      http_get_dict(status, M, Status),
      (http_status_label(Status, Lbl) -> true ; Lbl = 'NO LABEL')
  ->  debug(bgt(scrape), "Status: ~D (~s)", [Status,Lbl]),
      sleep(Timeout),
      http_retry_until_success(Goal_0)
  ;   % TCP error (Try Again)
      E = error(socket_error('Try Again'), _)
  ->  debug(bgt(scrape), "TCP Try Again", []),
      sleep(Timeout),
      http_retry_until_success(Goal_0)
  ).



%! http_status_label(+Code:between(100,599), -Lbl) is det.

http_status_label(Code, Lbl):-
  http_header:status_number_fact(Fact, Code),
  string_phrase(http_header:status_comment(Fact), Lbl).



%! http_status_is_auth_error(+Status) is semidet.

http_status_is_auth_error(401).



%! http_status_is_error(+Status) is semidet.

http_status_is_error(Status):-
  between(400, 599, Status).



%! http_status_is_redirect(+Status) is semidet.

http_status_is_redirect(Status) :-
  between(300, 399, Status).



%! http_throw_looping_redirect_error(+Iri) is det.

http_throw_looping_redirect_error(Iri) :-
  throw(
    error(
      permission_error(redirect, http, Iri),
      context(_, 'Redirection loop')
    )
  ).



%! http_throw_max_redirect_error(+Iri, +Max) is det.

htttp_throw_max_redirect_error(Iri, Max) :-
  format(atom(Comment), "max_redirect (~w) limit exceeded", [Max]),
  throw(
    error(
      permission_error(redirect, http, Iri),
      context(_, Comment)
    )
  ).