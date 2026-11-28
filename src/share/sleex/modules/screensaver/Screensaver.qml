pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

Scope {
    id: root

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:screensaver"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: "#000000"
            visible: GlobalStates.screensaverActive

            function dismiss() {
                GlobalStates.screensaverActive = false;
            }

            FocusScope {
                id: keyScope
                anchors.fill: parent
                focus: true

                Component.onCompleted: keyScope.forceActiveFocus()

                Keys.onPressed: (event) => {
                    event.accepted = true;
                    win.dismiss();
                }

                ScreensaverBackground {
                    anchors.fill: parent
                    active: GlobalStates.screensaverActive
                    clusterCenterX: cluster.centerX
                    clusterCenterY: cluster.centerY
                    accentColor: cluster.activeAccentColor
                }

                ScreensaverCluster {
                    id: cluster
                    screenWidth: win.width
                    screenHeight: win.height
                }

                MouseArea {
                    id: dismissArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.AllButtons
                    cursorShape: Qt.BlankCursor

                    property bool armed: false
                    property bool hasInitialPos: false
                    property real initialX: 0
                    property real initialY: 0

                    Timer {
                        interval: 250
                        running: GlobalStates.screensaverActive
                        repeat: false
                        onTriggered: dismissArea.armed = true
                    }

                    onPressed: (mouse) => {
                        mouse.accepted = true;
                        win.dismiss();
                    }

                    onWheel: (wheel) => {
                        wheel.accepted = true;
                        win.dismiss();
                    }

                    onPositionChanged: (mouse) => {
                        if (!armed) return;
                        if (!hasInitialPos) {
                            initialX = mouse.x;
                            initialY = mouse.y;
                            hasInitialPos = true;
                            return;
                        }
                        if (Math.hypot(mouse.x - initialX, mouse.y - initialY) > 2) {
                            win.dismiss();
                        }
                    }
                }
            }
        }
    }
}
