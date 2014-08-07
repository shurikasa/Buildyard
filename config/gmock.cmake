set(GMOCK_PACKAGE_VERSION 1.7.0)
set(GMOCK_OPTIONAL ON)

# Windows is not supported yet
if(MSVC)
  return()
endif()

set(GMOCK_REPO_URL http://googlemock.googlecode.com/svn/tags/release-1.7.0/)
set(GMOCK_REPO_TYPE svn)

set(GMOCK_SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/gmock")
set(GMOCK_EXTRA
  INSTALL_COMMAND
    # Make sure lib folder exists. Not necessary for include folder because
    # make_directory creates it if not present
    ${CMAKE_COMMAND} -E make_directory ${BUILDYARD_INSTALL_PATH}/lib/ &&

    # Copy headers
    ${CMAKE_COMMAND} -E copy_directory ${GMOCK_SOURCE}/include/ ${BUILDYARD_INSTALL_PATH}/include &&
    ${CMAKE_COMMAND} -E copy_directory ${GMOCK_SOURCE}/gtest/include/ ${BUILDYARD_INSTALL_PATH}/include &&
    ${CMAKE_COMMAND} -E copy_directory ${GMOCK_SOURCE}/gtest/include/internal ${BUILDYARD_INSTALL_PATH}/include/gtest &&

    # Copy libraries
    ${CMAKE_COMMAND} -E copy ${CMAKE_BINARY_DIR}/gmock/libgmock.a ${BUILDYARD_INSTALL_PATH}/lib/ &&
    ${CMAKE_COMMAND} -E copy ${CMAKE_BINARY_DIR}/gmock/libgmock_main.a ${BUILDYARD_INSTALL_PATH}/lib/ &&
    ${CMAKE_COMMAND} -E copy ${CMAKE_BINARY_DIR}/gmock/gtest/libgtest.a ${BUILDYARD_INSTALL_PATH}/lib/ &&
    ${CMAKE_COMMAND} -E copy ${CMAKE_BINARY_DIR}/gmock/gtest/libgtest_main.a ${BUILDYARD_INSTALL_PATH}/lib/
)
