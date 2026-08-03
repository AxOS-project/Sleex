import qs.modules.common
import qs.services
import SleexUiKit.Widgets
import SleexUiKit.Appearance
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    implicitWidth: 140
    implicitHeight: 140
    Layout.alignment: Qt.AlignVCenter

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 2

        StyledText {
            text: Stopwatch.formattedTime
            font.pixelSize: 30
            font.weight: Font.Bold
            color: Appearance.colors.colOnLayer1
            Layout.alignment: Qt.AlignHCenter
        }

        StyledText {
            text: Stopwatch.running ? "Running" : Stopwatch.elapsedTime > 0 ? "Paused" : "Ready"
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnLayer2
            opacity: 0.8
            Layout.alignment: Qt.AlignHCenter
        }

    }
}
