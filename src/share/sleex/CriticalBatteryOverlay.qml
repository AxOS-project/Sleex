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
            exclusiveZone: 0
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell:criticalaction"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region { }

            Shape {
                id: trackShape
                anchors.fill: parent
                visible: Battery.criticalActionWanted
                antialiasing: true

                layer.enabled: Battery.criticalActionWanted
                layer.smooth: true
                layer.samples: 2
                opacity: 0.15
                ShapePath {
                    strokeWidth: root.borderThick
                    strokeColor: Appearance.colors.colPrimary
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathMove { x: win.width / 2; y: root.pathInset }
                    PathLine { x: win.width - root.pathInset - root.cornerRadius; y: root.pathInset }
                    PathArc { x: win.width - root.pathInset; y: root.pathInset + root.cornerRadius; radiusX: root.cornerRadius; radiusY: root.cornerRadius; direction: PathArc.Clockwise }
                    PathLine { x: win.width - root.pathInset; y: win.height - root.pathInset - root.cornerRadius }
                    PathArc { x: win.width - root.pathInset - root.cornerRadius; y: win.height - root.pathInset; radiusX: root.cornerRadius; radiusY: root.cornerRadius; direction: PathArc.Clockwise }
                    PathLine { x: root.pathInset + root.cornerRadius; y: win.height - root.pathInset }
                    PathArc { x: root.pathInset; y: win.height - root.pathInset - root.cornerRadius; radiusX: root.cornerRadius; radiusY: root.cornerRadius; direction: PathArc.Clockwise }
                    PathLine { x: root.pathInset; y: root.pathInset + root.cornerRadius }
                    PathArc { x: root.pathInset + root.cornerRadius; y: root.pathInset; radiusX: root.cornerRadius; radiusY: root.cornerRadius; direction: PathArc.Clockwise }
                    PathLine { x: win.width / 2; y: root.pathInset }
                }
            }
            Shape {
                id: snakeShape
                anchors.fill: parent
                visible: Battery.criticalActionWanted
                antialiasing: true

                layer.enabled: Battery.criticalActionWanted
                layer.smooth: true
                layer.samples: 2
                ShapePath {
                    strokeWidth: root.borderThick
                    strokeColor: Appearance.colors.colPrimary
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap

                    trim.start: 0
                    trim.end: Math.max(win.prog, 0.002)
                    PathMove { x: win.width / 2; y: root.pathInset }
                    PathLine { x: win.width - root.pathInset - root.cornerRadius; y: root.pathInset }
                    PathArc { x: win.width - root.pathInset; y: root.pathInset + root.cornerRadius; radiusX: root.cornerRadius; radiusY: root.cornerRadius; direction: PathArc.Clockwise }
                    PathLine { x: win.width - root.pathInset; y: win.height - root.pathInset - root.cornerRadius }
                    PathArc { x: win.width - root.pathInset - root.cornerRadius; y: win.height - root.pathInset; radiusX: root.cornerRadius; radiusY: root.cornerRadius; direction: PathArc.Clockwise }
                    PathLine { x: root.pathInset + root.cornerRadius; y: win.height - root.pathInset }
                    PathArc { x: root.pathInset; y: win.height - root.pathInset - root.cornerRadius; radiusX: root.cornerRadius; radiusY: root.cornerRadius; direction: PathArc.Clockwise }
                    PathLine { x: root.pathInset; y: root.pathInset + root.cornerRadius }
                    PathArc { x: root.pathInset + root.cornerRadius; y: root.pathInset; radiusX: root.cornerRadius; radiusY: root.cornerRadius; direction: PathArc.Clockwise }
                    PathLine { x: win.width / 2; y: root.pathInset }
                }
            }
        }
    }

}
