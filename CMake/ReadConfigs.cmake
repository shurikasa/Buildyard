# Copyright (c) 2012 Stefan Eilemann <Stefan.Eilemann@epfl.ch>
# Does a use_external(..) for each config*/*.cmake project.

include(UseExternal)
include(CreateDependencyGraph)
include(GitTargets)

if(APPLE)
  find_program(TAR_EXE gnutar)
else()
  find_program(TAR_EXE tar)
endif()

find_program(AUTORECONF_EXE autoreconf)
if(NOT MSVC AND NOT AUTORECONF_EXE)
  if(APPLE)
    message(FATAL_ERROR
      "autoreconf missing, install autoconf tools (sudo port install autoconf)")
  else()
    message(FATAL_ERROR "autoreconf missing, install autoconf tools")
  endif()
endif()

macro(READ_CONFIG_DIR DIR)
  get_property(READ_CONFIG_DIR_DONE GLOBAL PROPERTY READ_CONFIG_DIR_${DIR})
  if(NOT READ_CONFIG_DIR_DONE)
    message(STATUS "Setting up ${DIR}")
    set_property(GLOBAL PROPERTY READ_CONFIG_DIR_${DIR} ON)

    set(READ_CONFIG_DIR_DEPENDS)
    if(EXISTS ${DIR}/Buildyard.txt) # deprecated, use Buildyard.cmake
      file(READ ${DIR}/Buildyard.txt BUILDYARD_REV)
      string(REGEX REPLACE "\n" "" BUILDYARD_REV "${BUILDYARD_REV}")
    endif()
    if(EXISTS ${DIR}/Buildyard.cmake)
      include(${DIR}/Buildyard.cmake)
    endif()

    if(EXISTS ${DIR}/depends.txt)
      file(READ ${DIR}/depends.txt READ_CONFIG_DIR_DEPENDS)
      string(REGEX REPLACE "[ \n]" ";" READ_CONFIG_DIR_DEPENDS
        "${READ_CONFIG_DIR_DEPENDS}")
    endif()

    list(LENGTH READ_CONFIG_DIR_DEPENDS READ_CONFIG_DIR_DEPENDS_LEFT)
    while(READ_CONFIG_DIR_DEPENDS_LEFT GREATER 2)
      list(GET READ_CONFIG_DIR_DEPENDS 0 READ_CONFIG_DIR_DEPENDS_DIR)
      list(GET READ_CONFIG_DIR_DEPENDS 1 READ_CONFIG_DIR_DEPENDS_REPO)
      list(GET READ_CONFIG_DIR_DEPENDS 2 READ_CONFIG_DIR_DEPENDS_TAG)
      list(REMOVE_AT READ_CONFIG_DIR_DEPENDS 0 1 2)
      list(LENGTH READ_CONFIG_DIR_DEPENDS READ_CONFIG_DIR_DEPENDS_LEFT)
      set(READ_CONFIG_DIR_DEPENDS_DIR
        "${CMAKE_SOURCE_DIR}/${READ_CONFIG_DIR_DEPENDS_DIR}")

      message(STATUS
        "Using ${READ_CONFIG_DIR_DEPENDS_REPO}:${READ_CONFIG_DIR_DEPENDS_TAG}"
        " for ${READ_CONFIG_DIR_DEPENDS_DIR}")
      if(NOT IS_DIRECTORY "${READ_CONFIG_DIR_DEPENDS_DIR}")
        execute_process(
          COMMAND "${GIT_EXECUTABLE}" clone "${READ_CONFIG_DIR_DEPENDS_REPO}"
            "${READ_CONFIG_DIR_DEPENDS_DIR}"
          RESULT_VARIABLE nok ERROR_VARIABLE error
          WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}")
        if(nok)
          message(FATAL_ERROR
            "${READ_CONFIG_DIR_DEPENDS_DIR} git clone failed: ${error}\n")
        endif()
      endif()
      if(IS_DIRECTORY "${READ_CONFIG_DIR_DEPENDS_DIR}/.git")
        execute_process( COMMAND "${GIT_EXECUTABLE}" reset -q .travis.yml
          WORKING_DIRECTORY "${READ_CONFIG_DIR_DEPENDS_DIR}")
        execute_process( COMMAND "${GIT_EXECUTABLE}" checkout -q -- .travis.yml
          WORKING_DIRECTORY "${READ_CONFIG_DIR_DEPENDS_DIR}")
        execute_process( COMMAND "${GIT_EXECUTABLE}" pull
          RESULT_VARIABLE nok ERROR_VARIABLE error
          WORKING_DIRECTORY "${READ_CONFIG_DIR_DEPENDS_DIR}")

        if(nok)
          message(FATAL_ERROR
            "${READ_CONFIG_DIR_DEPENDS_DIR} git pull failed: ${error}\n")
        endif()
        execute_process(
          COMMAND "${GIT_EXECUTABLE}" checkout -q "${READ_CONFIG_DIR_DEPENDS_TAG}"
          RESULT_VARIABLE nok ERROR_VARIABLE error
          WORKING_DIRECTORY "${READ_CONFIG_DIR_DEPENDS_DIR}"
          )
        if(nok)
          message(FATAL_ERROR
            "${READ_CONFIG_DIR_DEPENDS_DIR} git update failed: ${error}\n")
        endif()
      endif()
      read_config_dir(${READ_CONFIG_DIR_DEPENDS_DIR})
    endwhile()

    file(GLOB _files "${DIR}/*.cmake")
    set(_localFiles)
    if(EXISTS "${DIR}/depends.txt")
      set(_localFiles "${DIR}/depends.txt")
      string(REPLACE "${CMAKE_SOURCE_DIR}/" "" _localFiles ${_localFiles})
    endif()
    foreach(_config ${_files})
      include(${_config})
      string(REPLACE "${CMAKE_SOURCE_DIR}/" "" _config ${_config})
      list(APPEND _localFiles ${_config})
    endforeach()

    if(TAR_EXE)
      string(REGEX REPLACE ".*\\.([a-zA-Z0-9]+)$" "\\1" DIRID ${DIR})
      if(NOT "${DIR}" STREQUAL "${DIRID}")
        add_custom_target(tarball-${DIRID}
          COMMAND ${TAR_EXE} rf ${TARBALL} --transform 's:^:${CMAKE_PROJECT_NAME}-${VERSION}/:' -C "${CMAKE_SOURCE_DIR}" ${_localFiles}
          COMMENT "Adding ${DIRID}"
          DEPENDS tarball-${TARBALL_CHAIN})
        set(TARBALL_CHAIN ${DIRID})
      endif()
    endif()
  endif()
