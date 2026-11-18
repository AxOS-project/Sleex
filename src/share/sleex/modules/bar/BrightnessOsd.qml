import QtQuick
import qs.modules.common
import SleexUiKit.Widgets
import SleexUiKit.Appearance

Revealer {
    id: root
    reveal: showOsdValues

    property bool showOsdValues: false
    required property var brightnessMonitor

    Connections {
        target: root.brightnessMonitor ?? null
        function onBrightnessChanged() {
            if (!root.brightnessMonitor?.ready) return
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
