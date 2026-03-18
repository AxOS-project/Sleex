pragma Singleton
import QtQuick
import qs.modules.common
import Quickshell
import Quickshell.Io

/**
 * Simple hyprsunset service with automatic mode.
 * In theory we don't need this because hyprsunset has a config file, but it somehow doesn't work.
 * It should also be possible to control it via hyprctl, but it doesn't work consistently either so we're just killing and launching.
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
        if (root.active)
            Quickshell.execDetached(["hyprctl", "hyprsunset", "temperature", String(colorTemperature)]);
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
            `pidof hyprsunset || hyprsunset --temperature ${root.colorTemperature}`]);
    }

    function disable() {
        root.active = false;
        Quickshell.execDetached(["bash", "-c", "pkill hyprsunset"]);
    }

    function fetchState() {
        fetchProc.running = true;
    }

    Process {
        id: fetchProc
        running: true
        command: ["bash", "-c", "hyprctl hyprsunset temperature"]
        stdout: StdioCollector {
            id: stateCollector
            onStreamFinished: {
                const output = stateCollector.text.trim();
                if (output.length == 0 || output.startsWith("Couldn't"))
                    root.active = false;
                else
                    root.active = (output != "6500");
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
