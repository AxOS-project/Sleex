find_package(Qt6 REQUIRED COMPONENTS Core Qml Gui Quick Concurrent Sql Network DBus Bluetooth)
find_package(PkgConfig REQUIRED)

set(QT_QML_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/qml")
qt_standard_project_setup(REQUIRES 6.9)

function(qml_module arg_TARGET)
    cmake_parse_arguments(
        PARSE_ARGV 1 arg
        "CUSTOM_PLUGIN"
        "URI;CLASS_NAME"
        "SOURCES;PLUGIN_SOURCES;LIBRARIES"
    )

    set(plugin_arguments)

    if(arg_CUSTOM_PLUGIN)
        if(NOT arg_CLASS_NAME)
            message(FATAL_ERROR
                "${arg_TARGET}: CUSTOM_PLUGIN requires CLASS_NAME"
            )
        endif()

        if(NOT arg_PLUGIN_SOURCES)
            message(FATAL_ERROR
                "${arg_TARGET}: CUSTOM_PLUGIN requires PLUGIN_SOURCES"
            )
        endif()

        list(APPEND plugin_arguments
            NO_GENERATE_PLUGIN_SOURCE
            NO_PLUGIN_OPTIONAL
            CLASS_NAME "${arg_CLASS_NAME}"
        )
    endif()

    qt_add_qml_module(${arg_TARGET}
        URI ${arg_URI}
        VERSION ${VERSION}
        ${plugin_arguments}
        SOURCES ${arg_SOURCES}
    )

    qt_query_qml_module(${arg_TARGET}
        URI module_uri
        VERSION module_version
        PLUGIN_TARGET module_plugin_target
        TARGET_PATH module_target_path
        QMLDIR module_qmldir
        TYPEINFO module_typeinfo
    )

    if(arg_CUSTOM_PLUGIN)
        target_sources(
            "${module_plugin_target}"
            PRIVATE
                ${arg_PLUGIN_SOURCES}
        )

        target_link_libraries(
            "${module_plugin_target}"
            PRIVATE
                Qt::Core
                Qt::Qml
        )
    endif()

    message(
        STATUS
        "Created QML module ${module_uri}, version ${module_version}"
    )

    set(module_dir "${INSTALL_QMLDIR}/${module_target_path}")

    install(
        TARGETS ${arg_TARGET}
        LIBRARY DESTINATION "${module_dir}"
        RUNTIME DESTINATION "${module_dir}"
    )

    install(
        TARGETS "${module_plugin_target}"
        LIBRARY DESTINATION "${module_dir}"
        RUNTIME DESTINATION "${module_dir}"
    )

    install(FILES "${module_qmldir}" DESTINATION "${module_dir}")
    install(FILES "${module_typeinfo}" DESTINATION "${module_dir}")

    target_link_libraries(
        ${arg_TARGET}
        PRIVATE
            Qt::Core
            Qt::Qml
            ${arg_LIBRARIES}
    )
endfunction()

add_subdirectory(services)
add_subdirectory(core)
add_subdirectory(utils)
add_subdirectory(widgets)
