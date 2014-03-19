# Copyright (c) 2012 Stefan Eilemann <Stefan.Eilemann@epfl.ch>
# Does a use_external(..) for each config*/*.cmake project.

include(Common)
include(UseExternal)
include(CreateDependencyGraph)
include(GitExternal)
include(GitTargets)

if(APPLE)
  find_program(TAR_EXE gnutar)
else()
  find_program(TAR_EXE tar)
endif()

set(INSTALL_PATH "${CMAKE_CURRENT_BINARY_DIR}/install")

find_program(AUTORECONF_EXE autoreconf)
if(NOT MSVC AND NOT AUTORECONF_EXE)
  if(APPLE)
    message(STATUS
      "autoreconf missing, install autoconf tools (sudo port install autoconf)")
  else()
    message(STATUS "autoreconf missing, install autoconf tools")
  endif()
endif()

file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/info.cmake "message(\"\n")
macro(READ_CONFIG_DIR DIR)
  get_property(READ_CONFIG_DIR_DONE GLOBAL PROPERTY READ_CONFIG_DIR_${DIR})
  if(NOT READ_CONFIG_DIR_DONE) # Not already parsed
    set_property(GLOBAL PROPERTY READ_CONFIG_DIR_${DIR} ON) # mark being parsed

    # Read all dependencies first
    set(READ_CONFIG_DIR_DEPENDS)
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
        "${CMAKE_CURRENT_SOURCE_DIR}/${READ_CONFIG_DIR_DEPENDS_DIR}")

      message(STATUS
        "Using ${READ_CONFIG_DIR_DEPENDS_REPO}:${READ_CONFIG_DIR_DEPENDS_TAG}"
        " for ${READ_CONFIG_DIR_DEPENDS_DIR}")
      git_external("${READ_CONFIG_DIR_DEPENDS_DIR}"
        "${READ_CONFIG_DIR_DEPENDS_REPO}"
        "${READ_CONFIG_DIR_DEPENDS_TAG}"
        RESET .travis.yml)
      read_config_dir(${READ_CONFIG_DIR_DEPENDS_DIR})
    endwhile()

    # Read configurations in this configuration folder
    message(STATUS "Reading ${DIR}")

    set(_localFiles)
    if(EXISTS "${DIR}/depends.txt")
      set(_localFiles "${DIR}/depends.txt")
      string(REPLACE "${CMAKE_CURRENT_SOURCE_DIR}/" "" _localFiles
        ${_localFiles})
    endif()

    if(EXISTS ${DIR}/Buildyard.txt) # deprecated, use Buildyard.cmake
      file(READ ${DIR}/Buildyard.txt BUILDYARD_REV)
      string(REGEX REPLACE "\n" "" BUILDYARD_REV "${BUILDYARD_REV}")
    endif()
    if(EXISTS ${DIR}/Buildyard.cmake)
      include(${DIR}/Buildyard.cmake)
    endif()

    file(RELATIVE_PATH BASEDIR ${CMAKE_CURRENT_SOURCE_DIR} ${DIR})
    file(GLOB _files "${DIR}/*.cmake")
    foreach(_config ${_files})
      include(${_config})
      string(REPLACE "${CMAKE_CURRENT_SOURCE_DIR}/" "" _config ${_config})
      list(APPEND _localFiles ${_config})

      string(REPLACE ".cmake" "" NAME ${_config})
      get_filename_component(NAME ${NAME} NAME)
      string(TOUPPER ${NAME} NAME)
      set(${NAME}_DIR ${BASEDIR})
    endforeach()

    if(TAR_EXE)
      string(REGEX REPLACE ".*\\.([a-zA-Z0-9]+)$" "\\1" DIRID ${DIR})
      if(NOT "${DIR}" STREQUAL "${DIRID}")
        add_custom_target(tarball-${DIRID}
          COMMAND ${TAR_EXE} rf ${TARBALL} --transform 's:^:${CMAKE_PROJECT_NAME}-${VERSION}/:' -C "${CMAKE_CURRENT_SOURCE_DIR}" ${_localFiles}
          COMMENT "Adding ${DIRID}"
          DEPENDS tarball-${TARBALL_CHAIN})
        set(TARBALL_CHAIN ${DIRID})
      endif()
    endif()
  endif()
