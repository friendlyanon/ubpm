cmake_minimum_required(VERSION 3.14)

project(
    ubpm
    VERSION 1.0.0
    DESCRIPTION "CMake only dependency management nonintrusively"
    HOMEPAGE_URL "https://github.com/friendlyanon/ubpm"
    # Have to enable at least one language to make the lib dir available
    LANGUAGES C
)

include(GNUInstallDirs)

set(
    UBPM_BASH_SHEBANG "/bin/bash"
    CACHE STRING
    "Shebang for the installed utility script"
)

set(UBPM_DATAROOT "${CMAKE_INSTALL_DATADIR}/ubpm-${PROJECT_VERSION}/module")
set(UBPM_LIBROOT "${CMAKE_INSTALL_LIBDIR}/cmake/ubpm-${PROJECT_VERSION}")
file(
    RELATIVE_PATH UBPM_BIN_MODULE_PATH
    "/${CMAKE_INSTALL_BINDIR}" "/${UBPM_DATAROOT}"
)
file(
    RELATIVE_PATH UBPM_LIB_MODULE_PATH
    "/${UBPM_LIBROOT}" "/${UBPM_DATAROOT}"
)

configure_file(ubpm.in ubpm @ONLY)
configure_file(cmake/ubpmConfig.cmake.in ubpmConfig.cmake @ONLY)
configure_file(cmake/ubpmConfigVersion.cmake.in ubpmConfigVersion.cmake @ONLY)

install(PROGRAMS "${PROJECT_BINARY_DIR}/ubpm" TYPE BIN)

install(
    FILES
    "${PROJECT_BINARY_DIR}/ubpmConfig.cmake"
    "${PROJECT_BINARY_DIR}/ubpmConfigVersion.cmake"
    DESTINATION "${UBPM_LIBROOT}"
)

install(FILES ubpm.cmake DESTINATION "${UBPM_DATAROOT}")

include(CPack)
