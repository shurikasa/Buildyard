
# Copyright (c) 2012-2014 Stefan.Eilemann@epfl.ch

cmake_minimum_required(VERSION 2.8 FATAL_ERROR)
project(Buildyard)

set(VERSION_MAJOR "2013")
set(VERSION_MINOR "9")
set(VERSION_PATCH "0")
set(RELEASE_VERSION 0) # OFF or ABI version


list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/CMake
  ${CMAKE_CURRENT_SOURCE_DIR}/CMake/common)
set(GITTARGETS_RELEASE_BRANCH current)

include(GitExternal)
include(ReadConfigs)
add_custom_target(default ALL)

if(BUILDYARD_TARGETS)
  add_dependencies(default ${BUILDYARD_TARGETS})
else()
  foreach(PROJECT ${BUILDING})
    get_target_property(_optional ${PROJECT} _EP_IS_OPTIONAL_PROJECT)
    if(NOT _optional)
      add_dependencies(default ${PROJECT})
    endif()
  endforeach()
endif()
