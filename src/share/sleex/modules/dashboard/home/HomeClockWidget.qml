import qs.modules.common
import qs.services
import QtQuick
import SleexUiKit.Widgets
import SleexUiKit.Appearance

Rectangle {
    color: Appearance.colors.colLayer1
    radius: Appearance.rounding.normal
    clip: true

    Column {
        anchors.centerIn: parent
        spacing: 10

        StyledText {
            text: DateTime.time
            color: Appearance.colors.colPrimary
            font.pixelSize: 60
            font.bold: true
            anchors.horizontalCenter: parent.horizontalCenter
        }

        StyledText {
            text: DateTime.longDateFormat
            color: Appearance.colors.colOnLayer1
            font.pixelSize: 20
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
