import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import Quickshell.Widgets
import Sleex.Widgets

Rectangle {
    id: root
    color: Appearance.colors.colLayer1
    radius: Appearance.rounding.normal

    Column {
        anchors.centerIn: parent
        spacing: 10
        width: parent.width * 0.9

        Rectangle {
            id: userAvatar
            width: 120
            height: 120
            radius: 99
            anchors.horizontalCenter: parent.horizontalCenter
            color: Appearance.colors.colLayer2

            ClippingRectangle {
                width: 120; height: 120
                radius: 60
                color: "transparent"
                Image {
                    anchors.fill: parent
                    source: Config.options.dashboard.avatarPath
                    fillMode: Image.PreserveAspectCrop
                }
            }
        }

        Text {
            text: qsTr("Welcome, %1!").arg(SystemInfo.username)
            color: Appearance.colors.colOnLayer1
            font.pixelSize: 30
            font.bold: true
            anchors.horizontalCenter: parent.horizontalCenter
        }
        StyledText {
            text: Config.options.dashboard.userDesc
            color: Appearance.colors.colOnLayer1
            font.pixelSize: 20
            width: parent.width
            wrapMode: Text.WordWrap
            horizontalAlignment: Qt.AlignHCenter
        }
    }
}
