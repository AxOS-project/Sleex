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
    property var biggestWindowPerWorkspace: ({})

    // Whitelist only window/workspace/monitor-mutating events so cursor, title, and layer chatter stays silent.
    readonly property var _trackedEvents: new Set([
        "openwindow",
        "closewindow",
        "movewindowv2",
        "workspacev2",
        "changefloatingmode",
        "fullscreen",
        "monitoraddedv2",
        "monitorremovedv2",
        "configreloaded"
    ])

    function updateWindowList() {
        getClients.trigger()
        getMonitors.trigger()
    }

    function updateLayers() {
        getLayers.trigger()
    }

    function _parseJson(raw, label) {
        if (!raw || raw.trim().length === 0) return null
        try {
            return JSON.parse(raw)
        } catch (e) {
            console.warn(`[HyprlandData] Failed to parse ${label}:`, e)
            return null
        }
    }

    function _biggestWindowsEqual(a, b) {
        const keysA = Object.keys(a)
        const keysB = Object.keys(b)
        if (keysA.length !== keysB.length) return false
        for (let i = 0; i < keysA.length; ++i) {
            const k = keysA[i]
            const wa = a[k]
            const wb = b[k]
            if (!wa || !wb) return false
            if (wa.address !== wb.address || wa.class !== wb.class) return false
            if ((wa.size?.[0] ?? 0) !== (wb.size?.[0] ?? 0) || (wa.size?.[1] ?? 0) !== (wb.size?.[1] ?? 0)) return false
        }
        return true
    }

    function _applyClients(clients) {
        const tempWinByAddress = {}
        const tempAddresses = []
        const tempBiggest = {}
        for (let i = 0; i < clients.length; ++i) {
            const win = clients[i]
            tempWinByAddress[win.address] = win
            tempAddresses.push(win.address)

            const id = win.workspace?.id
            if (id === undefined) continue
            const prev = tempBiggest[id]
            const prevArea = prev ? (prev.size?.[0] ?? 0) * (prev.size?.[1] ?? 0) : 0
            const area = (win.size?.[0] ?? 0) * (win.size?.[1] ?? 0)
            if (area > prevArea) tempBiggest[id] = win
        }
        root.windowList = clients
        root.windowByAddress = tempWinByAddress
        root.addresses = tempAddresses
        if (!root._biggestWindowsEqual(root.biggestWindowPerWorkspace, tempBiggest)) {
            root.biggestWindowPerWorkspace = tempBiggest
        }
    }

    Component.onCompleted: {
        updateWindowList()
        updateLayers()
    }

    Timer {
        id: updateTimer
        interval: 25
        repeat: false
        onTriggered: root.updateWindowList()
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (root._trackedEvents.has(event.name)) {
                updateTimer.restart()
            }
        }
    }

    component HyprctlJsonProcess: Process {
        id: proc
        required property string query
        property bool rerunPending: false
        signal jsonReady(var data)

        function trigger() {
            if (running) {
                rerunPending = true
                return
            }
            running = true
        }

        command: ["hyprctl", "-j", proc.query]
        stdout: StdioCollector {
            onStreamFinished: {
                const parsed = root._parseJson(text, proc.query)
                if (parsed !== null) {
                    proc.jsonReady(parsed)
                }
            }
        }
        onExited: {
            if (rerunPending) {
                Qt.callLater(() => {
                    if (!proc.running && proc.rerunPending) {
                        proc.rerunPending = false
                        proc.running = true
                    }
                })
            }
        }
    }

    HyprctlJsonProcess {
        id: getClients
        query: "clients"
        onJsonReady: (clients) => root._applyClients(clients)
    }

    HyprctlJsonProcess {
        id: getMonitors
        query: "monitors"
        onJsonReady: (monitors) => { root.monitors = monitors }
    }

    HyprctlJsonProcess {
        id: getLayers
        query: "layers"
        onJsonReady: (layers) => { root.layers = layers }
    }
}

