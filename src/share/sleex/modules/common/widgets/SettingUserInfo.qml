import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.modules.common
import qs.services

Rectangle {
    id: userInfoWidget
    color: Appearance.colors.colLayer2
    radius: Appearance.rounding.normal
    Layout.fillWidth: true
    Layout.preferredHeight: 100

    RowLayout {
        anchors.centerIn: parent
        width: parent.width * 0.9
    
        Rectangle {
            id: userAvatar
            width: 64
            height: 64
            radius: 99
            color: Appearance.colors.colLayer2

            ClippingRectangle {
                width: 64
                height: 64
                radius: 32
                color: "transparent"
                Image {
                    anchors.fill: parent
                    source: Config.options.dashboard.avatarPath
                    fillMode: Image.PreserveAspectCrop
                }
            }
        }

        ColumnLayout {
            spacing: 4

            StyledText {
                text: SystemInfo.username
                font.pixelSize: Appearance.font.pixelSize.title
                color: Appearance.colors.colOnLayer0
            }

            StyledText {
                text: "Uptime: " + DateTime.uptime
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnLayer0
                opacity: 0.6
            }
        }
    }
}