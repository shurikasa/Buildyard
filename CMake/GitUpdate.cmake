# Script used by ExternalProject update step. Do not use directly.

execute_process(COMMAND ${GIT_EXECUTABLE} remote update
  OUTPUT_VARIABLE NULL ERROR_VARIABLE NULL)
execute_process(COMMAND ${GIT_EXECUTABLE} checkout ${REPO_TAG}
  RESULT_VARIABLE RESULT OUTPUT_VARIABLE OUTPUT ERROR_VARIABLE OUTPUT)
if(RESULT)
  # Try again by fetching tags (will fetch a lot of stuff on shallow clones)
  #  see https://github.com/Eyescale/Buildyard/issues/102
  execute_process(COMMAND ${GIT_EXECUTABLE} fetch --tags OUTPUT_VARIABLE NULL)
  execute_process(COMMAND ${GIT_EXECUTABLE} checkout ${REPO_TAG}
    RESULT_VARIABLE RESULT OUTPUT_VARIABLE OUTPUT ERROR_VARIABLE OUTPUT)
  if(RESULT)
    message(STATUS "git checkout ${REPO_TAG} failed: ${OUTPUT}")
  endif()
endif()

if(BUILDYARD_UPDATE_REBASE)
  execute_process(COMMAND ${GIT_EXECUTABLE} rebase FETCH_HEAD
    RESULT_VARIABLE RESULT OUTPUT_VARIABLE OUTPUT ERROR_VARIABLE OUTPUT)
  if(RESULT)
    message(STATUS "git rebase failed, aborting upstream merge")
    execute_process(COMMAND ${GIT_EXECUTABLE} rebase --abort)
  endif()
endif()
