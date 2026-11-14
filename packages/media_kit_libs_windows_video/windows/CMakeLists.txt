# This file is a part of media_kit (https://github.com/media-kit/media-kit).
#
# Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
# All rights reserved.
# Use of this source code is governed by MIT license that can be found in the LICENSE file.

cmake_minimum_required(VERSION 3.14)
cmake_policy(SET CMP0175 NEW)

# This option is read by the other packages which are part of package:media_kit.
option(MEDIA_KIT_LIBS_AVAILABLE "package:media_kit libraries are available." ON)

set(PROJECT_NAME "media_kit_libs_windows_video")
project(${PROJECT_NAME} LANGUAGES CXX)

# Deal with MSVC incompatiblity
add_compile_definitions(_DISABLE_CONSTEXPR_MUTEX_CONSTRUCTOR)

# ------------------------------------------------------------------------------
function(download_and_verify url md5 locationForArchive)
  # Check if the archive exists.
  if(EXISTS "${locationForArchive}")
    file(MD5 "${locationForArchive}" ARCHIVE_MD5)

    # If MD5 doesn't match, delete the archive to download again.
    if(NOT md5 STREQUAL ARCHIVE_MD5)
      file(REMOVE "${locationForArchive}")
      message(STATUS "MD5 mismatch. File deleted.")
    endif()
  endif()

  # Download the archive if it doesn't exist.
  if(NOT EXISTS "${locationForArchive}")
    message(STATUS "Downloading archive from ${url}...")
    file(DOWNLOAD "${url}" "${locationForArchive}")
    message(STATUS "Downloaded archive to ${locationForArchive}.")

    # Verify MD5 of the newly downloaded file.
    file(MD5 "${locationForArchive}" ARCHIVE_MD5)

    if(md5 STREQUAL ARCHIVE_MD5)
      message(STATUS "${locationForArchive} Verification successful.")
    else()
      message(FATAL_ERROR "${locationForArchive} Integrity check failed, please try to re-build project again.")
    endif()
  endif()
endfunction()

function(check_directory_exists_and_not_empty dir result_var)
  # Check if the directory exists
  if(EXISTS "${dir}")
    # Check if the directory is not empty
    file(GLOB dir_contents "${dir}/*")

    if(dir_contents)
      set(${result_var} TRUE PARENT_SCOPE)
    else()
      set(${result_var} FALSE PARENT_SCOPE)
      message(STATUS "Directory ${dir} exists but is empty!")
    endif()
  else()
    set(${result_var} FALSE PARENT_SCOPE)
    message(STATUS "Directory ${dir} does not exist!")
  endif()
endfunction()

# Both arches take shinchiro's libmpv rather than the media-kit archives. Those
# pass --disable-decoders and re-enable an allowlist that leaves out pgssub, so
# a PGS track stayed listed and selectable while mpv had no decoder to turn a
# sample into a picture. shinchiro's build excludes only libaom_av1, so every
# other decoder is present. The download points at the SourceForge mirror
# because the matching GitHub releases are pruned once thirty newer builds
# exist.
#
# Flutter sets FLUTTER_TARGET_PLATFORM to "windows-x64" or "windows-arm64", but
# leaves it unset when this package is configured on its own, and dereferencing
# it unset makes the if() below a syntax error.
if(NOT DEFINED FLUTTER_TARGET_PLATFORM)
  set(FLUTTER_TARGET_PLATFORM "windows-x64")
endif()

if(FLUTTER_TARGET_PLATFORM STREQUAL "windows-arm64")
  set(LIBMPV "mpv-dev-aarch64-20260607-git-71ebd08.7z")
  set(LIBMPV_MD5 "c1ffe70ca6f4c17dc4b2ff0e28b49ea2")
else()
  set(LIBMPV "mpv-dev-x86_64-20260607-git-71ebd08.7z")
  set(LIBMPV_MD5 "650a6c8fde5855a7cb3e219616d5d5f2")
endif()

set(LIBMPV_URL "https://downloads.sourceforge.net/project/mpv-player-windows/libmpv/${LIBMPV}")

