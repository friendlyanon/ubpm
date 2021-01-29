cmake_minimum_required(VERSION 3.14)

project(
    ubpm
    VERSION 0.1.0
    DESCRIPTION "CMake only dependency management nonintrusively"
    HOMEPAGE_URL "https://github.com/friendlyanon/ubpm"
    LANGUAGES NONE
)

# Define lib dir here, so we don't have to enable any languages
set(CMAKE_INSTALL_LIBDIR lib CACHE PATH "Object code libraries (lib)")
include(GNUInstallDirs)

set(
    UBPM_BASH_SHEBANG "/bin/bash"
    CACHE STRING
    "Shebang for the installed utility script"
)

set(UBPM_DATAROOT "${CMAKE_INSTALL_DATADIR}/ubpm/module")
set(UBPM_LIBROOT "${CMAKE_INSTALL_LIBDIR}/cmake/ubpm")
file(
    RELATIVE_PATH UBPM_BIN_MODULE_PATH
    "/${CMAKE_INSTALL_BINDIR}" "/${UBPM_DATAROOT}"
)
file(
    RELATIVE_PATH UBPM_LIB_MODULE_PATH
    "/${UBPM_LIBROOT}" "/${UBPM_DATAROOT}"
)

configure_file(ubpm.sh.in ubpm @ONLY)
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
