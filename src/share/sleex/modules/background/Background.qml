pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root
    readonly property bool fixedClockPosition: Config.options.background.fixedClockPosition
    readonly property real fixedClockX: Config.options.background.clockX
    readonly property real fixedClockY: Config.options.background.clockY

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: bgRoot
            required property var modelData
            property string wallpaperPath: Config.options.background.wallpaperPath

            property real clockX: Config.options.background.clockX !== 0 ? Config.options.background.clockX : modelData.width / 2
            property real clockY: Config.options.background.clockY !== 0 ? Config.options.background.clockY : modelData.height / 2
            property var textHorizontalAlignment: clockX < screen.width / 3 ? Text.AlignLeft :
                (clockX > screen.width * 2 / 3 ? Text.AlignRight : Text.AlignHCenter)

            property color dominantColor: Appearance.colors.colPrimary
            property bool dominantColorIsDark: dominantColor.hslLightness < 0.5
            property color colText: Config.options.background.clockMode == "light" ? Appearance.colors.colPrimary : ColorUtils.colorWithLightness(Appearance.colors.colPrimary, 0.12)

            screen: modelData
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "quickshell:background"
            exclusionMode: ExclusionMode.Ignore
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "transparent"

            Clock {
                id: clock
                z: 1
                screenWidth: bgRoot.screen.width
                screenHeight: bgRoot.screen.height
                clockX: bgRoot.clockX
                clockY: bgRoot.clockY
                clockSizeMultiplier: Config.options.background.clockSizeMultiplier
                fixedClockPosition: root.fixedClockPosition
                textColor: bgRoot.colText
                textHorizontalAlignment: bgRoot.textHorizontalAlignment

                onClockPositionChanged: function(newX, newY) {
                    bgRoot.clockX = newX
                    bgRoot.clockY = newY
                }

                onFixedPositionToggled: {
                    Config.options.background.fixedClockPosition = !root.fixedClockPosition
                }
            }

            Watermark {
                visibleWatermark: Config.options.background.showWatermark
            }
        }
    }
}
