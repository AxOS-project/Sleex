qml_module(sleex-fhtc
    URI Sleex.Fhtc
    SOURCES
        ipc.cpp ipc.hpp
        workspaces.cpp workspaces.hpp
        monitors.cpp monitors.hpp
        plugin.cpp
)

target_link_libraries(sleex-fhtc
    PRIVATE
        Qt6::Core
        Qt6::Qml
        Qt6::Network
)
