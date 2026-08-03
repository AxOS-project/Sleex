import qs.modules.common
import SleexUiKit.Widgets
import SleexUiKit.Appearance
import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: root

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: popupWindow
            required property var modelData
            screen: modelData

            property int cardWidth: 500
            property int cardHeight: 300
            property int cornerSize: Appearance.rounding.screenRounding ?? 20
            property int triggerWidth: 20
            property int triggerHeight: 20

            property bool revealed: containerArea.containsMouse

            anchors {
                bottom: true
                left: true
            }

            WlrLayershell.namespace: "quickshell:cornerPopup"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            implicitWidth: cardWidth + cornerSize + Appearance.sizes.elevationMargin * 2
            implicitHeight: cardHeight + cornerSize + Appearance.sizes.elevationMargin * 2

            mask: Region {
                item: containerArea
            }

            MouseArea {
                id: containerArea
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                hoverEnabled: true

                width: popupWindow.revealed ? (popupWindow.cardWidth + popupWindow.cornerSize) : popupWindow.triggerWidth
                height: popupWindow.revealed ? (popupWindow.cardHeight + popupWindow.cornerSize) : popupWindow.triggerHeight

                Behavior on width {
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Appearance.animation.elementMoveFast.type
                    }
                }

                Behavior on height {
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Appearance.animation.elementMoveFast.type
                    }
                }

                Item {
                    anchors.centerIn: parent
                    width: 24
                    height: 24
                    visible: !popupWindow.revealed
                    opacity: popupWindow.revealed ? 0 : 0.5

                    Behavior on opacity {
                        NumberAnimation { duration: 150 }
                    }

                    // MaterialSymbol {
                    //     anchors.centerIn: parent
                    //     text: "widgets"
                    //     iconSize: 20
                    //     color: Appearance.colors.colPrimary
                    // }
                }

                CornerPopupContent {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    cardWidth: popupWindow.cardWidth
                    cardHeight: popupWindow.cardHeight
                    cornerSize: popupWindow.cornerSize
                    opacity: popupWindow.revealed ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                        }
                    }
                }
            }
        }
    }
}
