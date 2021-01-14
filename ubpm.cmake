# UBPM - Dependency management for well behaved CMake packages
# Copyright (C) 2021  friendlyanon
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# Website: https://github.com/friendlyanon/ubpm

cmake_minimum_required(VERSION 3.15)

set(
    UBPM_INTERNAL_PASSTHROUGH
    UBPM_NO_GIT
    UBPM_GIT_EXECUTABLE
    UBPM_PATH
    UBPM_CORES
    UBPM_USE_ANSI_COLOR
    UBPM_LOG_COLOR
    UBPM_PASSTHROUGH_CACHE
    UBPM_PREFIX_PATH_INIT
    CACHE
    INTERNAL
    ""
)

if(NOT DEFINED CACHE{UBPM_CORES})
  include(ProcessorCount)
  ProcessorCount(UBPM_CORES)
  if(UBPM_CORES EQUAL "0")
    set(UBPM_CORES 1)
    message(AUTHOR_WARNING "UBPM: Could not determine processor count, using 1")
  endif()
  set(UBPM_CORES "${UBPM_CORES}" CACHE STRING "Processor count")
  unset(UBPM_CORES)
  mark_as_advanced(UBPM_CORES)
endif()

set(UBPM_INDENT "$CACHE{UBPM_INDENT}" CACHE INTERNAL "Indentation level")

set(UBPM_USE_ANSI_COLOR YES CACHE BOOL "Whether to use ANSI terminal colors")
mark_as_advanced(UBPM_USE_ANSI_COLOR)

set(UBPM_LOG_COLOR 96 CACHE STRING "ANSI color to use in the terminal")
mark_as_advanced(UBPM_LOG_COLOR)

string(
    CONCAT ubpm_doc
    "Cache variables that should be passed through to dependencies. "
    "These do not participate in hash calculation for caching the artifacts. "
    "Changing this after the initial configuration is not advised without "
    "clearing the artifact cache directory first."
)
set(UBPM_PASSTHROUGH_CACHE "CMAKE_TOOLCHAIN_FILE" CACHE STRING "${ubpm_doc}")
mark_as_advanced(UBPM_PASSTHROUGH_CACHE)
unset(ubpm_doc)

if(NOT DEFINED CACHE{UBPM_PREFIX_PATH_INIT})
  set(UBPM_PREFIX_PATH_INIT "$CACHE{CMAKE_PREFIX_PATH}" CACHE INTERNAL "")
endif()

macro(ubpm_msg_color TYPE PREFIX MESSAGE)
  string(ASCII 27 esc)
  message(
      "${TYPE}"
      "${PREFIX}${esc}[${UBPM_LOG_COLOR}m${MESSAGE}${esc}[0m"
  )
  unset(esc)
endmacro()

if(DEFINED CACHE{CMAKE_BUILD_TYPE})
  # Make sure this variable never warns for multi-config generators
  set(CMAKE_BUILD_TYPE "$CACHE{CMAKE_BUILD_TYPE}" CACHE STRING "" FORCE)
  # Print only from the top level project
  if(NOT "$CACHE{UBPM_IS_DEPENDENCY}")
    ubpm_msg_color(
        STATUS
        ""
        "UBPM: Default build mode is $CACHE{CMAKE_BUILD_TYPE}"
    )
  endif()
endif()

macro(ubpm_msg TYPE MESSAGE)
  if(TYPE STREQUAL "FATAL_ERROR")
    message(FATAL_ERROR "${MESSAGE}")
  else()
    if(UBPM_USE_ANSI_COLOR)
      ubpm_msg_color(
          "${TYPE}"
          "${UBPM_INDENT}"
          "UBPM [${NAME}]: ${MESSAGE}"
      )
    else()
      message("${TYPE}" "${UBPM_INDENT}UBPM [${NAME}]: ${MESSAGE}")
    endif()
  endif()
endmacro()

if(NOT DEFINED UBPM_PATH_INIT)
  get_filename_component(UBPM_PATH "${CMAKE_SOURCE_DIR}/.ubpm" REALPATH CACHE)
else()
  get_filename_component(UBPM_PATH "${UBPM_PATH_INIT}" REALPATH CACHE)
endif()
mark_as_advanced(UBPM_PATH)

if(NOT IS_ABSOLUTE "${UBPM_PATH}")
  message(FATAL_ERROR "UBPM_PATH is not an absolute path: ${UBPM_PATH}")
endif()

if(NOT "$CACHE{UBPM_NO_GIT}" AND NOT DEFINED CACHE{UBPM_GIT_EXECUTABLE})
  set(UBPM_GIT_EXECUTABLE git CACHE INTERNAL "Path to git executable")
endif()

