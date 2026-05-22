cmake_minimum_required(VERSION 3.25)

project(FakendBrowser VERSION 0.1.0 LANGUAGES CXX OBJCXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_OBJCXX_STANDARD 20)
set(CMAKE_OBJCXX_STANDARD_REQUIRED ON)
set(CMAKE_OSX_DEPLOYMENT_TARGET "14.0" CACHE STRING "Minimum macOS deployment target")

set(CEF_ROOT "${CMAKE_SOURCE_DIR}/vendor/cef/current" CACHE PATH "Path to the extracted CEF binary distribution")

if(NOT EXISTS "${CEF_ROOT}/cmake/FindCEF.cmake")
  message(FATAL_ERROR "CEF_ROOT is not ready at '${CEF_ROOT}'. Run scripts/fetch-cef.sh first.")
endif()

list(APPEND CMAKE_MODULE_PATH "${CEF_ROOT}/cmake")
find_package(CEF REQUIRED)

add_subdirectory("${CEF_ROOT}/libcef_dll" "${CMAKE_BINARY_DIR}/libcef_dll_wrapper")

set(FAKEND_APP_SOURCES
  src/app/AppDelegate.mm
  src/app/BrowserTab.mm
  src/app/BrowserWindowController.mm
  src/app/FakendCefApp.mm
  src/app/FakendClient.mm
  src/app/main.mm
)

set(FAKEND_HELPER_SOURCES
  src/helper/main.mm
  src/app/FakendCefApp.mm
)

add_executable(FakendBrowser MACOSX_BUNDLE ${FAKEND_APP_SOURCES})
set_target_properties(FakendBrowser PROPERTIES
  OUTPUT_NAME "Fakend Browser"
  MACOSX_BUNDLE_BUNDLE_NAME "Fakend Browser"
  MACOSX_BUNDLE_GUI_IDENTIFIER "com.fakend.browser"
  MACOSX_BUNDLE_INFO_PLIST "${CMAKE_SOURCE_DIR}/resources/FakendBrowser/Info.plist"
)

set(FAKEND_HELPER_APP_SUFFIXES
  "::"
  " (Alerts):_alerts:.alerts"
  " (GPU):_gpu:.gpu"
  " (Plugin):_plugin:.plugin"
  " (Renderer):_renderer:.renderer"
)
set(FAKEND_HELPER_TARGETS)

foreach(helper_suffix_list ${FAKEND_HELPER_APP_SUFFIXES})
  string(REPLACE ":" ";" helper_suffix_parts "${helper_suffix_list}")
  list(GET helper_suffix_parts 0 helper_name_suffix)
  list(GET helper_suffix_parts 1 helper_target_suffix)
  list(GET helper_suffix_parts 2 helper_bundle_id_suffix)

  set(helper_target "FakendBrowserHelper${helper_target_suffix}")
  set(helper_output_name "Fakend Browser Helper${helper_name_suffix}")
  set(helper_bundle_id "com.fakend.browser.helper${helper_bundle_id_suffix}")
  set(helper_info_plist "${CMAKE_BINARY_DIR}/${helper_target}-Info.plist")

  file(READ "${CMAKE_SOURCE_DIR}/resources/FakendBrowserHelper/Info.plist" helper_info_contents)
  string(REPLACE "<string>Fakend Browser Helper</string>"
                 "<string>${helper_output_name}</string>"
                 helper_info_contents
                 "${helper_info_contents}")
  string(REPLACE "<string>com.fakend.browser.helper</string>"
                 "<string>${helper_bundle_id}</string>"
                 helper_info_contents
                 "${helper_info_contents}")
  file(WRITE "${helper_info_plist}" "${helper_info_contents}")

  add_executable(${helper_target} MACOSX_BUNDLE ${FAKEND_HELPER_SOURCES})
  set_target_properties(${helper_target} PROPERTIES
    OUTPUT_NAME "${helper_output_name}"
    MACOSX_BUNDLE_BUNDLE_NAME "${helper_output_name}"
    MACOSX_BUNDLE_GUI_IDENTIFIER "${helper_bundle_id}"
    MACOSX_BUNDLE_INFO_PLIST "${helper_info_plist}"
  )
  list(APPEND FAKEND_HELPER_TARGETS ${helper_target})
endforeach()

foreach(target FakendBrowser ${FAKEND_HELPER_TARGETS})
  target_include_directories(${target} PRIVATE
    "${CMAKE_SOURCE_DIR}/src"
    "${CEF_ROOT}"
  )
  target_compile_options(${target} PRIVATE
    -fobjc-arc
  )
  target_link_libraries(${target} PRIVATE
    libcef_dll_wrapper
    ${CEF_STANDARD_LIBS}
    "-framework Cocoa"
  )
  add_dependencies(${target} libcef_dll_wrapper)
endforeach()

add_dependencies(FakendBrowser ${FAKEND_HELPER_TARGETS})

set(CEF_FRAMEWORK_PATH "${CEF_ROOT}/Release/Chromium Embedded Framework.framework")

add_custom_command(TARGET FakendBrowser POST_BUILD
  COMMAND "${CMAKE_COMMAND}" -E make_directory "$<TARGET_BUNDLE_DIR:FakendBrowser>/Contents/Frameworks"
  COMMAND "${CMAKE_COMMAND}" -E copy_directory "${CEF_FRAMEWORK_PATH}" "$<TARGET_BUNDLE_DIR:FakendBrowser>/Contents/Frameworks/Chromium Embedded Framework.framework"
  VERBATIM
)

foreach(helper_target ${FAKEND_HELPER_TARGETS})
  add_custom_command(TARGET FakendBrowser POST_BUILD
    COMMAND "${CMAKE_COMMAND}" -E copy_directory "$<TARGET_BUNDLE_DIR:${helper_target}>" "$<TARGET_BUNDLE_DIR:FakendBrowser>/Contents/Frameworks/$<TARGET_PROPERTY:${helper_target},OUTPUT_NAME>.app"
    VERBATIM
  )
endforeach()