endmacro()

set(_configs)
file(GLOB _dirs "${CMAKE_SOURCE_DIR}/config*")

list(LENGTH _dirs _dirs_num)
if(_dirs_num LESS 2)
  message(STATUS "No configurations found, cloning Eyescale config")
  execute_process(
    COMMAND "${GIT_EXECUTABLE}" clone https://github.com/Eyescale/config.git
      config.eyescale
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}")
  file(GLOB _dirs "${CMAKE_SOURCE_DIR}/config*")
endif()

set(TARBALL_CHAIN create)

list(SORT _dirs) # read config/ first
foreach(_dir ${_dirs})
  if(IS_DIRECTORY "${_dir}" AND NOT "${_dir}" MATCHES "config.local$")
    read_config_dir("${_dir}")
  endif()
endforeach()

if(IS_DIRECTORY ${CMAKE_SOURCE_DIR}/config.local)
  message(STATUS "Reading overrides from config.local")
  file(GLOB _files "config.local/*.cmake")
  foreach(_config ${_files})
    include(${_config})
  endforeach()
endif()

set(_configs)
if(IS_DIRECTORY "${CMAKE_SOURCE_DIR}/.git")
  if(BUILDYARD_REV)
    execute_process(
      COMMAND "${GIT_EXECUTABLE}" checkout -q "${BUILDYARD_REV}"
      WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}")
    add_custom_target(update)
  else()
    add_custom_target(update
      COMMAND ${GIT_EXECUTABLE} pull || ${GIT_EXECUTABLE} status
      COMMENT "Updating Buildyard"
      WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}")
  endif()
else()
  add_custom_target(update)
endif()
if(IS_DIRECTORY "${CMAKE_SOURCE_DIR}/config.local/.git")
  add_custom_target(config.local-update
    COMMAND ${GIT_EXECUTABLE} pull
    COMMENT "Updating config.local"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/config.local"
    )
  add_dependencies(update config.local-update)
endif()

