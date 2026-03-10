pkg_check_modules(GLIB REQUIRED glib-2.0 gobject-2.0 gio-2.0)

qml_module(sleex-utils
    URI Sleex.Utils
    SOURCES
        DesktopStateManager.cpp DesktopStateManager.hpp
        DesktopModel.cpp DesktopModel.hpp
        plugin.cpp
)

target_include_directories(sleex-utils PRIVATE 
    ${LIBNM_INCLUDE_DIRS}
    ${GLIB_INCLUDE_DIRS}
)

target_link_libraries(sleex-utils PRIVATE 
    ${LIBNM_LIBRARIES}
    ${GLIB_LIBRARIES}
)

target_compile_options(sleex-utils PRIVATE 
    ${LIBNM_CFLAGS_OTHER}
    ${GLIB_CFLAGS_OTHER}
)

target_link_libraries(sleex-utils
    PRIVATE
        Qt6::Core
        Qt6::Qml
)