# A simple alias to execute_process that always checks the return code
function(ubpm_call)
  execute_process(COMMAND ${ARGV} RESULT_VARIABLE result)
  if(NOT result EQUAL "0")
    string(REPLACE ";" " " command "${ARGV}")
    message(FATAL_ERROR "Command exited with ${result}: ${command}")
  endif()
endfunction()

# Handy proxy to call cmake with ubpm_call
function(ubpm_cmake)
  ubpm_call("${CMAKE_COMMAND}" ${ARGV})
endfunction()

macro(ubpm_install_source_dir)
  ubpm_msg(STATUS "Configuring")

  set(
      config_args
      -D "UBPM_INDENT:INTERNAL=  $CACHE{UBPM_INDENT}"
      -D "UBPM_IS_DEPENDENCY:INTERNAL=YES"
  )
  foreach(var IN LISTS UBPM_PASSTHROUGH_CACHE)
    if(DEFINED "CACHE{${var}}")
      string(REPLACE ";" [[\\\;]] escaped "$CACHE{${var}}")
      list(APPEND config_args -D "${var}:INTERNAL=${escaped}")
    endif()
  endforeach()

  list(APPEND config_args -D UBPM_NO_SCRIPT_WARNING:INTERNAL=YES)
  foreach(var IN LISTS UBPM_INTERNAL_PASSTHROUGH)
    string(REPLACE ";" [[\\\;]] escaped "$CACHE{${var}}")
    list(APPEND config_args -D "${var}:INTERNAL=${escaped}")
  endforeach()

  if(_OPTIONS)
    foreach(index RANGE "${options_limit}")
      string(REPLACE ";" [[\\\;]] escaped "${options_${index}}")
      list(APPEND config_args -D "${escaped}")
    endforeach()
  endif()

  if(_SCRIPT_PATH)
    file(REMOVE "${source_dir}/CMakeLists.txt")
    file(INSTALL "${_SCRIPT_PATH}" DESTINATION "${source_dir}" RENAME CMakeLists.txt MESSAGE_NEVER)
  endif()

  set(cmake_args -D "CMAKE_BUILD_TYPE=${_BUILD_TYPE}")
  if(CMAKE_GENERATOR)
    list(APPEND cmake_args -G "${CMAKE_GENERATOR}")
    if(CMAKE_GENERATOR_PLATFORM)
      list(APPEND cmake_args -A "${CMAKE_GENERATOR_PLATFORM}")
    endif()
    if(CMAKE_GENERATOR_TOOLSET)
      list(APPEND cmake_args -T "${CMAKE_GENERATOR_TOOLSET}")
    endif()
    if(CMAKE_MAKE_PROGRAM)
      list(APPEND cmake_args -D "CMAKE_MAKE_PROGRAM:FILEPATH=${CMAKE_MAKE_PROGRAM}")
    endif()
  endif()

  set(build_dir "${UBPM_PATH}/build")
  file(REMOVE_RECURSE "${build_dir}")

  ubpm_cmake(
      -S "${source_dir}"
      -B "${build_dir}"
      --no-warn-unused-cli
      ${cmake_args} ${config_args}
  )

  ubpm_msg(STATUS "Building")
  set(build_log "${UBPM_PATH}/build.log")
  file(REMOVE "${build_log}")
  ubpm_cmake(
      --build "${build_dir}"
      --config "${_BUILD_TYPE}"
      -j "${UBPM_CORES}"
      OUTPUT_FILE "${build_log}" ERROR_FILE "${build_log}"
  )
  file(REMOVE "${build_log}")

  ubpm_msg(STATUS "Installing")
  file(REMOVE_RECURSE "${install_dir}")
  if("${_COMPONENTS}" STREQUAL "")
    ubpm_cmake(
        --install "${build_dir}"
        --config "${_BUILD_TYPE}"
        --prefix "${install_dir}"
        OUTPUT_QUIET
    )
  else()
    foreach(component IN LISTS _COMPONENTS)
      ubpm_cmake(
          --install "${build_dir}"
          --config "${_BUILD_TYPE}"
          --prefix "${install_dir}"
          --component "${component}"
          OUTPUT_QUIET
      )
    endforeach()
  endif()

  file(WRITE "${UBPM_PATH}/prefix/${type_path}/${NAME}-${install_hash}" "${install_dir}")

  file(REMOVE_RECURSE "${build_dir}")
  file(WRITE "${install_hash_path}" "${install_hashable}")
  ubpm_msg(STATUS "Installed")
endmacro()

