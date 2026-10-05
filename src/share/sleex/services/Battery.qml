pragma Singleton

import qs
import qs.modules.common
import Quickshell
import Quickshell.Services.UPower
import QtQuick
import Quickshell.Io

Singleton {
    id: batteryService

    property bool available:     UPower.displayDevice.isLaptopBattery
    property var  chargeState:   UPower.displayDevice.state
    property bool isCharging:    chargeState === UPowerDeviceState.Charging || chargeState === UPowerDeviceState.PendingCharge
    property bool isDischarging: chargeState === UPowerDeviceState.Discharging
    property bool isPluggedIn:   isCharging || chargeState === UPowerDeviceState.FullyCharged

    property real percentage:          UPower.displayDevice.percentage
    readonly property int percentageInt: Math.round(batteryService.percentage * 100)

    property bool isLow:        percentage <= Config.options.battery.low      / 100
    property bool isCritical:   percentage <= Config.options.battery.critical / 100
    property bool isSuspending: percentage <= Config.options.battery.suspend  / 100

    property int warningThreshold:  Config.options.battery.low
    property int criticalThreshold: Config.options.battery.critical
    property int suspendThreshold:  Config.options.battery.suspend

    property bool isLowAndNotCharging:      isLow      && !isCharging
    property bool isCriticalAndNotCharging: isCritical && !isCharging

    property bool criticalActionWanted: available && Config.options.battery.criticalActionEnabled
        && isCriticalAndNotCharging && !_criticalActionFired
    property real criticalActionProgress: 0
    property bool _criticalActionFired: false

    readonly property string criticalActionLabel: {
        switch (Config.options.battery.criticalAction) {
            case "hibernate": return qsTr("Hibernate")
            case "shutdown":  return qsTr("Shut down")
            case "lock":      return qsTr("Lock screen")
            default:          return qsTr("Suspend")
        }
    }

    onIsCriticalChanged: {
        if (!isCritical) _criticalActionFired = false
    }

    onCriticalActionWantedChanged: {
        if (criticalActionWanted) {
            criticalActionProgress = 0
            criticalActionAnim.restart()
        } else {
            criticalActionAnim.stop()
            criticalActionProgress = 0
        }
    }

    NumberAnimation {
        id: criticalActionAnim
        target: batteryService
        property: "criticalActionProgress"
        from: 0
        to: 1
        duration: Config.options.battery.criticalActionDelay * 1000
        easing.type: Easing.Linear
        onFinished: {
            if (batteryService.criticalActionWanted)
                batteryService.runCriticalAction()
        }
    }

    signal criticalActionExecuted()

    function runCriticalAction() {
        _criticalActionFired = true
        criticalActionExecuted()
        const action = Config.options.battery.criticalAction
        if (action === "lock") {
            GlobalStates.screenLocked = true
        } else if (action === "shutdown") {
            PowerActions.poweroff()
        } else if (action === "hibernate") {
            PowerActions.hibernate()
        } else {
            PowerActions.suspend()
        }
    }

    property real energyRate:  UPower.displayDevice.changeRate
    property real timeToFull:  UPower.displayDevice.timeToFull

    readonly property int remainingTime: {
        const seconds = UPower.displayDevice.timeToFull
        return (seconds > 0 && isFinite(seconds)) ? Math.floor(seconds / 60) : 0
    }
    readonly property int timeToEmpty: UPower.displayDevice.timeToEmpty

    property bool _wasFull: false

    onIsPluggedInChanged: {
        if (!available) return
        if (isPluggedIn) {
            if (Config.options.battery.sound)
                Audio.playSound("assets/sounds/battery/02_plug.wav")
        } else {
            if (Config.options.battery.sound)
                Audio.playSound("assets/sounds/battery/02_unplug.wav")
        }
    }

    onIsDischargingChanged: {
        if (isDischarging) _wasFull = false
    }

    onPercentageChanged: {
        if (!available) return
        if (isPluggedIn) {
            if (batteryService.percentageInt >= 100 && !_wasFull) {
                _wasFull = true
                if (Config.options.battery.sound)
                    Audio.playSound("assets/sounds/battery/01_full.wav")
                sendNotification("Battery Full", "The battery is fully charged.")
            }
            if (batteryService.percentageInt < 100) _wasFull = false
        }
    }

    onIsCriticalAndNotChargingChanged: {
        if (!available) return
        if (isCriticalAndNotCharging && !Config.options.battery.overlayEnabled) {
            if (Config.options.battery.sound)
                Audio.playSound("assets/sounds/battery/05_critical.wav")
            sendNotification("Critical Battery Level",
                `Power level has reached ${batteryService.percentageInt}%. Please connect your charger immediately.`)
        }
    }

    onIsLowAndNotChargingChanged: {
        if (!available) return
        // Only fire for low (not critical) to avoid double notification
        if (isLowAndNotCharging && !isCriticalAndNotCharging && !Config.options.battery.overlayEnabled) {
            if (Config.options.battery.sound)
                Audio.playSound("assets/sounds/battery/04_warn.wav")
            sendNotification("Low Battery Warning",
                `Power level has dropped to ${batteryService.percentageInt}%. Consider connecting your charger.`)
        }
    }

    function sendNotification(title, body) {
        Quickshell.execDetached(["notify-send", title, body, "-u", "critical", "-a", "System"])
    }
}