file(GLOB _dirs "${CMAKE_SOURCE_DIR}/config*")
foreach(_dir ${_dirs})
  if(IS_DIRECTORY "${_dir}" AND NOT "${_dir}" MATCHES "config.local$")
    message(STATUS "Reading ${_dir}")
    get_filename_component(_dirName ${_dir} NAME)

    set(_dest "${_dir}")

    string(REGEX REPLACE ".*\\.(.+)" "\\1" _group ${_dirName})
    if(_group STREQUAL _dirName)
      set(_group)
    else()
      execute_process(COMMAND ${GIT_EXECUTABLE} config --get remote.origin.url
        WORKING_DIRECTORY ${_dir} OUTPUT_VARIABLE ${_group}_CONFIGURL)
      string(REGEX REPLACE "(\r?\n)+$" "" ${_group}_CONFIGURL
        "${${_group}_CONFIGURL}")

      string(TOUPPER ${_group} _GROUP)
      if(NOT ${_GROUP}_DOC_PROJECT AND ${_GROUP}_REPO_URL)
        set(${_GROUP}_DOC_PROJECT "${_group}") # automagic doc project
      endif()
      if(${_GROUP}_DOC_PROJECT) # set in config.group/Buildyard.cmake
        set(_dest "${CMAKE_SOURCE_DIR}/src/${${_GROUP}_DOC_PROJECT}/images")
      endif()
    endif()

    if(NOT BUILDYARD_REV AND _dir MATCHES "config.")
      add_custom_target(${_dirName}-update
        COMMAND ${GIT_EXECUTABLE} pull
        COMMENT "Updating ${_dirName}"
        WORKING_DIRECTORY "${_dir}"
        )
      add_dependencies(update ${_dirName}-update)
    endif()

    create_dependency_graph_start(${_dir})
    file(GLOB _files "${_dir}/*.cmake")
    foreach(_configfile ${_files})
      string(REPLACE ".cmake" "" _config ${_configfile})
      get_filename_component(_config ${_config} NAME)

      if(NOT _config STREQUAL "Buildyard")
        set(_configfound)
        list(FIND _configs ${_config} _configfound)
        if(_configfound EQUAL -1)
          list(APPEND _configs ${_config})
          create_dependency_graph(${_dir} ${_dest} "${${_GROUP}_DOC_PROJECT}"
            ${_config})

          string(TOUPPER ${_config} _CONFIG)
          set(${_CONFIG}_CONFIGFILE "${_configfile}")
          set(${_CONFIG}_GROUP ${_group})
        endif()
      endif()
    endforeach()
    create_dependency_graph_end(${_dir} ${_dest} "${${_GROUP}_DOC_PROJECT}")
  endif()
endforeach()

# resolve to set Boost_NO_SYSTEM_PATHS later in use_external
if(NOT BOOST_FORCE_BUILD)
  set(Boost_NO_BOOST_CMAKE ON) #fix Boost find for CMake > 2.8.7
  find_package(Boost QUIET)
endif()

# configure projects
list(SORT _configs)
foreach(_config ${_configs})
  string(TOUPPER ${_config} _CONFIG)
  use_external(${_config})
  use_external_gather_debs(${_CONFIG})
  list(APPEND DEBS ${${_CONFIG}_DEBS})
endforeach()

if(DEBS)
  list(REMOVE_DUPLICATES DEBS)
  list(SORT DEBS)

  add_custom_target(apt-get
    COMMAND sudo apt-get install ${DEBS}
    COMMENT "Running 'sudo apt-get install' for all dependencies:")
endif()

# generate Travis configs
foreach(_dir ${_dirs})
  if(IS_DIRECTORY "${_dir}" AND NOT "${_dir}" MATCHES "config.local$")
    get_filename_component(_dirName ${_dir} NAME)
    string(REGEX REPLACE ".*\\.(.+)" "\\1" _group ${_dirName})

    if(NOT _group STREQUAL _dirName)
      string(REGEX REPLACE "(\r?\n)+$" "" ${_group}_CONFIGURL
        "${${_group}_CONFIGURL}")

      file(WRITE ${_dir}/.travis.yml
        "# generated by Buildyard, do not edit.\n"
        "notifications:\n"
        "  email:\n"
        "    on_success: never\n"
        "language: cpp\n"
        "# compiler: clang\n"
        "before_install:\n"
        " - sudo apt-get update -qq\n"
        " - sudo apt-get install -qq ")
      foreach(_dep ${DEBS})
        file(APPEND ${_dir}/.travis.yml "${_dep} ")
      endforeach()
      file(APPEND ${_dir}/.travis.yml
        "\nscript:\n"
        " - git clone --depth 10 https://github.com/Eyescale/Buildyard.git\n"
        " - cd Buildyard\n"
        " - git clone --depth 1 ${${_group}_CONFIGURL} ${_dirName}\n"
        " - env TRAVIS=1 make tests\n")
    endif()
  endif()