# Download the git source at the specified branch and optionally the specified
# commit, then delete .git to save space and prevent some IDEs from picking up
# the source as being under version control needlessly
macro(ubpm_install_git)
  if("$CACHE{UBPM_NO_GIT}")
    ubpm_msg(FATAL_ERROR "Git support is disabled")
  endif()

  ubpm_msg(STATUS "Cloning")

  file(REMOVE_RECURSE "${source_dir}")
  list(POP_FRONT _GIT repo branch commit)
  ubpm_call("${UBPM_GIT_EXECUTABLE}" clone "${repo}" "${source_dir}" -b "${branch}" --single-branch --quiet ERROR_QUIET)
  if(commit)
    ubpm_call("${UBPM_GIT_EXECUTABLE}" checkout "${commit}" -q WORKING_DIRECTORY "${source_dir}")
  endif()
  file(REMOVE_RECURSE "${source_dir}/.git")

  file(WRITE "${source_hash_path}" "${source_hashable}")
  ubpm_install_source_dir()
endmacro()

macro(ubpm_determine_hash_method)
  string(LENGTH "${_URL_HASH}" _length)
  if(_length EQUAL "32")
    set(hash_method MD5)
  elseif(_length EQUAL "40")
    set(hash_method SHA1)
  elseif(_length EQUAL "56")
    set(hash_method SHA224)
  elseif(_length EQUAL "64")
    set(hash_method SHA256)
  elseif(_length EQUAL "96")
    set(hash_method SHA384)
  elseif(_length EQUAL "128")
    set(hash_method SHA512)
  else()
    ubpm_msg(FATAL_ERROR "Could not determine hash method for URL_HASH (length: ${_length})")
  endif()
endmacro()

macro(ubpm_install_url)
  ubpm_determine_hash_method()
  set(dl_path "${UBPM_PATH}/download")
  file(REMOVE_RECURSE "${dl_path}")
  file(MAKE_DIRECTORY "${dl_path}")

  ubpm_msg(STATUS "Fetching")

  set(archive_path "${dl_path}/archive.zip")
  file(DOWNLOAD "${_URL}" "${archive_path}" STATUS dl_status)
  list(POP_FRONT dl_status dl_code dl_message)
  if(NOT dl_code EQUAL "0")
    ubpm_msg(FATAL_ERROR "Download failed with code ${dl_code} (${dl_message})")
  endif()

  file("${hash_method}" "${archive_path}" hash)
  if(NOT _URL_HASH STREQUAL hash)
    ubpm_msg(STATUS "Archive path: ${archive_path}")
    ubpm_msg(STATUS "Hash method: ${hash_method}")
    ubpm_msg(STATUS "URL_HASH: ${_URL_HASH}")
    ubpm_msg(STATUS "Hash of the file: ${hash}")
    ubpm_msg(FATAL_ERROR "Hash mismatch")
  endif()

  set(extract_path "${UBPM_PATH}/extract")
  file(REMOVE_RECURSE "${extract_path}")
  file(MAKE_DIRECTORY "${extract_path}")
  ubpm_cmake(-E tar xf "${archive_path}" WORKING_DIRECTORY "${extract_path}")
  file(REMOVE_RECURSE "${dl_path}")

  set(from_path "${extract_path}")
  if(_PATH)
    set(from_path "${from_path}/${_PATH}")
  else()
    file(GLOB content LIST_DIRECTORIES YES "${from_path}/*")
    list(LENGTH content content_length)
    if(content_length EQUAL "1" AND IS_DIRECTORY "${content}")
      set(from_path "${content}")
    endif()
  endif()
  get_filename_component(name_path "${source_dir}" DIRECTORY)
  file(MAKE_DIRECTORY "${name_path}")
  file(REMOVE_RECURSE "${source_dir}")
  file(RENAME "${from_path}" "${source_dir}")
  file(REMOVE_RECURSE "${extract_path}")

  # Make sure things above flush
  ubpm_cmake(-E sleep 1)

  file(WRITE "${source_hash_path}" "${source_hashable}")
  ubpm_install_source_dir()
endmacro()

macro(ubpm_dispatch)
  if(KIND STREQUAL "source")
    ubpm_install_source_dir()
  elseif(KIND STREQUAL "git")
    ubpm_install_git()
  elseif(KIND STREQUAL "url")
    ubpm_install_url()
  endif()
endmacro()

function(ubpm_gather_prefixes TYPE OUT)
  file(GLOB prefixes LIST_DIRECTORIES NO "${UBPM_PATH}/prefix/${TYPE}/*")
  set(result "")
  foreach(file IN LISTS prefixes)
    file(READ "${file}" prefix)
    list(APPEND result "${prefix}")
  endforeach()
  set("${OUT}" "${result}" PARENT_SCOPE)
endfunction()

