/*  Part of SWI-Prolog

    Author:        Jan Wielemaker
    E-mail:        J.Wielemaker@vu.nl
    WWW:           http://www.swi-prolog.org
    Copyright (c)  2018, VU University Amsterdam
                         CWI, Amsterdam
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions
    are met:

    1. Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.

    2. Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in
       the documentation and/or other materials provided with the
       distribution.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
    COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
    LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
    ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
    POSSIBILITY OF SUCH DAMAGE.
*/

:- module(prolog_build_home, []).
:- use_module(library(lists)).
:- use_module(library(pure_input)).

/** <module> Setup SWI-Prolog to run from the build directory

This module is loaded if SWI-Prolog  is   started  in the build tree and
sets up paths such that all packages can be loaded and the system can be
used interactively similar to the installed  system. This serves several
purposes:

  - We can easily debug the various installations
  - We can easily develop
  - We can build the documentation without installing

This file is normally installed in `CMAKE_BINARY_DIRECTORY/home`.
*/

%!  cmake_binary_directory(-BinDir) is det.
%!  cmake_source_directory(-SrcDir) is det.
%
%   Find    the    equivalent    of      =CMAKE_BINARY_DIRECTORY=    and
%   CMAKE_SOURCE_DIRECTORY.

cmake_binary_directory(BinDir) :-
    current_prolog_flag(executable, OsExe),
    prolog_to_os_filename(Exe, OsExe),
    working_directory(PWD, PWD),
    absolute_file_name(Exe, AbsExe,
                       [ access(execute),
                         relative_to(PWD)
                       ]),
    file_directory_name(AbsExe, AbsExeDir),
    file_directory_name(AbsExeDir, ParentDir),
    (   file_base_name(ParentDir, packages)
    ->  file_directory_name(ParentDir, BinDir)
    ;   BinDir = ParentDir
    ).

%!  cmake_source_directory(-SrcDir) is det.
%
%   Find the SWI-Prolog source directory. First   try .. from the binary
%   dir, that try the binary dir   and finally read the =CMakeLists.txt=
%   file. We take these three steps because   the  first two are quicker
%   and I'm not sure how much we can rely on the CMakeCache.txt content.

cmake_source_directory(SrcDir) :-
    cmake_binary_directory(BinDir),
    (   file_directory_name(BinDir, SrcDir)
    ;   SrcDir = BinDir
    ),
    atomic_list_concat([SrcDir, 'CMakeLists.txt'], /, CMakeFile),
    exists_file(CMakeFile),
    is_swi_prolog_cmake_file(CMakeFile),
    !.
cmake_source_directory(SrcDir) :-
    cmake_binary_directory(BinDir),
    atomic_list_concat([BinDir, 'CMakeCache.txt'], /, CacheFile),
    phrase_from_file(source_dir(SrcDir), CacheFile).

is_swi_prolog_cmake_file(File) :-
    setup_call_cleanup(
        open(File, read, In),
        is_swi_prolog_stream(In),
        close(In)).

is_swi_prolog_stream(In) :-
    repeat,
    read_string(In, "\n", "\t ", Sep, Line),
    (   Sep == -1
    ->  !, fail
    ;   sub_string(Line, _, _, _, "project(SWI-Prolog)")
    ),
    !.

source_dir(SrcDir) -->
    string(_),
    `SWI-Prolog_SOURCE_DIR:STATIC=`,
    string(Codes), `\n`,
    !,
    skip_remaining,
    { atom_codes(SrcDir, Codes) }.

string([]) --> [].
string([H|T]) --> [H], string(T).

skip_remaining(_,_).


%!  swipl_package(-Pkg, -PkgBinDir) is nondet.
%
%   True when Pkg is available in the build tree at the given location.

swipl_package(Pkg, PkgBinDir) :-
    cmake_binary_directory(CMakeBinDir),
    atomic_list_concat([CMakeBinDir, packages], /, PkgRoot),
    exists_directory(PkgRoot),
    directory_files(PkgRoot, Candidates),
    member(Pkg, Candidates),
    \+ special(Pkg),
    atomic_list_concat([PkgRoot, Pkg], /, PkgBinDir),
    atomic_list_concat([PkgBinDir, 'CMakeFiles'], /, CMakeDir),
    exists_directory(CMakeDir).

special(.).
special(..).

:- multifile user:file_search_path/2.
:- dynamic   user:file_search_path/2.

user:file_search_path(library, swi(packages)).

%!  add_package(+Package, +PkgSrcDir, +PkgBinDir) is det.
%
%   Setup the source paths and initialization for Package with the given
%   source and binary location.

add_package(xpce, PkgBinDir) :-
    !,
    add_package_path(PkgBinDir),
    cmake_source_directory(Root),
    atomic_list_concat([Root, 'packages/xpce/swipl/swipl-rc'], /, PceLinkFile),
    use_module(PceLinkFile).
add_package(chr, PkgBinDir) :-
    assertz(user:file_search_path(chr, PkgBinDir)),
    assertz(user:file_search_path(chr, library(chr))),
    assertz(user:file_search_path(library, PkgBinDir)).
add_package(jpl, PkgBinDir) :-
    add_package_path(PkgBinDir),
    atomic_list_concat([PkgBinDir, 'src/java'], /, JarDir),
    assertz(user:file_search_path(jar, JarDir)).
add_package(http, PkgBinDir) :-
    add_package_path(PkgBinDir),
    file_directory_name(PkgBinDir, PkgDir),
    assertz(user:file_search_path(library, PkgDir)).
add_package(_Pkg, PkgBinDir) :-
    add_package_path(PkgBinDir).

%!  add_package_path(+PkgBinDir) is det.
%
%   Add the source  and  binary  directories   for  the  package  to the
%   `library` and `foreign` search paths. Note that  we only need to add
%   the binary directory if  it  contains   shared  objects,  but  it is
%   probably cheaper to add it anyway.

add_package_path(PkgBinDir) :-
    assertz(user:file_search_path(foreign, PkgBinDir)).

:- if(\+ current_prolog_flag(emscripten, true)).
:- forall(swipl_package(Pkg, PkgBinDir),
          add_package(Pkg, PkgBinDir)).
:- endif.

%!  set_version_info
%
%   Indicate we are running from the   build directory rather than using
%   an installed version.

set_version_info :-
    cmake_binary_directory(BinDir),
    version(format('    CMake built from "~w"', [BinDir])).

:- if(\+ current_prolog_flag(emscripten, true)).
:- initialization(set_version_info).
:- endif.

% Avoid getting Java from the host when running under Wine.

:- if(current_prolog_flag(wine_version, _)).
delete_host_java_home :-
    (   getenv('JAVA_HOME', Dir),
        sub_atom(Dir, 0, _, _, /)
    ->  unsetenv('JAVA_HOME')
    ;   true
    ).

:- initialization(delete_host_java_home).
:- endif.


		 /*******************************
		 *        DOCUMENTATION		*
		 *******************************/

user:file_search_path(swi_man_manual, ManDir) :-
    cmake_binary_directory(BinDir),
    atomic_list_concat([BinDir, 'man/Manual'], /, ManDir).
user:file_search_path(swi_man_packages, BinDir) :-
    swipl_package(_, BinDir).


		 /*******************************
		 *        CONFIGURATION		*
		 *******************************/

:- multifile
    prolog:runtime_config/2.

prolog:runtime_config(c_libdir, LibDir) :-
    cmake_binary_directory(BinDir),
    atomic_list_concat([BinDir, src], /, LibDir).
