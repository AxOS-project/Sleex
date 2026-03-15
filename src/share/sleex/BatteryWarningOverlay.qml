import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

Scope {
    id: root

    property bool isCritical: false

    Connections {
        target: Battery

        function onIsLowAndNotChargingChanged() {
            if (Battery.isLowAndNotCharging) {
                root.isCritical = Battery.isCriticalAndNotCharging
                overlayLoader.active = false
                overlayLoader.loading = true
                if (Config.options.battery.sound !== false) {
                    Audio.playSound(root.isCritical
                        ? "assets/sounds/battery/05_critical.wav"
                        : "assets/sounds/battery/04_warn.wav")
                }
            } else {
                root.isCritical = false
                overlayLoader.active = false
            }
        }

        function onIsCriticalAndNotChargingChanged() {
            if (Battery.isCriticalAndNotCharging) {
                root.isCritical = true
                overlayLoader.active = false
                overlayLoader.loading = true
                if (Config.options.battery.sound !== false) {
                    Audio.playSound("assets/sounds/battery/05_critical.wav")
                }
            }
        }
    }

    LazyLoader {
        id: overlayLoader

        PanelWindow {
            id: popupWindow
            color: "transparent"

            // Cover the entire screen
            anchors.top:    true
            anchors.bottom: true
            anchors.left:   true
            anchors.right:  true

            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0

            WlrLayershell.layer:         WlrLayer.Overlay
            WlrLayershell.namespace:     "quickshell:batterywarning"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Rectangle {
                anchors.fill: parent
                color:        Appearance.m3colors.m3scrim
                opacity:      0.45

                NumberAnimation on opacity {
                    from: 0; to: 0.45
                    duration:           Appearance.animation.elementMoveEnter.duration
                    easing.type:        Appearance.animation.elementMoveEnter.type
                    easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
                }

                // Tap outside the card to dismiss
                MouseArea {
                    anchors.fill: parent
                    onClicked:    overlayLoader.active = false
                }
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
                        target: cardWrapper; property: "opacity"
                        from: 0; to: 1
                        duration:           Appearance.animation.elementMoveEnter.duration
                        easing.type:        Appearance.animation.elementMoveEnter.type
                        easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
                    }
                    NumberAnimation {
                        target: cardWrapper; property: "scale"
                        from: 0.85; to: 1.0
                        duration:           Appearance.animation.elementMoveEnter.duration
                        easing.type:        Appearance.animation.elementMoveEnter.type
                        easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
                    }
                }

                StyledRectangularShadow {
                    target: card
                }

                Rectangle {
                    id: card
                    implicitWidth:  320
                    implicitHeight: cardColumn.implicitHeight
                    radius:         Appearance.rounding.verylarge
                    color:          Appearance.m3colors.m3surfaceContainerHigh
                    clip:           true

                    ColumnLayout {
                        id: cardColumn
                        width: parent.width
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
                                    ? "battery_very_low"
                                    : "battery_low"
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
                                text:        root.isCritical ? qsTr("Critical Battery") : qsTr("Low Battery")
                                font.family: Appearance.font.family.main
                                font.pixelSize: Appearance.font.pixelSize.large
                                font.weight: Font.Bold
                                color:       Appearance.colors.colOnLayer2
                            }

                            StyledText {
                                Layout.fillWidth:    true
                                horizontalAlignment: Text.AlignHCenter
                                text:        qsTr("%1% battery remaining.").arg(Battery.percentageInt)
                                font.family: Appearance.font.family.main
                                font.pixelSize: Appearance.font.pixelSize.small
                                color:       Appearance.colors.colOnLayer1
                                wrapMode:    Text.WordWrap
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height:  1
                            color:   Appearance.colors.colOutlineVariant
                            opacity: 0.5
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight:   54
                            color: powerSaverHover.containsMouse
                                ? Appearance.colors.colLayer2Hover
                                : "transparent"

                            Behavior on color {
                                ColorAnimation {
                                    duration:           Appearance.animation.elementMoveFast.duration
                                    easing.type:        Appearance.animation.elementMoveFast.type
                                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                }
                            }

                            StyledText {
                                anchors.centerIn: parent
                                text:             qsTr("Power Saver Mode")
                                font.family:      Appearance.font.family.main
                                font.pixelSize:   Appearance.font.pixelSize.normal
                                font.weight:      Font.Medium
                                color:            Appearance.colors.colPrimary
                            }

                            MouseArea {
                                id:           powerSaverHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape:  Qt.PointingHandCursor
                                onClicked: {
                                    Quickshell.execDetached(["powerprofilesctl", "set", "power-saver"])
                                    overlayLoader.active = false
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height:  1
                            color:   Appearance.colors.colOutlineVariant
                            opacity: 0.5
                        }

                        Item {
                            Layout.fillWidth: true
                            implicitHeight:   54

                            Rectangle {
                                anchors.fill:        parent
                                anchors.topMargin:   -Appearance.rounding.verylarge
                                height:              parent.height + Appearance.rounding.verylarge
                                radius:              Appearance.rounding.verylarge
                                color: closeHover.containsMouse
                                    ? Appearance.colors.colLayer2Hover
                                    : "transparent"

                                Behavior on color {
                                    ColorAnimation {
                                        duration:           Appearance.animation.elementMoveFast.duration
                                        easing.type:        Appearance.animation.elementMoveFast.type
                                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                    }
                                }
                            }

                            StyledText {
                                anchors.centerIn: parent
                                text:             qsTr("Close")
                                font.family:      Appearance.font.family.main
                                font.pixelSize:   Appearance.font.pixelSize.normal
                                color:            Appearance.colors.colPrimary
                            }

                            MouseArea {
                                id:           closeHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape:  Qt.PointingHandCursor
                                onClicked:    overlayLoader.active = false
                            }
                        }
                    }
                }
            }
        }
    }
}