function(ubpm_dependency NAME)
  if(NAME STREQUAL "")
    message(FATAL_ERROR "UBPM: no name provided")
  endif()

  set(oneValueArgs SOURCE_DIR URL URL_HASH BUILD_TYPE PATH SCRIPT_PATH)
  set(multiValueArgs GITHUB GIT COMPONENTS)
  cmake_parse_arguments(PARSE_ARGV 1 "" "OPTIONS" "${oneValueArgs}" "${multiValueArgs}")

  if(_OPTIONS)
    set(found_options NO)
    set(options_limit -1)
    math(EXPR limit "${ARGC} - 1")
    foreach(index RANGE 1 "${limit}")
      if(found_options)
        math(EXPR options_limit "${options_limit} + 1")
        set("options_${options_limit}" "${ARGV${index}}")
      elseif("${ARGV${index}}" STREQUAL "OPTIONS")
        set(found_options YES)
      endif()
    endforeach()
    if(options_limit EQUAL "-1")
      ubpm_msg(FATAL_ERROR "OPTIONS was defined without arguments")
    endif()
  endif()

  if(NOT _BUILD_TYPE AND DEFINED CACHE{CMAKE_BUILD_TYPE})
    set(_BUILD_TYPE "$CACHE{CMAKE_BUILD_TYPE}")
  endif()

  if(NOT _BUILD_TYPE)
    ubpm_msg(FATAL_ERROR "No build type was specified (CMAKE_BUILD_TYPE nor BUILD_TYPE)")
  endif()

  if(_SCRIPT_PATH)
    if(_SOURCE_DIR)
      ubpm_msg(FATAL_ERROR "Can't use SCRIPT_PATH with SOURCE_DIR source type")
    endif()

    if(NOT EXISTS "${_SCRIPT_PATH}")
      ubpm_msg(FATAL_ERROR "Script path must point to a file")
    endif()

    if(NOT "$CACHE{UBPM_NO_SCRIPT_WARNING}")
      ubpm_msg(AUTHOR_WARNING "If you have to provide a script, consider also submitting a patch to the dependency")
      set(UBPM_NO_SCRIPT_WARNING YES CACHE INTERNAL "Only warn once")
    endif()
  endif()

  set(source_hashable "")
  set(KIND "")

  if(_SOURCE_DIR)
    get_filename_component(source_dir "${_SOURCE_DIR}" REALPATH)
    set(source_hashable "${source_dir}")
    set(KIND source)
  else()
    set(source_dir "${UBPM_PATH}/source/${NAME}")
  endif()

  if(_GITHUB)
    set(_GIT "https://github.com/${_GITHUB}")
  endif()

  if(_GIT)
    list(LENGTH _GIT git_length)
    if(git_length LESS "2" OR "3" LESS git_length)
      ubpm_msg(FATAL_ERROR "Wrong git arguments")
    endif()
    set(source_hashable "${_GIT}")
    set(KIND git)
  endif()

  if(_URL)
    if(NOT _URL_HASH)
      ubpm_msg(FATAL_ERROR "No URL_HASH provided")
    endif()
    string(TOLOWER "${_URL_HASH}" _URL_HASH)
    set(source_hashable "${_URL}" "${_URL_HASH}" "${_PATH}")
    set(KIND url)
  endif()

  if(KIND STREQUAL "")
    ubpm_msg(FATAL_ERROR "Could not determine type")
  endif()

  set(script_hash "")
  if(_SCRIPT_PATH)
    file(SHA1 "${_SCRIPT_PATH}" script_hash)
  endif()

  set(source_hash "")
  if(NOT KIND STREQUAL "source")
    string(SHA1 source_hash "${script_hash};${source_hashable}")
    if(EXISTS "${source_dir}/.${source_hash}")
      set(KIND source)
    else()
      set(source_hash_path "${source_dir}/.${source_hash}")
    endif()
    set(source_dir "${source_dir}/${source_hash}")
  else()
    string(SHA1 source_hash "${source_hashable}")
  endif()

  set(install_hashable "${source_hash}" "${_BUILD_TYPE}" "${_OPTIONS}")
  string(SHA1 install_hash "${install_hashable}")

  set(type_path optimized)
  if(_BUILD_TYPE STREQUAL "Debug")
    set(type_path debug)
  endif()

  set(install_dir "${UBPM_PATH}/install/${type_path}/${NAME}")
  set(install_hash_path "${install_dir}/.${install_hash}")
  if(EXISTS "${install_hash_path}")
    ubpm_msg(STATUS "From install cache")
  else()
    if(NOT _SOURCE_DIR AND KIND STREQUAL "source")
      ubpm_msg(STATUS "From source cache")
    endif()

    set(install_dir "${install_dir}/${install_hash}")
    ubpm_dispatch()
  endif()

  ubpm_gather_prefixes("${type_path}" prefixes)
  if(NOT "$CACHE{UBPM_PREFIX_PATH_INIT}" STREQUAL "")
    list(PREPEND prefixes "$CACHE{UBPM_PREFIX_PATH_INIT}")
  endif()
  set(CMAKE_PREFIX_PATH "${prefixes}" CACHE STRING "" FORCE)
endfunction()
