pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Portable session power actions: suspend, poweroff, reboot, hibernate.
//
// Real systemd's loginctl has never had these verbs (only systemctl does -
// confirmed against systemd's own src/login/loginctl.c); elogind is the one
// that added them as its own extension, and systemctl itself doesn't exist
// at all outside systemd. So the only thing both implementations expose
// identically is login1's own D-Bus Manager methods.
Singleton {
    id: root

    function _methodName(action) {
        switch (action) {
            case "suspend": return "Suspend"
            case "poweroff": return "PowerOff"
            case "reboot": return "Reboot"
            case "hibernate": return "Hibernate"
            default: return ""
        }
    }

    function run(action) {
        const method = root._methodName(action)
        if (method === "") return
        const cmd = "command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ] && exec systemctl " + action +
            " || exec dbus-send --system --print-reply --dest=org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager." + method + " boolean:true"
        Quickshell.execDetached(["sh", "-c", cmd])
    }

    function suspend() { root.run("suspend") }
    function poweroff() { root.run("poweroff") }
    function reboot() { root.run("reboot") }
    function hibernate() { root.run("hibernate") }

    // Lets non-QML processes (hypridle, wlogout) trigger the same portable
    // logic, the same way GlobalStates.qml exposes "lock" for hypridle's
    // own lock_cmd - qs -p /usr/share/sleex ipc call powerAction poweroff
    IpcHandler {
        target: "powerAction"

        function suspend(): void { root.suspend() }
        function poweroff(): void { root.poweroff() }
        function reboot(): void { root.reboot() }
        function hibernate(): void { root.hibernate() }
    }
}
