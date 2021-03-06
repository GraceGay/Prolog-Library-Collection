:- module(
  html_ext,
  [
    html_download/2,    % +Uri, -Dom
    html_download/3,    % +Uri, -Dom, +Options
    html_insert_dom//1, % +Dom
  ]
).

%! html_download(+Uri:atom, -Dom:list(compound)) is det.
%! html_download(+Uri:atom, -Dom:list(compound), +Options:list(compound)) is det.
%
% @arg Options are passed to http_open2/3 and load_html/3.

html_download(Uri, Dom) :-
  html_download(Uri, Dom, []).


html_download(Uri, Dom2, Options) :-
  setup_call_cleanup(
    http_open2(Uri, In, Options),
    (
      merge_options([encoding('utf-8'),max_errors(-1)], Options, HtmlOptions),
      load_html(In, Dom1, HtmlOptions),
      clean_dom(Dom1, Dom2)
    ),
    close(In)
  ).



%! html_insert_dom(+Dom:list(compound))// is det.

html_insert_dom(Dom) -->
  {with_output_to(atom(Atom), xml_write_canonical(current_output, Dom, []))},
  html(\[Atom]).
