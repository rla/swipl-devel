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
    file_directory_name(Exe, CoreDir),
    file_directory_name(CoreDir, RelBinDir),
    working_directory(PWD, PWD),
    absolute_file_name(RelBinDir, BinDir,
                       [ file_type(directory),
                         relative_to(PWD)
                       ]).

cmake_source_directory(SrcDir) :-
    cmake_binary_directory(BinDir),
    file_directory_name(BinDir, SrcDir).

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
    assertz(user:file_search_path(jar, JarDir)),
    (   current_prolog_flag(wine_version, _)
    ->  unsetenv('JAVA_HOME')           % cross compiling
    ;   true
    ).
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

:- forall(swipl_package(Pkg, PkgBinDir),
          add_package(Pkg, PkgBinDir)).


		 /*******************************
		 *        DOCUMENTATION		*
		 *******************************/

user:file_search_path(swi_man_manual, ManDir) :-
    cmake_binary_directory(BinDir),
    atomic_list_concat([BinDir, 'man/Manual'], /, ManDir).
user:file_search_path(swi_man_packages, BinDir) :-
    swipl_package(_, BinDir).