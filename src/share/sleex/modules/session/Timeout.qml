import QtQuick
import Quickshell
import qs.modules.common

Item {
    id: timeoutService
    
    property int illuminanceTimeout: Config.options.timeout.illuminance
    property int lockTimeout: Config.options.timeout.lock
    property int standbyTimeout: Config.options.timeout.standby
    property int suspendTimeout: Config.options.timeout.suspend

    function executeIlluminanceAction() {
        Quickshell.execDetached(["brightnessctl", "-s", "set", "10"])
        Quickshell.execDetached(["/bin/bash", "/usr/share/sleex/scripts/illuminance.sh"])
    }

    function executeLockAction() {
        Quickshell.execDetached(["qs", "-p", "/usr/share/sleex", "ipc", "call", "lock", "lock"])
    }
    
    function executeStandbyAction() {
        Quickshell.execDetached(["hyprctl", "dispatch", "dpms", "off"])
    }

    function executeSuspendAction() {
        Quickshell.execDetached(["systemctl", "suspend"])
    }

    Timer {
        id: illuminanceTimer
        interval: timeoutService.illuminanceTimeout
        repeat: false
        running: false
        onTriggered: {
            executeIlluminanceAction()
        }
    }

    Timer {
        id: lockTimer
        interval: timeoutService.lockTimeout
        repeat: false
        running: false
        onTriggered: {
            executeLockAction()
        }
    }

    Timer {
        id: suspendTimer
        interval: timeoutService.suspendTimeout
        repeat: false
        running: false
        onTriggered: {
            executeSuspendAction()
        }
    }

    Timer {
        id: standbyTimer
        interval: timeoutService.standbyTimeout
        repeat: false
        running: false
        onTriggered: {
            executeStandbyAction()
        }
    }

    Component.onCompleted: {
        illuminanceTimer.start()
        lockTimer.start()
        suspendTimer.start()
        standbyTimer.start()
    }
}
