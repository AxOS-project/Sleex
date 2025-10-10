import Quickshell
import Quickshell.Hyprland
import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Revealer {
    id: root
    reveal: showOsdValues

    property bool showOsdValues: false
    property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
    property var brightnessMonitor: Brightness.getMonitorForScreen(focusedScreen)

    Connections {
        target: Brightness
        function onBrightnessChanged() {
            if (!root.brightnessMonitor.ready) return
            root.triggerOsd()
        }
    }

    function triggerOsd() {
        showOsdValues = true
        osdTimeout.restart()
    }

    Timer {
        id: osdTimeout
        interval: Config.options.osd.timeout
        repeat: false
        running: false
        onTriggered: {
            showOsdValues = false
        }
    }

    BarGroupR {
        id: brightnessOsd
        padding: 10

        StyledProgressBar {
            value: root.brightnessMonitor?.brightness ?? 0.5
        }

        Item {
            implicitWidth: 5
        }

        MaterialSymbol {
            text: "clear_day"
            iconSize: Appearance.font.pixelSize.normal
        }
    }
}
