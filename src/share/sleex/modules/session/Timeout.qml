import QtQuick
import Quickshell
import qs.modules.common

Item {
    id: timeoutService
    width: 1
    height: 1

    // Idle timeout in milliseconds
    property int idleTime: Config.options.timeout.illuminance

    Timer {
        id: idleTimer
        interval: timeoutService.idleTime
        repeat: true
        running: true
        onTriggered: {
            Quickshell.execDetached(["brightnessctl", "-s", "set", "10"])
        }
    }
}
