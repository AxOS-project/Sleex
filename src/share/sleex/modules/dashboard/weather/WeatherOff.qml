import QtQuick 
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Rectangle {
    id: weatherRoot
    anchors.horizontalCenterOffset: -2
    color: "transparent"

    Rectangle {
        id: card
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            anchors.fill: parent
            Text {
                text: "Weather disabled"
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.title
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }
            // Separator line
            Rectangle {
                width: parent.width
                height: 1
                color: Appearance.colors.colLayer2
                Layout.fillWidth: true
                Layout.topMargin: 2
                Layout.bottomMargin: 2
            }
            Text {
                text: "The weather service is disabled.\nEnable it in the policy page of the Sleex settings."
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.normal
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
        }
    }
}