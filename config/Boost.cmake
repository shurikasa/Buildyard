# set(Boost_DEBUG TRUE)
set(BOOST_PACKAGE_MINOR_VERSION 41)
set(BOOST_PACKAGE_VERSION 1.${BOOST_PACKAGE_MINOR_VERSION}.0)
set(BOOST_REPO_URL https://github.com/boostorg/boost.git)
set(BOOST_REPO_TAG boost-1.56.0)
set(BOOST_SOURCE "${CMAKE_SOURCE_DIR}/src/Boost")
set(BOOST_OPTIONAL ON)
set(BOOST_CMAKE_INCLUDE "SYSTEM")

set(BOOST_BUILD_LIBRARIES serialization system regex date_time thread filesystem
                          program_options test)
find_package(PythonLibs QUIET)
if(PYTHONLIBS_FOUND)
  list(APPEND BOOST_BUILD_LIBRARIES python)
endif()

set(WITH_LIBRARIES)

if(MSVC)
  string(REGEX REPLACE "Visual Studio ([0-9]+)[ ]*[0-9]*" "msvc-\\1.0"
    TOOLSET ${CMAKE_GENERATOR})
  if(TOOLSET MATCHES "Win64")
    string(REGEX REPLACE "([0-9.]+) Win64" "\\1" TOOLSET ${TOOLSET})
    set(ADDRESS 64)
    set(PROGRAM_PREFIX $ENV{PROGRAMW6432})
  else()
    set(ADDRESS 32)
    set(PROGRAM_PREFIX $ENV{PROGRAMFILES})
  endif()

  # Add default boost installation paths to search list
  foreach(MINOR RANGE ${BOOST_PACKAGE_MINOR_VERSION} 70)
    list(APPEND CMAKE_PREFIX_PATH "${PROGRAM_PREFIX}/boost/boost_1_${MINOR}")
    foreach(PATCH RANGE 0 2)
      list(APPEND CMAKE_PREFIX_PATH
        "${PROGRAM_PREFIX}/boost/boost_1_${MINOR}_${PATCH}")
    endforeach()
  endforeach()

  set(BATFILE "${BOOST_SOURCE}/b3_${TOOLSET}.${ADDRESS}.bat")
  foreach(WITH_LIBRARY ${BOOST_BUILD_LIBRARIES})
    list(APPEND WITH_LIBRARIES " --with-${WITH_LIBRARY}")
  endforeach()
  string(REGEX REPLACE ";" " " WITH_LIBRARIES ${WITH_LIBRARIES})
  file(WRITE "${BATFILE}"
    "set VS_UNICODE_OUTPUT=\n"
    "b2 --layout=tagged toolset=${TOOLSET} address-model=${ADDRESS} ${WITH_LIBRARIES} link=shared \"--prefix=${CMAKE_CURRENT_BINARY_DIR}/install\" %1 %2 %3 %4\n"
)
  set(BOOTSTRAP bootstrap.bat)
  set(BTWO ${BATFILE})
else()
  foreach(WITH_LIBRARY ${BOOST_BUILD_LIBRARIES})
    list(APPEND WITH_LIBRARIES "${WITH_LIBRARY},")
  endforeach()
  string(REGEX REPLACE ";" " " WITH_LIBRARIES ${WITH_LIBRARIES})
  set(BOOTSTRAP ./bootstrap.sh "--prefix=${CMAKE_CURRENT_BINARY_DIR}/install" --with-libraries=${WITH_LIBRARIES})
  set(BTWO ./b2)
  if(APPLE)
    set(BTWO ${BTWO} address-model=32_64)
  elseif("$ENV{CC}}" MATCHES "xlc")
    set(BTWO ${BTWO} toolset=vacpp address-model=64 cxxflags=-qsmp=omp:noopt)
  else()
    set(BTWO ${BTWO} toolset=gcc)
  endif()
endif()

set(BOOST_EXTRA
  CONFIGURE_COMMAND cd ${BOOST_SOURCE} && ${BOOTSTRAP}
  BUILD_COMMAND cd ${BOOST_SOURCE} && ${BTWO} -j8
  INSTALL_COMMAND cd ${BOOST_SOURCE} && ${BTWO} headers -j8 install
)
