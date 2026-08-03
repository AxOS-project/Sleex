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

    CircularProgress {
        id: progressRing
        anchors.centerIn: parent
        implicitSize: Math.min(parent.width, parent.height)
        lineWidth: 7
        value: Pomodoro.progress
        colPrimary: Appearance.colors.colPrimary
        colSecondary: Appearance.colors.colOutlineVariant
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 0

        StyledText {
            text: Pomodoro.formattedTime
            font.pixelSize: 28
            font.weight: Font.Bold
            color: Appearance.colors.colOnLayer1
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
