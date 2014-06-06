
# Copyright (c) 2014 Stefan.Eilemann@epfl.ch
# Creates a <project>-package and packages target to be executed on a release machine

function(PACKAGE name)
  string(TOUPPER ${name} NAME)
  if(TARGET ${name}-package OR ${NAME}_OPTIONAL OR NOT TARGET ${name}-only)
    return()
  endif()
  if(NOT TARGET packages)
    add_custom_target(packages)
    set_target_properties(packages PROPERTIES EXCLUDE_FROM_ALL ON)
  endif()

  # dependencies first - use_external already processed the basics
  foreach(_dep ${${NAME}_DEPENDS})
    package(${_dep})
  endforeach()

  get_property(cmd_set TARGET ${name} PROPERTY _EP_BUILD_COMMAND SET)
  if(cmd_set)
    get_property(cmd TARGET ${name} PROPERTY _EP_BUILD_COMMAND)
  else()
    _ep_get_build_command(${name} BUILD cmd)
  endif()

  add_custom_target(${name}-packagedir
    COMMAND ${CMAKE_COMMAND} -E make_directory "${${NAME}_SOURCE}/packagebuild"
    COMMENT "Create ${name} package build directory"
    WORKING_DIRECTORY "${${NAME}_SOURCE}"
    )
  add_custom_target(${name}-package
    COMMAND ${CMAKE_COMMAND} -DCMAKE_BUILD_TYPE=Release ..
    COMMAND ${cmd} package-install
    COMMENT "Build and sudo install ${name} package"
    WORKING_DIRECTORY "${${NAME}_SOURCE}/packagebuild"
    DEPENDS ${name}-packagedir ${name}-only
    )
  add_dependencies(packages ${name}-package)

  foreach(_dep ${${NAME}_DEPENDS})
    if(TARGET ${_dep}-package)
      add_dependencies(${name}-package ${_dep}-package)
    endif()
  endforeach()

  set_target_properties(${name}-packagedir PROPERTIES EXCLUDE_FROM_ALL ON)
  set_target_properties(${name}-package PROPERTIES EXCLUDE_FROM_ALL ON)
endfunction()
