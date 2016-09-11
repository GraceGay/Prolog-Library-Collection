:- module(
  file_ext,
  [
    absolute_file_name_number/4, % +Spec:compound
                                 % +Number:integer
                                 % -Abs:atom
                                 % +Opts
    common_prefix_path/3, % +Path1:atom
                          % +Path2:atom
                          % ?CommonPrefixPath:atom
    create_file/4, % +Spec:term
                   % +Name:atom
                   % +Type:atom
                   % -File:atom
    file_alternative/5, % +FromPath:atom
                        % ?Dir:atom
                        % ?Name:atom
                        % ?Ext:atom
                        % -ToPath:atom
    file_component/3, % +Path:atom
                      % ?Field:oneof([base,directory,extension,file_type,local])
                      % ?Component:atom
    file_components/4, % +Path:atom
                       % ?Dir:atom
                       % ?Base:atom
                       % ?Ext:atom
    file_kind_alternative/2, % +Path1:atom
                             % ?Path2:atom
    file_kind_alternative/3, % +FromPath:atom
                             % +ToFileKind:atom
                             % -ToPath:atom
    file_kind_extension/2, % +FileKind:atom
                           % ?Ext:atom
    hidden_file_name/2, % +Path:atom
                        % ?HiddenPath:atom
    local_file_component/3, % ?Local:atom
                            % ?Field:oneof([base,extension])
                            % ?Component:atom
    local_file_components/3, % ?Local:atom
                             % ?Base:atom
                             % ?Ext:atom
    merge_into_one_file/2, % +FromDir:atom
                           % +ToFile:atom
    new_file_name/2, % +Path1:atom
                     % -Path2:atom
    prefix_path/2 % ?PrefixPath:atom
                  % +Path:atom
  ]
).

/** <module> File extensions

Additional support predicates for creating, opening, removing,
and searching files.
These are to be used in addition to
[SWI-Prolog file build-ins](http://www.swi-prolog.org/pldoc/man?section=files)
and
[`library(filesex)`](http://www.swi-prolog.org/pldoc/man?section=filesex).

# Terminology

I am not aware of a standardized vocabulary about files
(although the POSIX standard may contain one?).
Here is my ad-hoc attempt:

Concepts:
  - **File**
  - **Directory**
  - **File link**

Terms:
  - **Abs path**
    A path whose first character is a root character.
  - **Base file name**
    An atom.
  - **Directory name**
    A file name that is a sequence of atoms separated by directory separators.
    Every prefix of a directory name that ends at a directory separator
    denoted a directory.
  - **File extension**
    An atom.
  - **Local file name**
    A local file name is
    (1) a base file name that is optionally followed by
    (2a) the file extension separator and (2b) a file extension.
  - **Path**
    A file name that consists of
    (1) directories separated by directory separators
    and an optional (2) local file name
    If a local file name is present the path denotes a file.
    If no local file name is present the path denotes a directory.
  - **Relative path**
    A path whose first character is not a root character.

## Variable names

In line with the terminology this modules uses the following variable names:
  - `Abs` to denote absolute paths.
  - `Base` to denote base file names.
  - `Dir` to denote directory names.
  - `Ext` to denote file extensions.
  - `FileKind` to denote either a registered file type or a file extension
     (in that order).
  - `FileType` to denote a registered file type mapped onto
     at least one file extension.
  - `Local` to denote local file names.
  - `Path` to denote paths.
  - `Rel` to denote relative paths.
  - `Spec` for file specifications (i.e., compound terms)
     handled by absolute_file_name/[2,3].

---

@author Wouter Beek
@version 2015/07, 2015/12
*/

:- use_module(library(apply)).
:- use_module(library(error)).
:- use_module(library(filesex)).
:- use_module(library(lists)).

:- predicate_options(absolute_file_name_number/4, 4, [
     pass_to(absolute_file_name/3, 3)
   ]).

error:has_type(absolute_path, Term) :-
  error:has_type(atom, Term),
  root_prefix(Root),
  atom_concat(Root, _, Term).





%! absolute_file_name_number(
%!   +Spec:compound,
%!   +Number:nonneg,
%!   -Abs:atom,
%!   +Opts
%! ) is det.
% This comes in handy for numbered files, e.g. '/home/some_user/test_7.txt'.
%
% Options are passed to absolute_file_name/3.

absolute_file_name_number(Spec, Number, Abs, Opts) :-
  format(atom(Atom), '_~d', [Number]),
  spec_atomic_concat(Spec, Atom, NumberedSpec),
  absolute_file_name(NumberedSpec, Abs, Opts).



%! common_prefix_path(
%!   +Path1:atom,
%!   +Path2:atom,
%!   +CommonPrefixPath:atom
%! ) is semidet.
%! common_prefix_path(
%!   +Path1:atom,
%!   +Path2:atom,
%!   -CommonPrefixPath:atom
%! ) is det.
% Succeeds id Path1 and Path2 share the same CommonPrefixPath.

