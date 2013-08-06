
# Copyright (c) 2012 Stefan Eilemann <Stefan.Eilemann@epfl.ch>

cmake_minimum_required(VERSION 2.8 FATAL_ERROR)
project(Buildyard)

set(VERSION_MAJOR "2013")
set(VERSION_MINOR "6")
set(VERSION_PATCH "0")
set(RELEASE_VERSION 0) # OFF or ABI version

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/CMake)
set(GITTARGETS_RELEASE_BRANCH current)

include(ReadConfigs)
add_custom_target(default ALL)

if(BUILDYARD_TARGETS)
  add_dependencies(default ${BUILDYARD_TARGETS})
else()
  add_dependencies(default ${BUILDING})
endif()
