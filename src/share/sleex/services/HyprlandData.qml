pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

/**
 * Provides access to some Hyprland data not available in Quickshell.Hyprland.
 */
Singleton {
    id: root
    property var windowList: []
    property var addresses: []
    property var windowByAddress: ({})
    property var monitors: []
    property var layers: ({})

    function updateWindowList() {
        getClients.running = true
        getMonitors.running = true
    }

    function updateLayers() {
        getLayers.running = true
    }

    Component.onCompleted: {
        updateWindowList()
        updateLayers()
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            const skipped = ["activewindow", "focusedmon", "monitoradded",
                "createworkspace", "destroyworkspace", "moveworkspace",
                "activespecial", "movewindow", "windowtitle"];
            if (skipped.includes(event.name)) return;
            updateWindowList();
        }
    }

    property var biggestWindowPerWorkspace: ({})

    Process {
        id: getClients
        command: ["bash", "-c", "hyprctl clients -j | jq -c"]
        stdout: SplitParser {
            onRead: (data) => {
                root.windowList = JSON.parse(data)
                let tempWinByAddress = {}
                let tempBiggest = {}
                for (var i = 0; i < root.windowList.length; ++i) {
                    var win = root.windowList[i]
                    tempWinByAddress[win.address] = win
                    
                    const id = win.workspace.id;
                    const prev = tempBiggest[id];
                    const prevArea = prev ? prev.size[0] * prev.size[1] : 0;
                    const area = win.size[0] * win.size[1];
                    if (area > prevArea) tempBiggest[id] = win;
                }
                root.windowByAddress = tempWinByAddress
                root.addresses = root.windowList.map((win) => win.address)
                root.biggestWindowPerWorkspace = tempBiggest
            }
        }
    }
    Process {
        id: getMonitors
        command: ["bash", "-c", "hyprctl monitors -j | jq -c"]
        stdout: SplitParser {
            onRead: (data) => {
                root.monitors = JSON.parse(data)
            }
        }
    }

    Process {
        id: getLayers
        command: ["bash", "-c", "hyprctl layers -j | jq -c"]
        stdout: SplitParser {
            onRead: (data) => {
                root.layers = JSON.parse(data)
            }
        }
    }
}