common_prefix_path(Path1, Path2, CommonPrefixPath) :-
  directory_subdirectories(Path1, PathComponents1),
  directory_subdirectories(Path2, PathComponents2),
  common_list_prefix(PathComponents1, PathComponents2, CommonComponentPrefix),
  directory_subdirectories(CommonPrefixPath, CommonComponentPrefix).



%! create_file(+Spec:compound, +Base:atom, +FileKind:atom, -Abs:atom) is det.
% Creates a file with:
%   - the given directory
%   - the given base name
%   - the given file type
%
% File types are resolved using prolog_file_type/2.
%
% @arg Spec The atomic name of a directory or a compound term that
%      can be resolved by absolute_file_name/2.
% @arg Base A file base name.
% @arg FileKind Either a registered file type or a file extension.
% @arg Abs An absolute file path.

create_file(Spec, Base, FileKind, Path) :-
  % Resolve the directory in case the compound term notation employed
  % by absolute_file_name/3 is used.
  absolute_file_name(Spec, Dir, [access(write),file_type(directory)]),

  % Make sure that the directory exists.
  make_directory_path(Dir),

  % Create the local file name by appending the file base name
  % and the file extension.
  % The extension must be of the given type.
  once(file_kind_extension(FileKind, Ext)),
  local_file_components(Local, Base, Ext),

  % Append directory and file name.
  directory_file_path(Dir, Local, Path),

  create_file(Path).



%! file_alternative(
%!   +FromPath:atom,
%!   ?ToDirectory:atom,
%!   ?ToBase:atom,
%!   ?ToExtension:atom,
%!   -ToPath:atom
%! ) is det.
% Creates a file name that is similar to a given file name,
% by allowing different components to be specified:
%   - directory name
%   - base file name
%   - file extension

file_alternative(FromPath, ToDir, ToBase, ToExt, ToPath) :-
  file_components(FromPath, FromDir, FromBase, FromExt),
  defval(FromDir, ToDir),
  defval(FromBase, ToBase),
  defval(FromExt, ToExt),
  file_components(ToPath, ToDir, ToBase, ToExt).



%! file_component(
%!   +Path:atom,
%!   +Field:oneof([base,directory,extension,file_type,local]),
%!   +Component:atom
%! ) is semidet.
%! file_component(
%!   +Path:atom,
%!   +Field:oneof([base,directory,extension,file_type,local]),
%!   -Component:atom
%! ) is multi.
%! file_component(
%!   +Path:atom,
%!   -Field:oneof([base,directory,extension,file_type,local]),
%!   -Component:atom
%! ) is multi.

file_component(Path, Field, Component) :-
  call_det(file_component0, nonvar-Path, nonvar-Field, any-Component).

file_component0(Path, base, Base) :-
  file_components(Path, _, Base, _).
file_component0(Path, directory, Dir) :-
  file_components(Path, Dir, _, _).
file_component0(Path, extension, Ext) :-
  file_components(Path, _, _, Ext).
file_component0(Path, file_type, FileType) :-
  file_component0(Path, extension, Ext),
  user:prolog_file_type(Ext, FileType).
file_component0(Path, local, Local) :-
  directory_file_path(_, Local, Path).



%! file_components(+Path:atom, +Dir:atom, +Base:atom, +Ext:atom) is semidet.
%! file_components(+Path:atom, -Dir:atom, -Base:atom, -Ext:atom) is det.
%! file_components(-Path:atom, +Dir:atom, +Base:atom, +Ext:atom) is det.
% Relates a file path to its components:
%   - directory
%   - base name
%   - file extension
%
% For directories, the base name and file extension are the empty atom.

file_components(Path, Dir, Base, Ext) :-
  nonvar(Path), !,
  (   exists_directory(Path)
  ->  Dir = Path,
      Base = '',
      Ext = ''
  ;   directory_file_path(Dir, Local, Path),
      file_name_extension(Base, Ext, Local)
  ).
file_components(Path, Dir, Base, Ext) :-
  maplist(nonvar, [Dir,Base,Ext]), !,
  file_name_extension(Base, Ext, Local),
  directory_file_path(Dir, Local, Path).
file_components(_, _, _, _) :-
  instantiation_error(_).



%! file_kind_alternative(+Path1:atom, +Path2:atom) is semidet.
% Succeeds if the files are type-alternatives of each other.

file_kind_alternative(Path1, Path2) :-
  file_component(Path1, directory, Dir),
  file_component(Path2, directory, Dir),
  file_component(Path1, base, Dir),
  file_component(Path2, base, Dir).



%! file_kind_alternative(
%!   +FromFile:atom,
%!   +ToFileKind:atom,
%!   -ToFile:atom
%! ) is det.
% Returns an alternative of the given file with the given file type.

file_kind_alternative(FromFile, ToFileKind, ToFile) :-
  file_kind_extension(ToFileKind, ToExt),
  file_alternative(FromFile, _, _, ToExt, ToFile).



