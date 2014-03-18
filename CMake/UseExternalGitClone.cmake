# rewrites the git clone script:
# * Never, ever, remove source directories
# * use a shallow clone if requested

function(use_external_git_clone name)
  get_property(git_repository TARGET ${name} PROPERTY _EP_GIT_REPOSITORY)
  if(NOT git_repository)
    return()
  endif()

  string(TOUPPER ${name} NAME)

  ExternalProject_Get_Property(${name} source_dir tmp_dir)
  set(git_clone_script "${tmp_dir}/${name}-gitclone.cmake")
  if(NOT EXISTS ${git_clone_script})
    message(WARNING "Can't find ${git_clone_script}, shallow clone not active")
    return()
  endif()

  file(READ ${git_clone_script} content)

  # Be nicer than ExternalProject
  set(content "if(IS_DIRECTORY \"${source_dir}/.git\")
  message(STATUS \"Don't re-clone existing git repo ${source_dir}\")
  return()
endif()
${content}")

  # shallow clone
  if(${NAME}_REPO_DEPTH)
    string(REGEX REPLACE
      "\"[ ]+clone[ ]+\"" "\" clone --depth ${${NAME}_REPO_DEPTH} \""
      content ${content})
  endif()

  file(WRITE ${git_clone_script} ${content})
endfunction()
