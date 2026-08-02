import qs.modules.common
import qs.modules.common.widgets
import SleexUiKit.Widgets
import SleexUiKit.Appearance
import qs.services
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

Item {
    id: root

    Rectangle {
        color: Appearance.colors.colLayer1
        radius: Appearance.rounding.normal
        anchors.fill: parent

        NotificationListView { // Scrollable window
            id: listview
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: statusRow.top
            anchors.bottomMargin: 5
            anchors.margins: 10

            clip: true
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: listview.width
                    height: listview.height
                    radius: Appearance.rounding.normal
                }
            }

            popup: false

        }

        // Placeholder when list is empty
        Item {
            anchors.fill: listview

            visible: opacity > 0
            opacity: (Notifications.list.length === 0) ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.animation.menuDecel.duration
                    easing.type: Appearance.animation.menuDecel.type
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 5

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    iconSize: 55
                    color: Appearance.m3colors.m3outline
                    text: "notifications_active"
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.m3colors.m3outline
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("No notifications")
                }
            }
        }

        Item {
            id: statusRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 10

            Layout.fillWidth: true
            implicitHeight: Math.max(
                controls.implicitHeight,
                statusText.implicitHeight
            )

            StyledText {
                id: statusText
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 10
                horizontalAlignment: Text.AlignHCenter
                text: `${Notifications.list.length} notifications`

                opacity: Notifications.list.length > 0 ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                }
            }

            ButtonGroup {
                id: controls
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 5

                NotificationStatusButton {
                    buttonIcon: "notifications_paused"
                    buttonText: qsTr("Silent")
                    toggled: Notifications.silent
                    onClicked: () => {
                        Notifications.silent = !Notifications.silent;
                    }
                }
                NotificationStatusButton {
                    buttonIcon: "clear_all"
                    buttonText: qsTr("Clear")
                    onClicked: () => {
                        Notifications.discardAllNotifications()
                    }
                }
            }
        }
    }
}