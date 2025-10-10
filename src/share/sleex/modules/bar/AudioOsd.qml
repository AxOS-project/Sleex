import Quickshell
import Quickshell.Hyprland
import QtQuick.Layouts
import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Revealer {
    id: root
    reveal: showOsdValues

    property bool showOsdValues: false

    function triggerOsd() {
        showOsdValues = true
        osdTimeout.restart()
    }

    Connections { // Listen to volume changes
        target: Audio.sink?.audio ?? null
        function onVolumeChanged() {
            if (!Audio.ready) return
            root.triggerOsd()
        }
        function onMutedChanged() {
            if (!Audio.ready) return
            root.triggerOsd()
        }
    }

    Connections { // Listen to protection triggers
        target: Audio
        function onSinkProtectionTriggered(reason) {
            root.protectionMessage = reason;
            root.triggerOsd()
        }
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

    RowLayout {
        
        BarGroupR {
            id: brightnessOsd
            padding: 10

            MaterialSymbol {
                text: "volume_up" 
                iconSize: Appearance.font.pixelSize.normal
            }

            Item {
                implicitWidth: 5
            }

            StyledProgressBar {
                value: Audio.sink?.audio.volume ?? 0
            }        
        }
    }
}