endforeach()

# Output configured projects:
message("")
if(SKIPPING)
  list(SORT SKIPPING)
  set(TEXT "Skipping:\t")
  foreach(PROJECT ${SKIPPING})
    set(TEXT "${TEXT} ${PROJECT}")
  endforeach()
  message(STATUS ${TEXT})
  set(SKIPPING)
endif()
message("")
if(USING)
  list(SORT USING)
  set(TEXT "Installed:\t")
  foreach(PROJECT ${USING})
    set(TEXT "${TEXT} ${PROJECT}")
  endforeach()
  message(STATUS ${TEXT})
  set(USING)
endif()
message("")
if(BUILDING)
  list(SORT BUILDING)
  set(TEXT "Building:\t")
  foreach(PROJECT ${BUILDING})
    set(TEXT "${TEXT} ${PROJECT}")
  endforeach()
  message(STATUS ${TEXT})
  set(BUILDING)
endif()
message("")

if(TAR_EXE)
  add_dependencies(tarball DEPENDS tarball-${TARBALL_CHAIN})
endif()

# make metarelease: package & module for selected projects specified
# in config.*/Buildyard.cmake
if(RELEASE_NAME)
  # metamodule
  if(MODULE_MODULEFILES)
    file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/MetaModule.cmake
      "file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/${RELEASE_NAME}\n"
      "  \"#%Module1.0\\n\"\n"
      "  \"######################################################################\\n\"\n"
      "  \"#\\n\"\n"
      "  \"# Module:      ${RELEASE_NAME}\\n\"\n"
      "  \"#\\n\"\n"
      "  \"#\\n\"\n"
      "  \"\\n\"\n"
      "  \"# Set internal variables\\n\"\n"
      "  \"set package_name \\\"${RELEASE_NAME}\\\"\\n\"\n"
      "  \"\\n\"\n"
      "  \"module-whatis \\\"Meta module for Release ${RELEASE_NAME}\\\"\\n\"\n"
      "  \"\\n\"\n"
      "  \"proc ModulesHelp { } {\\n\"\n"
      "  \"    global package_name\\n\"\n"
      "  \"\\n\"\n"
      "  \"    puts stderr \\\"This meta module prepares your environment for ${RELEASE_NAME}\\n\"\n"
      "  \"\\n\"\n"
      "  \"Type 'module list' to list all the loaded modules.\\n\"\n"
      "  \"Type 'module avail' to list all the availables ones.\\\"\\n\"\n"
      "  \"}\\n\"\n"
      "  \"\\n\"\n"
      ")\n"
      "foreach(_releaseproj ${RELEASE_PROJECTS})\n"
      "  file(READ ${CMAKE_CURRENT_BINARY_DIR}/\${_releaseproj}/Module.txt \${_releaseproj}modulename)\n"
      "  file(APPEND ${CMAKE_CURRENT_BINARY_DIR}/${RELEASE_NAME}\n"
      "    \"module load \${\${_releaseproj}modulename}\\n\"\n"
      "  )\n"
      "endforeach()\n"
    )

    add_custom_target(metamodule
      COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/MetaModule.cmake &&
              ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_BINARY_DIR}/${RELEASE_NAME} ${MODULE_MODULEFILES}/${RELEASE_NAME}
      COMMENT "Created meta module ${RELEASE_NAME} at ${MODULE_MODULEFILES}: ${RELEASE_PROJECTS}")

    foreach(_releaseproj ${RELEASE_PROJECTS})
      add_dependencies(metamodule ${_releaseproj}-module)
    endforeach()
  endif()

  # metapackage
  add_custom_target(metapackage
    COMMENT "Created packages for Release ${RELEASE_NAME}: ${RELEASE_PROJECTS}"
  )
  foreach(_releaseproj ${RELEASE_PROJECTS})
    add_dependencies(metapackage ${_releaseproj}-package)
  endforeach()
endif()
