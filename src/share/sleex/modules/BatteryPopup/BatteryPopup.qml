import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    property bool isCritical: false

    component Divider: Rectangle {
        Layout.fillWidth: true
        height:  1
        color:   Appearance.colors.colOutlineVariant
        opacity: 0.5
    }

    component CardButton: Item {
        id: btn
        required property string label
        required property bool bold
        property bool roundBottom: false
        property color hoverColor: Appearance.colors.colLayer2Hover
        property real hoverProgress: area.containsMouse ? 1 : 0
        signal clicked()

        Layout.fillWidth: true
        implicitHeight:   54
        Behavior on hoverProgress {
            NumberAnimation {
                duration:           Appearance.animation.elementMoveFast.duration
                easing.type:        Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        Canvas {
            id: hoverCanvas
            anchors.fill: parent
            antialiasing: true

            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()

                if (btn.hoverProgress <= 0)
                    return

                const w = width
                const h = height
                const r = btn.roundBottom ? Math.min(Appearance.rounding.verylarge, w / 2, h) : 0

                ctx.globalAlpha = btn.hoverProgress
                ctx.fillStyle = btn.hoverColor

                if (r > 0) {
                    ctx.beginPath()
                    ctx.moveTo(0, 0)
                    ctx.lineTo(w, 0)
                    ctx.lineTo(w, h - r)
                    ctx.quadraticCurveTo(w, h, w - r, h)
                    ctx.lineTo(r, h)
                    ctx.quadraticCurveTo(0, h, 0, h - r)
                    ctx.closePath()
                    ctx.fill()
                } else {
                    ctx.fillRect(0, 0, w, h)
                }
            }
        }

        onHoverProgressChanged: hoverCanvas.requestPaint()
        onRoundBottomChanged: hoverCanvas.requestPaint()
        onHoverColorChanged: hoverCanvas.requestPaint()

        StyledText {
            anchors.centerIn: parent
            text:             btn.label
            font.pixelSize:   Appearance.font.pixelSize.normal
            font.weight:      btn.bold ? Font.Medium : Font.Normal
            color:            Appearance.colors.colPrimary
        }

        MouseArea {
            id:           area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape:  Qt.PointingHandCursor
            onClicked:    btn.clicked()
        }
    }

    Connections {
        target: Battery

        function onIsLowAndNotChargingChanged() {
            if (!Config.options.battery.overlayEnabled) return
            if (Battery.isLowAndNotCharging) {
                root.isCritical = Battery.isCriticalAndNotCharging
                overlayLoader.active = false
                overlayLoader.loading = true
                if (Config.options.battery.sound)
                    Audio.playSound(root.isCritical
                        ? "assets/sounds/battery/05_critical.wav"
                        : "assets/sounds/battery/04_warn.wav")
            } else {
                root.isCritical = false
                overlayLoader.active = false
            }
        }

        function onIsCriticalAndNotChargingChanged() {
            if (!Config.options.battery.overlayEnabled) return
            if (Battery.isCriticalAndNotCharging) {
                root.isCritical = true
                overlayLoader.active = false
                overlayLoader.loading = true
                if (Config.options.battery.sound)
                    Audio.playSound("assets/sounds/battery/05_critical.wav")
            }
        }
    }
    
    LazyLoader {
        id: overlayLoader

        PanelWindow {
            color: "transparent"

            anchors { top: true; bottom: true; left: true; right: true }

            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.layer:         WlrLayer.Overlay
            WlrLayershell.namespace:     "quickshell:batterywarning"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            Item {
                anchors.fill: parent
                focus: true

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        overlayLoader.active = false
                        event.accepted = true
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked:    overlayLoader.active = false
                }

                Item {
                    id: cardWrapper
                    anchors.centerIn: parent
                    width:  card.implicitWidth
                    height: card.implicitHeight

                    opacity: 0
                    scale:   0.85

                    ParallelAnimation {
                        running: true
                        NumberAnimation {
                            target:             cardWrapper
                            property:           "opacity"
                            from: 0; to: 1
                            duration:           Appearance.animation.elementMoveEnter.duration
                            easing.type:        Appearance.animation.elementMoveEnter.type
                            easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
                        }
                        NumberAnimation {
                            target:             cardWrapper
                            property:           "scale"
                            from: 0.85; to: 1.0
                            duration:           Appearance.animation.elementMoveEnter.duration
                            easing.type:        Appearance.animation.elementMoveEnter.type
                            easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
                        }
                    }

                    StyledRectangularShadow { target: card }

                    Rectangle {
                        id:             card
                        implicitWidth:  320
                        implicitHeight: cardColumn.implicitHeight
                        radius:         Appearance.rounding.verylarge
                        color:          Appearance.m3colors.m3surfaceContainerHigh
                        clip:           true

                        ColumnLayout {
                            id:      cardColumn
                            width:   parent.width
                            spacing: 0
                            ColumnLayout {
                                Layout.fillWidth:    true
                                Layout.topMargin:    32
                                Layout.bottomMargin: 28
                                Layout.leftMargin:   24
                                Layout.rightMargin:  24
                                spacing: 8

                                MaterialSymbol {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: Battery.percentageInt <= Battery.criticalThreshold
                                        ? "battery_very_low" : "battery_low"
                                    font.pixelSize: 52
                                    color: root.isCritical
                                        ? Appearance.colors.colError
                                        : Appearance.colors.colPrimary

                                    Behavior on color {
                                        ColorAnimation {
                                            duration:           Appearance.animation.elementMoveFast.duration
                                            easing.type:        Appearance.animation.elementMoveFast.type
                                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                        }
                                    }

                                    SequentialAnimation on opacity {
                                        running: root.isCritical
                                        loops:   Animation.Infinite
                                        NumberAnimation { to: 0.25; duration: 600; easing.type: Easing.InOutSine }
                                        NumberAnimation { to: 1.0;  duration: 600; easing.type: Easing.InOutSine }
                                    }
                                }

                                StyledText {
                                    Layout.fillWidth:    true
                                    horizontalAlignment: Text.AlignHCenter
                                    text:       root.isCritical ? qsTr("Critical Battery") : qsTr("Low Battery")
                                    font.pixelSize: Appearance.font.pixelSize.large
                                    font.weight: Font.Bold
                                    color:      Appearance.colors.colOnLayer2
                                }

                                StyledText {
                                    Layout.fillWidth:    true
                                    horizontalAlignment: Text.AlignHCenter
                                    text:  qsTr("%1% battery remaining.").arg(Battery.percentageInt)
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colOnLayer1
                                }
                            }

                            Divider {}

                            CardButton {
                                label: qsTr("Power Saver Mode")
                                bold:  true
                                onClicked: {
                                    Quickshell.execDetached(["powerprofilesctl", "set", "power-saver"])
                                    overlayLoader.active = false
                                }
                            }

                            Divider {}

                            CardButton {
                                label:     qsTr("Close")
                                bold:      false
                                roundBottom: true
                                onClicked: overlayLoader.active = false
                            }
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "battery"

        function onShowOverlay() {
            if (Config.options.battery.overlayEnabled) {
                root.isCritical = Battery.isCriticalAndNotCharging
                overlayLoader.active = false
                overlayLoader.loading = true
            }
        }
    }
}
