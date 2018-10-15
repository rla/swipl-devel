# Installation of SWI-Prolog data files that are literally
# copied from the sources to their installation location.
#
# We want to use this to create a shadow data tree in the
# CMAKE_BINARY_DIRECTORY such that we can run the full system
# without installing it

# ${SWIPL_BUILD_HOME} holds the direcory where we link the Prolog
# resource files.
set(SWIPL_BUILD_HOME    ${CMAKE_BINARY_DIR}/home)
set(SWIPL_BUILD_LIBRARY ${SWIPL_BUILD_HOME}/library)

add_custom_target(prolog_home)

function(symlink from to)
  get_filename_component(LNTDIR ${to} DIRECTORY)
  get_filename_component(LNTNAME ${to} NAME)
  file(RELATIVE_PATH LNLNK ${LNTDIR} ${from})
  if(NOT EXISTS ${LNTDIR})
    execute_process(COMMAND ${CMAKE_COMMAND} -E make_directory ${LNTDIR})
  endif()
  execute_process(COMMAND ${CMAKE_COMMAND} -E create_symlink
		  ${LNLNK} ./${LNTNAME}
		  WORKING_DIRECTORY ${LNTDIR})
endfunction()

function(create_directory dir)
  set(done)
  get_property(done GLOBAL PROPERTY CREATE_DIRECTORY_STATE)
  list(FIND done ${dir} index)
  if(index LESS 0)
    add_custom_command(
	OUTPUT ${LNTDIR}/.created
	COMMAND ${CMAKE_COMMAND} -E make_directory ${dir}
	COMMAND ${CMAKE_COMMAND} -E touch ${dir}/.created)
    list(APPEND	done ${dir})
    set_property(GLOBAL PROPERTY CREATE_DIRECTORY_STATE "${done}")
  endif()
endfunction()

function(add_symlink_command from to)
  get_filename_component(LNTDIR ${to} DIRECTORY)
  get_filename_component(LNTNAME ${to} NAME)
  file(RELATIVE_PATH LNLNK ${LNTDIR} ${from})
  create_directory(${LNTDIR})
  add_custom_command(
      OUTPUT ${to}
      COMMAND ${CMAKE_COMMAND} -E create_symlink ${LNLNK} ./${LNTNAME}
      WORKING_DIRECTORY ${LNTDIR}
      DEPENDS ${LNTDIR}/.created)
endfunction()

function(install_in_home name)
  cmake_parse_arguments(my "" "RENAME;DESTINATION" "FILES" ${ARGN})
  if(my_DESTINATION AND my_FILES)
    string(REPLACE
	   "${SWIPL_INSTALL_PREFIX}/"
	   "${SWIPL_BUILD_HOME}/" buildhome ${my_DESTINATION})

    set(deps)

    foreach(file ${my_FILES})
      if(NOT IS_ABSOLUTE ${file})
        set(file ${CMAKE_CURRENT_SOURCE_DIR}/${file})
      endif()
      if(my_RENAME)
        set(base ${my_RENAME})
      else()
        get_filename_component(base ${file} NAME)
      endif()
      if(NOT EXISTS ${file})
        message(FATAL_ERROR
		"Cannot link from build home: ${file} does not exist")
      endif()
      add_symlink_command(${file} ${buildhome}/${base})
      set(deps ${deps} ${buildhome}/${base})
    endforeach()

    add_custom_target(
	${name} ALL
	DEPENDS ${deps})
    add_dependencies(prolog_home ${name})
  endif()
endfunction()

function(install_src name)
  install_in_home(${name} ${ARGN})
  install(${ARGN})
endfunction()