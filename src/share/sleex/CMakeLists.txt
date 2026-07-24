cmake_minimum_required(VERSION 3.19)

project(sleex VERSION 1.15 LANGUAGES CXX)

find_package(Qt6 REQUIRED COMPONENTS LinguistTools)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")
set(CMAKE_INSTALL_PREFIX "/")

set(DISTRIBUTOR "Unset" CACHE STRING "Distributor")
set(INSTALL_LIBDIR "usr/lib/sleex" CACHE STRING "Library install dir")
set(INSTALL_QMLDIR "usr/lib/qt6/qml" CACHE STRING "QML install dir")

add_subdirectory(plugins)

qt6_add_translations(
    TARGETS sleex-coreplugin
    TS_FILES "${CMAKE_CURRENT_SOURCE_DIR}/translations/sleex_pt_BR.ts"
    RESOURCE_PREFIX "/i18n"
    LRELEASE_OPTIONS -nounfinished
)