# Download location of the libmpv archive.
set(LIBMPV_ARCHIVE "${CMAKE_BINARY_DIR}/${LIBMPV}")
set(LIBMPV_SRC "${CMAKE_BINARY_DIR}/libmpv")

download_and_verify(
  ${LIBMPV_URL}
  ${LIBMPV_MD5}
  ${LIBMPV_ARCHIVE}
)

check_directory_exists_and_not_empty(${LIBMPV_SRC} LIBMPV_SRC_VALID)

# The ARM64 archives use the 7-Zip ARM64 BCJ branch filter (codec 0x0a, added
# in 7-Zip 23.00), which the libarchive bundled inside the VS2022 CMake has no
# decoder for. Depending on the archive, cmake -E tar either stops with a codec
# error or writes out a DLL of the right size holding the wrong bytes, so
# reaching a real 7-Zip is load bearing rather than a convenience.
find_program(SEVENZ_EXECUTABLE
  NAMES 7z 7za 7zr
  HINTS "$ENV{ProgramW6432}/7-Zip" "$ENV{ProgramFiles}/7-Zip"
        "$ENV{ProgramFiles\(x86\)}/7-Zip" "C:/Program Files/7-Zip"
)

function(require_sevenzip_on_arm64 archive_name)
  if(FLUTTER_TARGET_PLATFORM STREQUAL "windows-arm64" AND NOT SEVENZ_EXECUTABLE)
    message(FATAL_ERROR
      "7-Zip is required to extract the ARM64 ${archive_name} archive. "
      "Install 7-Zip 23.00 or newer.")
  endif()
endfunction()

# Extract the libmpv archive.
if(NOT LIBMPV_SRC_VALID)
  message(STATUS "Extracting ${LIBMPV}...")
  make_directory("${LIBMPV_SRC}")
  add_custom_target("${PROJECT_NAME}_LIBMPV_EXTRACT" ALL)
  
  require_sevenzip_on_arm64("libmpv")
  if(SEVENZ_EXECUTABLE)
    message(STATUS "Using 7zip for extraction: ${SEVENZ_EXECUTABLE}")
    add_custom_command(
      TARGET "${PROJECT_NAME}_LIBMPV_EXTRACT"
      POST_BUILD
      COMMAND "${SEVENZ_EXECUTABLE}" x -y "-o${LIBMPV_SRC}" "\"${LIBMPV_ARCHIVE}\""
      COMMAND xcopy "\"${LIBMPV_SRC}/include/mpv\"" "\"${LIBMPV_SRC}/mpv\"" /E /H /C /I
      COMMAND rmdir "\"${LIBMPV_SRC}/include\"" /S /Q
      COMMAND ren "\"${LIBMPV_SRC}/mpv\"" "\"include\""
      WORKING_DIRECTORY "${LIBMPV_SRC}"
    )
  else()
    message(STATUS "7zip not found, falling back to CMake tar")
    add_custom_command(
      TARGET "${PROJECT_NAME}_LIBMPV_EXTRACT"
      POST_BUILD
      COMMAND "${CMAKE_COMMAND}" -E tar xzf "\"${LIBMPV_ARCHIVE}\""
      COMMAND xcopy "\"${LIBMPV_SRC}/include/mpv\"" "\"${LIBMPV_SRC}/mpv\"" /E /H /C /I
      COMMAND rmdir "\"${LIBMPV_SRC}/include\"" /S /Q
      COMMAND ren "\"${LIBMPV_SRC}/mpv\"" "\"include\""
      WORKING_DIRECTORY "${LIBMPV_SRC}"
    )
  endif()
endif()

# ------------------------------------------------------------------------------

# ANGLE archive containing the pre-built shared libraries & headers. The
# upstream archive is x64 only, so ARM64 takes libEGL and libGLESv2 built for
# aarch64 from the fork behind media-kit's own Windows ARM64 work.
if(FLUTTER_TARGET_PLATFORM STREQUAL "windows-arm64")
  set(ANGLE "ANGLE_WINARM64.7z")
  set(ANGLE_URL "https://github.com/talynone/flutter-windows-ANGLE-OpenGL-ES/releases/download/v1.0.1/ANGLE_WINARM64.7z")
  set(ANGLE_MD5 "b56aaae894ccf6c8ee90b59ee642a787")
