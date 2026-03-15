pkg_check_modules(GLIB REQUIRED glib-2.0 gobject-2.0 gio-2.0)

qml_module(sleex-core
    URI Sleex.Core
    SOURCES
        init.cpp init.hpp
        plugin.cpp
    DEPENDENCIES
            Qt::Sql
)

target_include_directories(sleex-core PRIVATE 
    ${LIBNM_INCLUDE_DIRS}
    ${GLIB_INCLUDE_DIRS}
)

target_link_libraries(sleex-core PRIVATE 
    ${LIBNM_LIBRARIES}
    ${GLIB_LIBRARIES}
)

target_compile_options(sleex-core PRIVATE 
    ${LIBNM_CFLAGS_OTHER}
    ${GLIB_CFLAGS_OTHER}
)

target_link_libraries(sleex-core
    PRIVATE
        Qt6::Core
        Qt6::Qml
        Qt6::Sql
)