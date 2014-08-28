set(ZMQCPP_PACKAGE_VERSION 4)
set(ZMQCPP_OPTIONAL ON)
set(ZMQCPP_REPO_URL https://github.com/zeromq/cppzmq.git)
set(ZMQCPP_REPO_TYPE git)
set(ZMQCPP_REPO_TAG master)
set(ZMQCPP_DEPENDS REQUIRED libzmq)

set(ZMQCPP_SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/cppzmq")
set(ZMQCPP_EXTRA
    CONFIGURE_COMMAND touch ${CMAKE_BINARY_DIR}
    BUILD_COMMAND touch ${CMAKE_BINARY_DIR}
    INSTALL_COMMAND
        ${CMAKE_COMMAND} -E make_directory ${BUILDYARD_INSTALL_PATH}/include/ &&
        # Copy header
        ${CMAKE_COMMAND} -E copy_if_different ${ZMQCPP_SOURCE}/zmq.hpp ${BUILDYARD_INSTALL_PATH}/include/
)
