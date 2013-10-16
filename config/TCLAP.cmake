
set(TCLAP_PACKAGE_VERSION 1.2)
set(TCLAP_OPTIONAL ON)
set(TCLAP_REPO_URL git://git.code.sf.net/p/tclap/code)
set(TCLAP_REPO_TAG tclap-1-2-1)
set(TCLAP_SOURCE "${CMAKE_SOURCE_DIR}/src/TCLAP")
set(TCLAP_AUTOCONF ON)
set(TCLAP_CONFIGURE_FLAGS "--enable-doxygen")
set(TCLAP_PRE_CONFIGURE
  "execute_process(COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_LIST_DIR}/TCLAP.fix ${TCLAP_SOURCE}/docs/Makefile.am)")
