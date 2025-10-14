import qs.modules.common
import qs.modules.common.widgets
import "../"
import Quickshell.Io
import Quickshell
import Quickshell.Hyprland

QuickToggleButton {
    id: root
    toggled: false
    buttonIcon: "coffee"
    onClicked: {
        if (toggled) {
            root.toggled = false
            Quickshell.execDetached(["exec", "pkill", "wayland-idle"])
        } else {
            root.toggled = true
            Quickshell.execDetached(["python", "/usr/share/sleex/scripts/wayland-idle-inhibitor.py"])
        }
    }
    Process {
        id: fetchActiveState
        running: true
        command: ["bash", "-c", "pidof wayland-idle-inhibitor.py"]
        onExited: (exitCode, exitStatus) => {
            root.toggled = exitCode === 0
        }
    }
    StyledToolTip {
        text: qsTr("Keep system awake")
    }
}
