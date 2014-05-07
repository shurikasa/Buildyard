# Copyright (c) 2013 Stefan.Eilemann@epfl.ch

# write configure command for autoconf-based projects
function(USE_EXTERNAL_AUTOCONF name)
  string(TOUPPER ${name} NAME)
  set(${NAME}_CONFIGURE_CMD
    ${CMAKE_BINARY_DIR}/${name}/${name}_configure_cmd.cmake)
  if(NOT ${NAME}_CONFIGURE_DIR)
    set(${NAME}_CONFIGURE_DIR ${CMAKE_BINARY_DIR}/${name})
  endif()

  set(CFLAGS "$ENV{CFLAGS} -I/opt/local/include -I${CMAKE_CURRENT_BINARY_DIR}/install/include")
  set(CXXFLAGS "$ENV{CXXFLAGS} -I/opt/local/include -I${CMAKE_CURRENT_BINARY_DIR}/install/include")
  set(LDFLAGS "$ENV{LDFLAGS} -L/opt/local/lib -L${CMAKE_CURRENT_BINARY_DIR}/install/lib")
  if(APPLE)
    foreach(ARCH ${CMAKE_OSX_ARCHITECTURES})
      set(CFLAGS "${CFLAGS} -arch ${ARCH}")
      set(CXXFLAGS "${CXXFLAGS} -arch ${ARCH}")
    endforeach()
    if(CMAKE_OSX_SYSROOT)
      set(CFLAGS "${CFLAGS} -isysroot ${CMAKE_OSX_SYSROOT}")
      set(CXXFLAGS "${CXXFLAGS} -isysroot ${CMAKE_OSX_SYSROOT}")
    endif()
  endif()

  file(WRITE ${${NAME}_CONFIGURE_CMD}
    "${${NAME}_PRE_CONFIGURE}\n"
    "if(NOT EXISTS ${${NAME}_SOURCE}/configure)\n"
    "  execute_process(COMMAND ${AUTORECONF_EXE} -i\n"
    "    WORKING_DIRECTORY ${${NAME}_SOURCE})\n"
    "endif()\n"
    "if(NOT EXISTS ${CMAKE_BINARY_DIR}/${name}/config.status)\n"
    "  set(ENV{CFLAGS} ${CFLAGS})\n"
    "  set(ENV{CXXFLAGS} ${CXXFLAGS})\n"
    "  set(ENV{LDFLAGS} ${LDFLAGS})\n"
    "  execute_process(COMMAND ${${NAME}_SOURCE}/configure --prefix=${CMAKE_CURRENT_BINARY_DIR}/install ${${NAME}_CONFIGURE_FLAGS}\n"
    "    WORKING_DIRECTORY ${${NAME}_CONFIGURE_DIR}\n"
    "    RESULT_VARIABLE ERROR)\n"
    "  if(ERROR)\n"
    "    execute_process(COMMAND ${CMAKE_COMMAND} -E remove ${CMAKE_BINARY_DIR}/${name}/config.status)\n"
    "    message(FATAL_ERROR \"Configure script for ${name} failed\")\n"
    "  else()\n"
    "    execute_process(COMMAND ${CMAKE_COMMAND} -E touch ${CMAKE_BINARY_DIR}/${name}/config.status)\n"
    "  endif()\n"
    "endif()\n"
    )
endfunction()