endmacro()

set(_configs)
file(GLOB _dirs "${CMAKE_CURRENT_SOURCE_DIR}/config*")

list(LENGTH _dirs _dirs_num)
if(_dirs_num LESS 2)
  message(STATUS "No configurations found, cloning Eyescale config")
  execute_process(
    COMMAND "${GIT_EXECUTABLE}" clone https://github.com/Eyescale/config.git
      config.eyescale
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}")
  file(GLOB _dirs "${CMAKE_CURRENT_SOURCE_DIR}/config*")
endif()

set(TARBALL_CHAIN create)

list(SORT _dirs) # read config/ first
foreach(_dir ${_dirs})
  if(IS_DIRECTORY "${_dir}" AND NOT "${_dir}" MATCHES "config.local$")
    read_config_dir("${_dir}")
  endif()
endforeach()

if(IS_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/config.local)
  message(STATUS "Reading project overrides from config.local")
  file(GLOB _files "config.local/*.cmake")
  foreach(_config ${_files})
    include(${_config})
  endforeach()
endif()

set(_configs)
if(IS_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/.git")
  if(NOT TARGET update)
    add_custom_target(update)
  endif()
  if(BUILDYARD_REV)
    execute_process(
      COMMAND "${GIT_EXECUTABLE}" checkout -q "${BUILDYARD_REV}"
      WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}")
  else()
    add_custom_target(update_Buildyard
      COMMAND ${GIT_EXECUTABLE} reset -q .travis.yml
      COMMAND ${GIT_EXECUTABLE} checkout -q -- .travis.yml
      COMMAND ${GIT_EXECUTABLE} remote update || ${GIT_EXECUTABLE} status
      COMMENT "Updating Buildyard"
      WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}")
    add_dependencies(update update_Buildyard)
  endif()
else()
  if(NOT TARGET update)
    add_custom_target(update)
  endif()
endif()
if(IS_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/config.local/.git")
  add_custom_target(config.local-update
    COMMAND ${GIT_EXECUTABLE} remote update
    COMMENT "Updating config.local"
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/config.local"
    )
  add_dependencies(update config.local-update)
endif()

# Create targets for dependency graphs
file(GLOB _dirs "${CMAKE_CURRENT_SOURCE_DIR}/config*")
foreach(_dir ${_dirs})
  if(IS_DIRECTORY "${_dir}" AND NOT "${_dir}" MATCHES "config.local$")
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
        set(_dest
          "${CMAKE_CURRENT_SOURCE_DIR}/src/${${_GROUP}_DOC_PROJECT}/images")
      endif()
    endif()

    if(NOT BUILDYARD_REV AND _dir MATCHES "config.")
      add_custom_target(${_dirName}-update
        COMMAND ${GIT_EXECUTABLE} reset -q .travis.yml || ${GIT_EXECUTABLE} status
        COMMAND ${GIT_EXECUTABLE} checkout -q -- .travis.yml || ${GIT_EXECUTABLE} status
        COMMAND ${GIT_EXECUTABLE} remote update
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
if(BUILDYARD_TARGETS)
  set(_configs ${BUILDYARD_TARGETS})
endif()
list(SORT _configs)
foreach(_config ${_configs})
  string(TOUPPER ${_config} _CONFIG)
  use_external(${_config})
  use_external_gather_install(${_CONFIG})
  list(APPEND DEBS ${${_CONFIG}_DEBS})
  list(APPEND PORTS ${${_CONFIG}_PORTS})
endforeach()

if(DEBS)
  list(SORT DEBS)
  list(REMOVE_DUPLICATES DEBS)

  add_custom_target(apt-get
    COMMAND sudo apt-get install ${DEBS}
    # Force reconfiguration after package installation
    COMMAND ${CMAKE_COMMAND} -E touch "${CMAKE_BINARY_DIR}/CMakeCache.txt"
    COMMENT "Running 'sudo apt-get install ${DEBS}':")
endif()

if(PORTS)
  list(SORT PORTS)
  list(REMOVE_DUPLICATES PORTS)
  set(PORTS_UNIVERSAL)
  foreach(PORT ${PORTS})
    list(APPEND PORTS_UNIVERSAL ${PORT} +universal)
  endforeach()

  add_custom_target(port-get
    COMMAND sudo port install -p ${PORTS_UNIVERSAL}
    COMMENT "Running 'sudo port install ${PORTS} (+universal)':")
endif()

# generate Travis configs
file(WRITE ${CMAKE_CURRENT_SOURCE_DIR}/.travis.yml
  "# generated by Buildyard, do not edit.\n"
  "notifications:\n"
  "  email:\n"
  "    on_success: never\n"
  "language: cpp\n"
  "# compiler: clang\n"
  "before_install:\n"
  " - sudo apt-get update -qq\n")
foreach(_dep ${DEBS})
  file(APPEND ${CMAKE_CURRENT_SOURCE_DIR}/.travis.yml
    " - sudo apt-get install -qq ${_dep} || /bin/true\n")
endforeach()
file(APPEND ${CMAKE_CURRENT_SOURCE_DIR}/.travis.yml
  "script:\n"
  " - mkdir config.none\n"
  " - env TRAVIS=1 make -j2 debug\n"
  " - env TRAVIS=1 make -j2 release\n"
  " - env TRAVIS=1 make tests ARGS=-V -C Debug\n"
  " - env TRAVIS=1 make tests ARGS=-V -C Release\n")

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
        " - sudo apt-get update -qq\n")
      foreach(_dep ${DEBS})
        file(APPEND ${_dir}/.travis.yml
          " - sudo apt-get install -qq ${_dep} || /bin/true\n")
      endforeach()
      file(APPEND ${_dir}/.travis.yml
        "script:\n"
        " - git clone --depth 10 https://github.com/Eyescale/Buildyard.git\n"
        " - cd Buildyard\n"
        " - mkdir config.travis\n"
        " - cp ../*.* config.travis\n"
        " - env TRAVIS=1 make -j2 debug\n"
        " - env TRAVIS=1 make tests ARGS=-V -C Debug\n")
      # don't run release in addition - travis has a 50 min timeout
    endif()
  endif()
endforeach()

# Output configured projects and save for 'make info':
if(SKIPPING)
  list(SORT SKIPPING)
  set(TEXT "\nSkipping:    ")
  foreach(PROJECT ${SKIPPING})
    set(TEXT "${TEXT} ${PROJECT}")
  endforeach()
  file(APPEND ${CMAKE_CURRENT_BINARY_DIR}/info.cmake "${TEXT}\n\n")
  message("${TEXT}\n")
  set(SKIPPING)
endif()
if(USING)
  list(SORT USING)
  set(TEXT "Installed:   ")
  foreach(PROJECT ${USING})
    set(TEXT "${TEXT} ${PROJECT}")
  endforeach()
  file(APPEND ${CMAKE_CURRENT_BINARY_DIR}/info.cmake "${TEXT}\n\n")
  message( "${TEXT}\n")
  set(USING)
endif()
if(BUILDING)
  list(APPEND BUILDING pngs)
  list(SORT BUILDING)
  set(TEXT "Building:    ")
  foreach(PROJECT ${BUILDING})
    get_target_property(_optional ${PROJECT} _EP_IS_OPTIONAL_PROJECT)
    if(NOT _optional)
      set(TEXT "${TEXT} ${PROJECT}")
    endif()
  endforeach()
  set(TEXT "${TEXT}\n              [")
  foreach(PROJECT ${BUILDING})
    get_target_property(_optional ${PROJECT} _EP_IS_OPTIONAL_PROJECT)
    if(_optional)
      set(TEXT "${TEXT} ${PROJECT}")
    endif()
  endforeach()
  set(TEXT "${TEXT} ]")
  file(APPEND ${CMAKE_CURRENT_BINARY_DIR}/info.cmake "${TEXT}\n")
  message( "${TEXT}\n")
endif()
file(APPEND ${CMAKE_CURRENT_BINARY_DIR}/info.cmake "\")")

add_custom_target(info
  COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/info.cmake
  COMMENT "Current Buildyard configuration:")

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
