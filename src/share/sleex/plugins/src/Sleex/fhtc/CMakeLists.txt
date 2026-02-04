
qml_module(sleex-fhtc
    URI Sleex.Fhtc
    SOURCES
        ipc.hpp ipc.cpp
        workspaces.hpp workspaces.cpp
        plugin.cpp  
)

target_link_libraries(sleex-fhtc
    PRIVATE
        Qt6::Core
        Qt6::Qml
        Qt6::Network
)