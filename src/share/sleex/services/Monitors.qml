pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick


Singleton {
    id: root

    readonly property list<Monitor> monitors: []
    readonly property Monitor primary: monitors.find(m => m.primary) ?? null
    property int snapThreshold: 20

    reloadableId: "monitors"

    function setMonitorPosition(name: string, x: int, y: int): void {
        const monitor = monitors.find(m => m.name === name);
        if (!monitor) return;
        
        setPositionProc.exec([
            "hyprctl", "keyword", "monitor",
            `${name},${monitor.width}x${monitor.height},${x}x${y},${monitor.scale}`
        ]);
    }

    function snapMonitors(primaryName: string, secondaryName: string, position: string): void {
        const primary = monitors.find(m => m.name === primaryName);
        const secondary = monitors.find(m => m.name === secondaryName);
        if (!primary || !secondary) return;

        let x, y;
        switch (position) {
            case "right":
                x = primary.x + primary.width;
                y = primary.y;
                break;
            case "left":
                x = primary.x - secondary.width;
                y = primary.y;
                break;
            case "top":
                x = primary.x;
                y = primary.y - secondary.height;
                break;
            case "bottom":
                x = primary.x;
                y = primary.y + primary.height;
                break;
            default:
                return;
        }

        setMonitorPosition(secondaryName, x, y);
    }

    function toggleMonitor(name: string): void {
        const monitor = monitors.find(m => m.name === name);
        if (!monitor) return;
        
        const config = monitor.enabled ? 
            `${name},disabled` : 
            `${name},${monitor.width}x${monitor.height},${monitor.x}x${monitor.y},${monitor.scale}`;
            
        toggleProc.exec(["hyprctl", "keyword", "monitor", config]);
    }

    function refreshMonitors(): void {
        getMonitors.running = true;
    }

    // Get monitor information
    Process {
        id: getMonitors
        
        running: true
        command: ["hyprctl", "monitors", "-j"]
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        
        stdout: StdioCollector {
            onStreamFinished: {
                let monitorData;
                try {
                    monitorData = JSON.parse(text);
                } catch (e) {
                    console.error("Failed to parse monitor data:", e);
                    return;
                }

                const rMonitors = root.monitors;
                
                // Remove destroyed monitors
                const destroyed = rMonitors.filter(rm => 
                    !monitorData.find(m => m.name === rm.name)
                );
                for (const monitor of destroyed) {
                    rMonitors.splice(rMonitors.indexOf(monitor), 1).forEach(m => m.destroy());
                }

                // Update or create monitors
                for (const monitorInfo of monitorData) {
                    const match = rMonitors.find(m => m.name === monitorInfo.name);
                    if (match) {
                        match.lastIpcObject = monitorInfo;
                    } else {
                        rMonitors.push(monitorComp.createObject(root, {
                            lastIpcObject: monitorInfo
                        }));
                    }
                }
            }
        }
    }

    // Set monitor position
    Process {
        id: setPositionProc
        
        onExited: {
            getMonitors.running = true;
        }
    }

    // Toggle monitor
    Process {
        id: toggleProc
        
        onExited: {
            getMonitors.running = true;
        }
    }

    // Listen for Hyprland events
    Process {
        running: true
        command: ["socat", "-", "UNIX-CONNECT:/tmp/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"]
        
        stdout: SplitParser {
            onRead: {
                if (data.startsWith("monitoradded") || 
                    data.startsWith("monitorremoved") || 
                    data.startsWith("configreloaded")) {
                    getMonitors.running = true;
                }
            }
        }
    }

    component Monitor: QtObject {
        required property var lastIpcObject
        
        readonly property string name: lastIpcObject.name ?? ""
        readonly property int width: lastIpcObject.width ?? 0
        readonly property int height: lastIpcObject.height ?? 0
        readonly property int x: lastIpcObject.x ?? 0
        readonly property int y: lastIpcObject.y ?? 0
        readonly property real scale: lastIpcObject.scale ?? 1.0
        readonly property bool primary: lastIpcObject.focused ?? false
        readonly property bool enabled: width > 0 && height > 0
        readonly property string resolution: `${width}x${height}`
    }

    Component {
        id: monitorComp
        Monitor {}
    }
}