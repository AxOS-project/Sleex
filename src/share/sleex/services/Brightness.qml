pragma Singleton
pragma ComponentBehavior: Bound

// From https://github.com/caelestia-dots/shell/ (`quickshell` branch) with modifications.
// License: GPLv3

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import Sleex.Fhtc

/**
 * For managing brightness of monitors. Supports both brightnessctl and ddcutil.
 */
Singleton {
    id: root

    signal brightnessChanged()

    property var ddcMonitors: []
    readonly property alias monitors: monitorVariants.instances

    function getMonitorForScreen(screen: ShellScreen): var {
        return monitors.find(m => m.screen === screen);
    }

    function getFocusedMonitor(): var {
        const focusedName = FhtcMonitors.activeMonitorName;
        return focusedName ? monitors.find(m => focusedName === m.screen.name) : undefined;
    }

    function increaseBrightness(): void {
        const monitor = getFocusedMonitor();
        if (monitor)
            monitor.setBrightness(monitor.brightness + 0.05);
    }

    function decreaseBrightness(): void {
        const monitor = getFocusedMonitor();
        if (monitor)
            monitor.setBrightness(monitor.brightness - 0.05);
    }

    function setMonitorBrightness(b): void {
        const monitor = getFocusedMonitor();
        if (monitor)
            monitor.setBrightness(b);
    }

    reloadableId: "brightness"

    onMonitorsChanged: ddcDetectTimer.restart()

    Component.onCompleted: {
        if (monitors.length > 0 && !ddcProc.running && !ddcDetectTimer.running)
            ddcDetectTimer.restart();
    }

    // Coalesce screen hotplug bursts so ddcutil detect runs once per topology change.
    Timer {
        id: ddcDetectTimer
        interval: 50
        repeat: false
        onTriggered: {
            if (root.monitors.length === 0)
                return;
            if (ddcProc.running) {
                ddcProc.pendingRestart = true;
                return;
            }
            ddcProc.detected = [];
            ddcProc.running = true;
        }
    }

    Process {
        id: ddcProc

        property var detected: []
        property bool pendingRestart: false

        command: ["ddcutil", "detect", "--brief"]
        stdout: SplitParser {
            splitMarker: "\n\n"
            onRead: data => {
                const trimmed = data.trim();
                if (!trimmed.startsWith("Display "))
                    return;
                const lines = trimmed.split("\n").map(l => l.trim());
                const model = lines.find(l => l.startsWith("Monitor:"))?.split(":")[2];
                const busNum = lines.find(l => l.startsWith("I2C bus:"))?.split("/dev/i2c-")[1];
                if (model && busNum) {
                    ddcProc.detected.push({ model, busNum });
                }
            }
        }
        onRunningChanged: {
            if (running || ddcDetectTimer.running)
                return;
            if (pendingRestart) {
                pendingRestart = false;
                detected = [];
                running = true;
                return;
            }
            root.ddcMonitors = detected;
            for (let i = 0; i < root.monitors.length; i++) {
                const m = root.monitors[i];
                if (m)
                    m.syncBackend();
            }
        }
    }

    component BrightnessMonitor: QtObject {
        id: monitor

        required property ShellScreen screen
        readonly property bool isDdc: root.ddcMonitors.some(m => m.model === screen.model)
        readonly property string busNum: root.ddcMonitors.find(m => m.model === screen.model)?.busNum ?? ""
        property real brightness
        property bool ready: false
        property string _backendKey: ""
        property bool _initIsDdc: false
        property int _pendingPercent: -1
        property int _lastSentPercent: -1

        onBrightnessChanged: {
            if (monitor.ready) {
                root.brightnessChanged();
            }
        }

        function syncBackend(): void {
            const key = isDdc ? `ddc:${busNum}` : "backlight";
            if (_backendKey === key)
                return;
            _backendKey = key;
            initialize();
        }

        function initialize(): void {
            monitor.ready = false;
            monitor._lastSentPercent = -1;
            initProc.running = false;
            monitor._initIsDdc = monitor.isDdc;
            initProc.command = monitor.isDdc
                ? ["ddcutil", "-b", monitor.busNum, "getvcp", "10", "--brief"]
                : ["brightnessctl", "-m"];
            initProc.running = true;
        }

        readonly property Process initProc: Process {
            stdout: SplitParser {
                onRead: data => {
                    const trimmed = data.trim();
                    if (!trimmed)
                        return;
                    const parts = monitor._initIsDdc ? trimmed.split(/\s+/) : trimmed.split(",");
                    const current = parseInt(monitor._initIsDdc ? parts[3] : parts[2]);
                    const max = parseInt(parts[4]);
                    if (!isNaN(current) && !isNaN(max) && max > 0) {
                        if (monitor._pendingPercent < 0 && !monitor.setProc.running && monitor._lastSentPercent < 0)
                            monitor.brightness = current / max;
                        monitor.ready = true;
                    }
                }
            }
        }

        function setBrightness(value: real): void {
            value = Math.max(0.01, Math.min(1, value));
            const rounded = Math.round(value * 100);
            if (Math.round(brightness * 100) === rounded)
                return;
            brightness = value;
            _pendingPercent = rounded;
            _flushPendingBrightness();
        }

        // Coalesce rapid updates so at most one brightness-write process runs per monitor.
        function _flushPendingBrightness(): void {
            if (setProc.running || _pendingPercent < 0)
                return;
            const target = _pendingPercent;
            _pendingPercent = -1;
            if (target === _lastSentPercent)
                return;
            _lastSentPercent = target;
            setProc.command = isDdc
                ? ["ddcutil", "-b", busNum, "setvcp", "10", target.toString()]
                : ["brightnessctl", "s", `${target}%`, "--quiet"];
            setProc.running = true;
        }

        readonly property Process setProc: Process {
            onRunningChanged: {
                if (!running) {
                    monitor._flushPendingBrightness();
                }
            }
        }
    }

    Variants {
        id: monitorVariants
        model: Quickshell.screens

        BrightnessMonitor {
            required property var modelData
            screen: modelData
        }
    }

    IpcHandler {
        target: "brightness"

        function increment() {
            onPressed: root.increaseBrightness()
        }

        function decrement() {
            onPressed: root.decreaseBrightness()
        }
    }

    GlobalShortcut {
        name: "brightnessIncrease"
        description: qsTr("Increase brightness")
        onPressed: root.increaseBrightness()
    }

    GlobalShortcut {
        name: "brightnessDecrease"
        description: qsTr("Decrease brightness")
        onPressed: root.decreaseBrightness()
    }
}