else()
  set(ANGLE "ANGLE.7z")
  set(ANGLE_URL "https://github.com/alexmercerind/flutter-windows-ANGLE-OpenGL-ES/releases/download/v1.0.1/ANGLE.7z")
  set(ANGLE_MD5 "e866f13e8d552348058afaafe869b1ed")
endif()

# Download location of the ANGLE archive.
set(ANGLE_ARCHIVE "${CMAKE_BINARY_DIR}/${ANGLE}")
set(ANGLE_SRC "${CMAKE_BINARY_DIR}/ANGLE")

download_and_verify(
  ${ANGLE_URL}
  ${ANGLE_MD5}
  ${ANGLE_ARCHIVE}
)

check_directory_exists_and_not_empty(${ANGLE_SRC} ANGLE_SRC_VALID)

# Extract the ANGLE archive.
if(NOT ANGLE_SRC_VALID)
  message(STATUS "Extracting ${ANGLE}...")
  make_directory("${ANGLE_SRC}")
  add_custom_target("${PROJECT_NAME}_ANGLE_EXTRACT" ALL)
  
  require_sevenzip_on_arm64("ANGLE")
  if(SEVENZ_EXECUTABLE)
    message(STATUS "Using 7zip for extraction: ${SEVENZ_EXECUTABLE}")
    add_custom_command(
      TARGET "${PROJECT_NAME}_ANGLE_EXTRACT"
      POST_BUILD
      COMMAND "${SEVENZ_EXECUTABLE}" x -y "-o${ANGLE_SRC}" "\"${ANGLE_ARCHIVE}\""
      WORKING_DIRECTORY "${ANGLE_SRC}"
    )
  else()
    message(STATUS "7zip not found, falling back to CMake tar")
    add_custom_command(
      TARGET "${PROJECT_NAME}_ANGLE_EXTRACT"
      POST_BUILD
      COMMAND "${CMAKE_COMMAND}" -E tar xzf "\"${ANGLE_ARCHIVE}\""
      WORKING_DIRECTORY "${ANGLE_SRC}"
    )
  endif()
endif()

# ------------------------------------------------------------------------------
set(PLUGIN_NAME "media_kit_libs_windows_video_plugin")

add_library(
  ${PLUGIN_NAME} SHARED
  "include/media_kit_libs_windows_video/media_kit_libs_windows_video_plugin_c_api.h"
  "media_kit_libs_windows_video_plugin_c_api.cpp"
)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(
  ${PLUGIN_NAME}
  PROPERTIES
  CXX_VISIBILITY_PRESET
  hidden
)
target_compile_definitions(
  ${PLUGIN_NAME}
  PRIVATE
  FLUTTER_PLUGIN_IMPL
)

target_include_directories(
  ${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
)
target_link_libraries(
  ${PLUGIN_NAME}
  PRIVATE
  flutter
  flutter_wrapper_plugin
)

set(
  media_kit_libs_windows_video_bundled_libraries
  "${LIBMPV_SRC}/libmpv-2.dll"
  "${ANGLE_SRC}/d3dcompiler_47.dll"
  "${ANGLE_SRC}/libEGL.dll"
  "${ANGLE_SRC}/libGLESv2.dll"
  "${ANGLE_SRC}/vk_swiftshader.dll"
  "${ANGLE_SRC}/vulkan-1.dll"
  "${ANGLE_SRC}/zlib.dll"
)

# The ARM64 ANGLE DLLs link libc++.dll dynamically. It ships in the ARM64
# archive and is absent from the x64 one, so listing it unconditionally would
# break x64 packaging.
if(FLUTTER_TARGET_PLATFORM STREQUAL "windows-arm64")
  list(APPEND media_kit_libs_windows_video_bundled_libraries "${ANGLE_SRC}/libc++.dll")
endif()

set(
  media_kit_libs_windows_video_bundled_libraries
  "${media_kit_libs_windows_video_bundled_libraries}"
  PARENT_SCOPE
)
