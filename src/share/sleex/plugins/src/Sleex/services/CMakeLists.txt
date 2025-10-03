pkg_check_modules(LIBNM REQUIRED libnm)
pkg_check_modules(GLIB REQUIRED glib-2.0 gobject-2.0 gio-2.0)

qml_module(sleex-services
    URI Sleex.Services
    SOURCES
        brightness.cpp brightness.hpp
        resourceUsage.cpp resourceUsage.hpp
        network.cpp network.hpp
        plugin.cpp  
)

target_include_directories(sleex-services PRIVATE 
    ${LIBNM_INCLUDE_DIRS}
    ${GLIB_INCLUDE_DIRS}
)

target_link_libraries(sleex-services PRIVATE 
    ${LIBNM_LIBRARIES}
    ${GLIB_LIBRARIES}
)

target_compile_options(sleex-services PRIVATE 
    ${LIBNM_CFLAGS_OTHER}
    ${GLIB_CFLAGS_OTHER}
)