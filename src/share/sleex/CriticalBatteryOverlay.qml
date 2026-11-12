import qs
import qs.modules.common
import qs.services
import SleexUiKit.Appearance
import QtQuick
import Quickshell
import Quickshell.Wayland
import QtQuick.Shapes

Scope {
    id: root

    property int borderThick: Config.options.battery.criticalOverlayBorderThick ?? 14
    property int pathInset: Config.options.battery.criticalOverlayPathInset ?? 0
    property int cornerRadius: Config.options.battery.criticalOverlayCornerRadius ?? 20

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            readonly property real prog: Battery.criticalActionProgress

            visible: Battery.criticalActionWanted
            color: "transparent"

            anchors { top: true; bottom: true; left: true; right: true }
            exclusiveZone: -1
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell:criticalaction"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region { }

            readonly property real halfThick: root.borderThick / 2
            readonly property real radius:    root.cornerRadius
            readonly property real lineLeft:   root.pathInset + halfThick
            readonly property real lineTop:    root.pathInset + halfThick
            readonly property real lineRight:  win.width - root.pathInset - halfThick
            readonly property real lineBottom: win.height - root.pathInset - halfThick

            component EdgePath: ShapePath {
                strokeWidth: root.borderThick
                strokeColor: Appearance.colors.colPrimary
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.MiterJoin

                PathMove { x: win.width / 2; y: win.lineTop }
                PathLine { x: win.lineRight - win.radius; y: win.lineTop }
                PathAngleArc {
                    centerX: win.lineRight - win.radius
                    centerY: win.lineTop + win.radius
                    radiusX: win.radius
                    radiusY: win.radius
                    startAngle: -90
                    sweepAngle: 90
                }
                PathLine { x: win.lineRight; y: win.lineBottom - win.radius }
                PathAngleArc {
                    centerX: win.lineRight - win.radius
                    centerY: win.lineBottom - win.radius
                    radiusX: win.radius
                    radiusY: win.radius
                    startAngle: 0
                    sweepAngle: 90
                }
                PathLine { x: win.lineLeft + win.radius; y: win.lineBottom }
                PathAngleArc {
                    centerX: win.lineLeft + win.radius
                    centerY: win.lineBottom - win.radius
                    radiusX: win.radius
                    radiusY: win.radius
                    startAngle: 90
                    sweepAngle: 90
                }
                PathLine { x: win.lineLeft; y: win.lineTop + win.radius }
                PathAngleArc {
                    centerX: win.lineLeft + win.radius
                    centerY: win.lineTop + win.radius
                    radiusX: win.radius
                    radiusY: win.radius
                    startAngle: 180
                    sweepAngle: 90
                }
                PathLine { x: win.width / 2; y: win.lineTop }
            }

            Shape {
                id: trackShape
                anchors.fill: parent
                visible: Battery.criticalActionWanted
                antialiasing: true

                layer.enabled: Battery.criticalActionWanted
                layer.smooth: true
                layer.samples: 2
                opacity: 0.15
                EdgePath { }
            }
            Shape {
                id: snakeShape
                anchors.fill: parent
                visible: Battery.criticalActionWanted
                antialiasing: true

                layer.enabled: Battery.criticalActionWanted
                layer.smooth: true
                layer.samples: 2
                EdgePath {
                    trim.start: 0
                    trim.end: Math.max(win.prog, 0.002)
                }
            }
        }
    }

}
