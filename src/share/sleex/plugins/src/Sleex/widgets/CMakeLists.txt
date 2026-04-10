enable_language(C)

pkg_check_modules(GLIB REQUIRED glib-2.0 gobject-2.0 gio-2.0)

find_package(Qt6 REQUIRED COMPONENTS GuiPrivate)

pkg_check_modules(WAYLAND_CLIENT  REQUIRED IMPORTED_TARGET wayland-client)
pkg_check_modules(WAYLAND_PROTOS  REQUIRED IMPORTED_TARGET wayland-protocols)
pkg_check_modules(GBM             REQUIRED IMPORTED_TARGET gbm)
pkg_check_modules(DRM             REQUIRED IMPORTED_TARGET libdrm)
pkg_check_modules(EGL             REQUIRED IMPORTED_TARGET egl)
pkg_check_modules(GLESv2          REQUIRED IMPORTED_TARGET glesv2)

find_program(WAYLAND_SCANNER wayland-scanner REQUIRED)

pkg_get_variable(WL_PROTO_DIR wayland-protocols pkgdatadir)
set(PROTO_DIR "${CMAKE_SOURCE_DIR}/protocols")

set(WAYLAND_PROTO_SOURCES "")

macro(wayland_add_protocol_sources _xml)
    get_filename_component(_base "${_xml}" NAME_WE)
    set(_header  "${CMAKE_CURRENT_BINARY_DIR}/${_base}-client-protocol.h")
    set(_source  "${CMAKE_CURRENT_BINARY_DIR}/${_base}-client-protocol.c")

    add_custom_command(
        OUTPUT "${_header}"
        COMMAND "${WAYLAND_SCANNER}" client-header "${_xml}" "${_header}"
        DEPENDS "${_xml}"
        VERBATIM
    )
    add_custom_command(
        OUTPUT "${_source}"
        COMMAND "${WAYLAND_SCANNER}" private-code "${_xml}" "${_source}"
        DEPENDS "${_xml}"
        VERBATIM
    )
    list(APPEND WAYLAND_PROTO_SOURCES "${_header}" "${_source}")
endmacro()

wayland_add_protocol_sources("${WL_PROTO_DIR}/staging/ext-image-copy-capture/ext-image-copy-capture-v1.xml")
wayland_add_protocol_sources("${WL_PROTO_DIR}/staging/ext-image-capture-source/ext-image-capture-source-v1.xml")
wayland_add_protocol_sources("${WL_PROTO_DIR}/staging/ext-foreign-toplevel-list/ext-foreign-toplevel-list-v1.xml")
wayland_add_protocol_sources("${WL_PROTO_DIR}/unstable/linux-dmabuf/linux-dmabuf-unstable-v1.xml")

add_library(sleex_wayland_protocols STATIC ${WAYLAND_PROTO_SOURCES})
target_link_libraries(sleex_wayland_protocols PUBLIC PkgConfig::WAYLAND_CLIENT)
target_include_directories(sleex_wayland_protocols PUBLIC ${CMAKE_CURRENT_BINARY_DIR})
set_target_properties(sleex_wayland_protocols PROPERTIES POSITION_INDEPENDENT_CODE ON)

qml_module(sleex-widgets
    URI Sleex.Widgets
    SOURCES
        ContributionCalendar.cpp ContributionCalendar.hpp
        ExtCaptureItem.cpp ExtCaptureItem.hpp
        GbmBuffer.cpp GbmBuffer.hpp
        plugin.cpp
)

target_include_directories(sleex-widgets PRIVATE 
    ${CMAKE_CURRENT_BINARY_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${LIBNM_INCLUDE_DIRS}
    ${GLIB_INCLUDE_DIRS}
)

target_link_libraries(sleex-widgets PRIVATE 
    ${LIBNM_LIBRARIES}
    ${GLIB_LIBRARIES}
    sleex_wayland_protocols
)

target_compile_options(sleex-widgets PRIVATE 
    ${LIBNM_CFLAGS_OTHER}
    ${GLIB_CFLAGS_OTHER}
)

target_link_libraries(sleex-widgets
    PRIVATE
        Qt6::Core
        Qt6::Gui
        Qt6::GuiPrivate
        Qt6::Qml
        Qt6::Quick
        PkgConfig::WAYLAND_CLIENT
        PkgConfig::GBM
        PkgConfig::DRM
        PkgConfig::EGL
        PkgConfig::GLESv2
)