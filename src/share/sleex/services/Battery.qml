pragma Singleton

import qs
import qs.modules.common
import Quickshell
import Quickshell.Services.UPower
import QtQuick
import Quickshell.Io

Singleton {
    id: batteryService

    property bool available: UPower.displayDevice.isLaptopBattery
    property var chargeState: UPower.displayDevice.state
    property bool isCharging: chargeState === UPowerDeviceState.Charging || chargeState === UPowerDeviceState.PendingCharge
    property bool isDischarging: chargeState === UPowerDeviceState.Discharging
    property bool isPluggedIn: isCharging || chargeState === UPowerDeviceState.FullyCharged
    property real percentage: UPower.displayDevice.percentage
    readonly property int percentageInt: Math.round(batteryService.percentage * 100)

    property bool isLow: percentage <= Config.options.battery.low / 100
    property bool isCritical: percentage <= Config.options.battery.critical / 100
    property bool isSuspending: percentage <= Config.options.battery.suspend / 100

    property int warningThreshold: Config.options.battery.low
    property int criticalThreshold: Config.options.battery.critical
    property int suspendThreshold: Config.options.battery.suspend

    property bool isLowAndNotCharging: isLow && !isCharging
    property bool isCriticalAndNotCharging: isCritical && !isCharging

    property real energyRate: UPower.displayDevice.changeRate
    property real timeToFull: UPower.displayDevice.timeToFull
    property real temperature: 0

    readonly property int remainingTime: {
        const seconds = UPower.displayDevice.timeToFull;
        return (seconds > 0 && isFinite(seconds)) ? Math.floor(seconds / 60) : 0;
    }
    readonly property int timeToEmpty: UPower.displayDevice.timeToEmpty

    property bool _wasLow: false
    property bool _wasCritical: false
    property bool _wasSuspendWarned: false
    property bool _wasFull: false

    onIsPluggedInChanged: {
        if (!available) return;
        if (isPluggedIn) {
            if (Config.options.battery.sound !== false) {
                Audio.playSound("assets/sounds/battery/02_plug.wav");
            }
            _wasLow = false;
            _wasCritical = false;
        } else {
            if (Config.options.battery.sound !== false) {
                Audio.playSound("assets/sounds/battery/02_unplug.wav");
            }
            checkBatteryState();
        }
    }

    onPercentageChanged: {
        if (!available) return;
        checkBatteryState();
    }

        // Rewritten for stateful, more intelligent notifications.
    function checkBatteryState() {
        if (isDischarging) {
            _wasFull = false;

            if (batteryService.percentageInt <= criticalThreshold && !_wasCritical) {
                _wasCritical = true;
                _wasLow = true;
                if (Config.options.battery.sound !== false) {
                    Audio.playSound("assets/sounds/battery/05_critical.wav");
                }
                sendNotification("Critical Battery Level", `Power level has reached ${batteryService.percentageInt}%. Please connect your charger immediately.`);
            }
            else if (batteryService.percentageInt <= warningThreshold && !_wasLow) {
                _wasLow = true;
                if (Config.options.battery.sound !== false) {
                    Audio.playSound("assets/sounds/battery/04_warn.wav");
                }
                sendNotification("Low Battery Warning", `Power level has dropped to ${batteryService.percentageInt}%. Consider connecting your charger.`);
            }
        }

        if (isPluggedIn) {
            if (batteryService.percentageInt > warningThreshold) _wasLow = false;
            if (batteryService.percentageInt > criticalThreshold) _wasCritical = false;

            if (batteryService.percentageInt >= 100 && !_wasFull) {
                _wasFull = true;
                if (Config.options.battery.sound !== false) {
                    Audio.playSound("assets/sounds/battery/01_full.wav");
                }
                sendNotification("Battery Full", "The battery is fully charged.");
            }
        }
    }

    function sendNotification(title, body) {
        Hyprland.dispatch(`exec notify-send "${title}" "${body}" -u critical -a "System"`);
    }

    Process {
        id: tempProcess
        command: ["bash", "-c", "cat /sys/class/thermal/thermal_zone0/temp"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text && text.trim() !== "") {
                    Battery.temperature = parseInt(text.trim()) / 1000
                } else {
                    Battery.temperature = 0
                }
            }
        }
    }

    Timer {
        interval: 3000
        repeat: true
        running: true
        onTriggered: {
            if (!tempProcess.running) {
                tempProcess.running = true
            }
        }
    }

    Component.onCompleted: {
        if (!tempProcess.running) {
            tempProcess.running = true;
        }
    }

}
