pragma Singleton
import QtQuick
import qs.modules.common
import Quickshell
import Quickshell.Io

/**
 * Simple gammastep night light service with automatic schedule mode.
 */
Singleton {
    id: root
    property bool ready: false
    property var manualActive
    property string from: Config.options.display.nightLightFrom
    property string to: Config.options.display.nightLightTo
    property bool automatic: Config.options.display.nightLightAuto && (Config?.ready ?? true)
    property int colorTemperature: Config.options.display.nightLightTemperature
    property bool shouldBeOn
    property bool active: false
    property int fromHour:   Number(from.split(":")[0])
    property int fromMinute: Number(from.split(":")[1])
    property int toHour:     Number(to.split(":")[0])
    property int toMinute:   Number(to.split(":")[1])
    property int clockHour:   DateTime.clock.hours
    property int clockMinute: DateTime.clock.minutes

    Component.onCompleted: {
        ready = true;
        reEvaluate();
        if (!root.automatic && !root.active && Config.options.display.nightLightEnabled)
            root.enable();
    }

    onClockMinuteChanged: {
        if (ready) reEvaluate();
    }

    onFromChanged: {
        if (!ready) return;
        root.manualActive = undefined;
        reEvaluate();
    }
    onToChanged: {
        if (!ready) return;
        root.manualActive = undefined;
        reEvaluate();
    }
    onAutomaticChanged: {
        if (!ready) return;
        root.manualActive = undefined;
        reEvaluate();
    }

    onColorTemperatureChanged: {
        if (root.active) {
            Quickshell.execDetached(["bash", "-c", `pkill gammastep; gammastep -O ${root.colorTemperature}`]);
        }
    }

    function reEvaluate() {
        const t = clockHour * 60 + clockMinute;
        const f = fromHour  * 60 + fromMinute;
        const e = toHour    * 60 + toMinute;
        root.shouldBeOn = (f < e) ? (t >= f && t < e) : (t >= f || t < e);
        root.ensureState();
    }

    function ensureState() {
        if (!root.automatic || root.manualActive !== undefined) return;
        if (root.shouldBeOn) root.enable(); else root.disable();
    }

    function load() { }

    function enable() {
        root.active = true;
        Quickshell.execDetached(["bash", "-c",
            `pidof gammastep || gammastep -O ${root.colorTemperature}`]);
    }

    function disable() {
        root.active = false;
        Quickshell.execDetached(["pkill", "gammastep"]);
    }

    function fetchState() {
        fetchProc.running = true;
    }

    Process {
        id: fetchProc
        running: true
        command: ["bash", "-c", "pidof gammastep"]
        stdout: StdioCollector {
            id: stateCollector
            onStreamFinished: {
                const output = stateCollector.text.trim();
                root.active = (output.length > 0 && !output.startsWith("Couldn't"));
            }
        }
    }

    function toggle() {
        if (root.manualActive === undefined)
            root.manualActive = root.active;
        root.manualActive = !root.manualActive;
        if (root.manualActive) root.enable(); else root.disable();
    }
}
