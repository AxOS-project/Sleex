pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

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

    IpcHandler {
        target: "powerAction"

        function suspend(): void { root.suspend() }
        function poweroff(): void { root.poweroff() }
        function reboot(): void { root.reboot() }
        function hibernate(): void { root.hibernate() }
    }
}
