# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "native_file_explorer_launcher")
project(${PROJECT_NAME} LANGUAGES CXX)

cmake_policy(VERSION 3.14...3.25)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "native_file_explorer_launcher_plugin")

list(APPEND PLUGIN_SOURCES
  "launcher.cpp"
  "launcher.h"
  "messages.g.cpp"
  "messages.g.h"
  "native_file_explorer_launcher_plugin.cpp"
  "native_file_explorer_launcher_plugin.h"
)

# Shell, association and image APIs beyond the default Windows libraries.
set(PLUGIN_SYSTEM_LIBRARIES shlwapi windowscodecs)

add_library(${PLUGIN_NAME} SHARED
  "include/native_file_explorer_launcher/native_file_explorer_launcher_plugin_c_api.h"
  "native_file_explorer_launcher_plugin_c_api.cpp"
  ${PLUGIN_SOURCES}
)
apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE
  flutter flutter_wrapper_plugin ${PLUGIN_SYSTEM_LIBRARIES})

set(native_file_explorer_launcher_bundled_libraries
  ""
  PARENT_SCOPE
)

# === Tests ===
# Built only with the example app (which sets this variable), so apps using
# the plugin don't build them. After building the example, run:
#   build\windows\x64\plugins\native_file_explorer_launcher\Debug\native_file_explorer_launcher_test.exe
if (${include_${PROJECT_NAME}_tests})
set(TEST_RUNNER "${PROJECT_NAME}_test")
enable_testing()

include(FetchContent)
FetchContent_Declare(
  googletest
  URL https://github.com/google/googletest/archive/refs/tags/v1.17.0.zip
)
# Prevent overriding the parent project's compiler/linker settings
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
# Disable install commands for gtest so it doesn't end up in the bundle.
set(INSTALL_GTEST OFF CACHE BOOL "Disable installation of googletest" FORCE)
FetchContent_MakeAvailable(googletest)

# The plugin's C API is not very useful for unit testing, so build the sources
# directly into the test binary rather than using the DLL.
add_executable(${TEST_RUNNER}
  test/launcher_test.cpp
  test/plugin_test.cpp
  ${PLUGIN_SOURCES}
)
apply_standard_settings(${TEST_RUNNER})
target_include_directories(${TEST_RUNNER} PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(${TEST_RUNNER} PRIVATE
  flutter_wrapper_plugin gtest_main gmock ${PLUGIN_SYSTEM_LIBRARIES})
# flutter_wrapper_plugin has link dependencies on the Flutter DLL.
add_custom_command(TARGET ${TEST_RUNNER} POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
  "${FLUTTER_LIBRARY}" $<TARGET_FILE_DIR:${TEST_RUNNER}>
)

include(GoogleTest)
gtest_discover_tests(${TEST_RUNNER})
endif()
