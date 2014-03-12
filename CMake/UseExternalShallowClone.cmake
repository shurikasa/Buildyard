# rewrites the git clone script to use a shallow clone if requested

function(use_external_shallow_clone name)
  string(TOUPPER ${name} NAME)
  if(NOT ${NAME}_REPO_DEPTH)
    return()
  endif()

  ExternalProject_Get_Property(${name} tmp_dir)
  set(git_clone_script "${tmp_dir}/${name}-gitclone.cmake")
  if(NOT EXISTS ${git_clone_script})
    message(WARNING "Can't find ${git_clone_script}, shallow clone not active")
    return()
  endif()

  file(READ ${git_clone_script} content)
  string(REGEX REPLACE "\"[ ]+clone " "\" clone --depth ${${NAME}_REPO_DEPTH} "
    content ${content})
  file(WRITE ${git_clone_script} ${content})
endfunction()
