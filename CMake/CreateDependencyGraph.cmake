
find_program(DOT_EXECUTABLE dot)
find_program(TRED_EXECUTABLE tred)
add_custom_target(pngs)
set_target_properties(pngs PROPERTIES EXCLUDE_FROM_ALL ON)
option(CREATE_DEPENDENCY_GRAPH_CLUSTERS
  "Create clusters for each configuration folder" OFF)

function(CREATE_DEPENDENCY_GRAPH_R name ALL FILE)
  string(TOUPPER ${name} NAME)
  if(${NAME}_PACKAGE_VERSION)
    set(label "${name}\\n${${NAME}_PACKAGE_VERSION}")
  else()
    set(label "${name}")
  endif()

  if(${NAME}_OPTIONAL OR NOT ${NAME}_PACKAGE_VERSION)
    file(APPEND ${CMAKE_CURRENT_BINARY_DIR}/${ALL}.dot
      "${name} [style=dashed, label=\"${label}\"]\n")
    file(APPEND ${FILE} "${name} [style=dashed, label=\"${label}\"]\n")
  else()
    file(APPEND ${CMAKE_CURRENT_BINARY_DIR}/${ALL}.dot
      "${name} [style=solid, label=\"${label}\"]\n")
    file(APPEND ${FILE} "${name} [style=solid, label=\"${label}\"]\n")
  endif()

  if(CREATE_DEPENDENCY_GRAPH_CLUSTERS)
    if(${NAME}_DIR)
      string(REPLACE "." "" CLUSTER ${${NAME}_DIR})
      file(APPEND ${FILE}
        "subgraph cluster_${CLUSTER} { color=gray label=\"${${NAME}_DIR}\" ${name}; }\n")
      file(APPEND ${CMAKE_CURRENT_BINARY_DIR}/${ALL}.dot
        "subgraph cluster_${CLUSTER} { color=gray label=\"${${NAME}_DIR}\" ${name}; }\n")
    else()
      file(APPEND ${FILE}
        "subgraph cluster_system { color=gray label=\"system\" ${name}; }\n")
      file(APPEND ${CMAKE_CURRENT_BINARY_DIR}/${ALL}.dot
        "subgraph cluster_system { color=gray label=\"system\" ${name}; }\n")
    endif()
  endif()

  set(DEPMODE dashed)
  foreach(_dep ${${NAME}_DEPENDS})
    if(_dep STREQUAL "OPTIONAL")
      set(DEPMODE dashed)
    elseif(_dep STREQUAL "REQUIRED")
      set(DEPMODE solid)
    else()
      file(APPEND ${FILE}
        "\"${_dep}\" -> \"${name}\" [style = ${DEPMODE}]\n" )
      file(APPEND ${CMAKE_CURRENT_BINARY_DIR}/${ALL}.dot
        "\"${_dep}\" -> \"${name}\" [style = ${DEPMODE}]\n" )
      create_dependency_graph_r(${_dep} ${ALL} ${FILE})
    endif()
  endforeach()
endfunction()

function(CREATE_DEPENDENCY_GRAPH_START DIR)
  get_filename_component(dir ${DIR} NAME)
  file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/${dir}.dot "strict digraph G {" )
endfunction()

function(CREATE_DEPENDENCY_GRAPH SRC DST GRP name)
  get_filename_component(dir ${SRC} NAME)
  file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/${name}.dot
    "strict digraph G { rankdir=\"RL\";" )

  create_dependency_graph_r(${name} ${dir}
    ${CMAKE_CURRENT_BINARY_DIR}/${name}.dot)
  file(APPEND ${CMAKE_CURRENT_BINARY_DIR}/${name}.dot "}" )
  if(DOT_EXECUTABLE AND TRED_EXECUTABLE)
    add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${name}_tred.dot
      COMMAND ${TRED_EXECUTABLE} ${CMAKE_CURRENT_BINARY_DIR}/${name}.dot >
               ${CMAKE_CURRENT_BINARY_DIR}/${name}_tred.dot
      DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/${name}.dot
      )
    add_custom_command(OUTPUT ${DST}/${name}.png
      COMMAND ${CMAKE_COMMAND} -E make_directory ${DST}
      COMMAND ${DOT_EXECUTABLE} -o ${DST}/${name}.png -Tpng
        ${CMAKE_CURRENT_BINARY_DIR}/${name}_tred.dot
      DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/${name}_tred.dot ${GRP}
      )
    add_custom_target(${name}-png DEPENDS ${DST}/${name}.png)
    add_dependencies(pngs ${name}-png)
 endif()
endfunction()

function(CREATE_DEPENDENCY_GRAPH_END SRC DST GRP)
  get_filename_component(dir ${SRC} NAME)
  file(APPEND ${CMAKE_CURRENT_BINARY_DIR}/${dir}.dot "}" )
  if(DOT_EXECUTABLE AND TRED_EXECUTABLE)
    add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${dir}_tred.dot
      COMMAND ${TRED_EXECUTABLE} ${CMAKE_CURRENT_BINARY_DIR}/${dir}.dot >
              ${CMAKE_CURRENT_BINARY_DIR}/${dir}_tred.dot
      DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/${dir}.dot
      )
    add_custom_command(OUTPUT ${DST}/all.png
      COMMAND ${CMAKE_COMMAND} -E make_directory ${DST}
      COMMAND ${DOT_EXECUTABLE} -o ${DST}/all.png -Tpng
      ${CMAKE_CURRENT_BINARY_DIR}/${dir}_tred.dot
      DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/${dir}_tred.dot ${GRP}
      )
    add_custom_target(${dir}_png DEPENDS ${DST}/all.png)
    add_dependencies(pngs ${dir}_png)
  endif()
endfunction()
