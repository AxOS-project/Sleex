pkg_check_modules(GLIB REQUIRED glib-2.0 gobject-2.0 gio-2.0)

qml_module(sleex-widgets
    URI Sleex.Widgets
    SOURCES
        ContributionCalendar.cpp ContributionCalendar.hpp
        plugin.cpp
)

target_include_directories(sleex-widgets PRIVATE 
    ${LIBNM_INCLUDE_DIRS}
    ${GLIB_INCLUDE_DIRS}
)

target_link_libraries(sleex-widgets PRIVATE 
    ${LIBNM_LIBRARIES}
    ${GLIB_LIBRARIES}
)

target_compile_options(sleex-widgets PRIVATE 
    ${LIBNM_CFLAGS_OTHER}
    ${GLIB_CFLAGS_OTHER}
)

target_link_libraries(sleex-widgets
    PRIVATE
        Qt6::Core
        Qt6::Qml
        Qt6::Quick
)