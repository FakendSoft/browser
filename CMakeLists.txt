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

add_executable(FakendBrowserHelper MACOSX_BUNDLE ${FAKEND_HELPER_SOURCES})
set_target_properties(FakendBrowserHelper PROPERTIES
  OUTPUT_NAME "Fakend Browser Helper"
  MACOSX_BUNDLE_BUNDLE_NAME "Fakend Browser Helper"
  MACOSX_BUNDLE_GUI_IDENTIFIER "com.fakend.browser.helper"
  MACOSX_BUNDLE_INFO_PLIST "${CMAKE_SOURCE_DIR}/resources/FakendBrowserHelper/Info.plist"
)

foreach(target FakendBrowser FakendBrowserHelper)
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

add_dependencies(FakendBrowser FakendBrowserHelper)

set(CEF_FRAMEWORK_PATH "${CEF_ROOT}/Release/Chromium Embedded Framework.framework")

add_custom_command(TARGET FakendBrowser POST_BUILD
  COMMAND "${CMAKE_COMMAND}" -E make_directory "$<TARGET_BUNDLE_DIR:FakendBrowser>/Contents/Frameworks"
  COMMAND "${CMAKE_COMMAND}" -E copy_directory "${CEF_FRAMEWORK_PATH}" "$<TARGET_BUNDLE_DIR:FakendBrowser>/Contents/Frameworks/Chromium Embedded Framework.framework"
  COMMAND "${CMAKE_COMMAND}" -E copy_directory "$<TARGET_BUNDLE_DIR:FakendBrowserHelper>" "$<TARGET_BUNDLE_DIR:FakendBrowser>/Contents/Frameworks/Fakend Browser Helper.app"
)