%! file_kind_extension(+FileKind:atom, +Ext:atom) is semidet.
%! file_kind_extension(+FileKind:atom, -Ext:atom) is nondet.
% Returns the extensions associated with the given file kind.
%
% These are either:
%   - all extensions registered with file type FileKind, or
%   - FileKind itself.
%
% @throws instantiation_error If FileKind is uninstantiated.

file_kind_extension(FileType, _) :-
  var(FileType), !,
  instantiation_error(FileType).
file_kind_extension(FileType, Ext) :-
  \+ user:prolog_file_type(_, FileType), !,
  Ext = FileType.
file_kind_extension(FileType, Ext) :-
  user:prolog_file_type(Ext, FileType).



%! hidden_file_name(+Path:atom, +HiddenPath:atom) is semidet.
%! hidden_file_name(+Path:atom, -HiddenPath:atom) is det.
% Returns the hidden file name for the given atomic name.

hidden_file_name(Path, HiddenPath) :-
  file_components(Path, Dir, Base, Ext),
  atomic_concat(., Base, HiddenBase),
  file_components(HiddenPath, Dir, HiddenBase, Ext).



%! local_file_component(
%!   +Local:atom,
%!   +Field:oneof([base,extension]),
%!   +Component:atom
%! ) is semidet.

local_file_component(Local, base, Base) :-
  call_det(local_file_component0(Local, base, Base)).

local_file_component0(Local, base, Base) :-
  local_file_components(Local, Base, _).
local_file_component0(Local, extension, Ext) :-
  local_file_components(Local, _, Ext).



%! local_file_components(+Local:atom, +Base:atom, +Ext:atom) is semidet.
%! local_file_components(+Local:atom, -Base:atom, -Ext:atom) is semidet.
%! local_file_components(-Local:atom, +Base:atom, +Ext:atom) is semidet.
% Relates a local file name to its components:
%   - base file name
%   - file extension
%
% @throws instantiation_error

local_file_components(Local, Base, Ext) :-
  nonvar(Local), !,
  (   atomic_list_concat([Base,Ext], ., Local)
  ->  true
  ;   Base = Local,
      Ext = ''
  ).
local_file_components(Local, Base, Ext) :-
  maplist(nonvar, [Base,Ext]), !,
  (   Ext == ''
  ->  Local = Base
  ;   atomic_list_concat([Base,Ext], ., Local)
  ).
local_file_components(_, _, _) :-
  instantiation_error(_).



%! merge_into_one_file(+FromFiles:list(atom), +ToFile:atom) is det.

merge_into_one_file(FromFiles, ToFile) :-
  setup_call_cleanup(
    open(ToFile, write, Out, [type(binary)]),
    maplist(merge_into_one_stream(Out), FromFiles),
    close(Out)
  ).

merge_into_one_stream(Out, FromFile) :-
  setup_call_cleanup(
    open(FromFile, read, In, [type(binary)]),
    copy_stream_data(In, Out),
    close(In)
  ).



%! new_file_name(+Path1:atom, -Path2:atom) is det.
% If a file with the same name exists in the same directory,
%  then a distinguishing integer is appended to the file name.
% Otherwise the file itself is returned.

% The file does not yet exist; done.
new_file_name(Path, Path) :-
  \+ exists_file(Path), !.
% The file already exists.
new_file_name(Path1, Path3) :-
  file_component(Path1, base, Base1),
  new_atom(Base1, Base2),
  file_alternative(Path1, _, Base2, _, Path2),
  new_file_name(Path2, Path3).



%! prefix_path(+PrefixPath:atom, +Path:atom) is semidet.
%! prefix_path(-PrefixPath:atom, +Path:atom) is multi.

prefix_path(_, Path) :-
  var(Path), !,
  instantiation_error(Path).
prefix_path(PrefixPath, Path) :-
  var(PrefixPath), !,
  directory_subdirectories(Path, Components),
  prefix(PrefixComponents, Components),
  directory_subdirectories(PrefixPath, PrefixComponents).
prefix_path(PrefixPath, Path) :-
  directory_subdirectories(PrefixPath, PrefixComponents),
  directory_subdirectories(Path, Components),
  prefix(PrefixComponents, Components).





% HELPERS %

%! spec_atomic_concat(+Spec, +Atomic:atom, -NewSpec) is det.
% Concatenates the given atom to the inner atomic term of the given
% specification.

spec_atomic_concat(Atomic1, Atomic2, Atom) :-
  atomic(Atomic1), !,
  atomic_concat(Atomic1, Atomic2, Atom).
spec_atomic_concat(Spec1, Atomic, Spec2) :-
  compound(Spec1), !,
  Spec1 =.. [Outer,Inner1],
  spec_atomic_concat(Inner1, Atomic, Inner2),
  Spec2 =.. [Outer,Inner2].
