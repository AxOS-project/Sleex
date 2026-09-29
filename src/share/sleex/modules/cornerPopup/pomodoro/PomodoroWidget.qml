import qs.modules.common
import SleexUiKit.Widgets
import SleexUiKit.Appearance
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    anchors.fill: parent
    spacing: 12

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.alignment: Qt.AlignHCenter
        spacing: 28

        PomodoroTimer {
            id: timerWidget
            Layout.alignment: Qt.AlignVCenter
        }

        PomodoroTimerButtons {
            id: timerButtonsWidget
            Layout.alignment: Qt.AlignVCenter
        }
    }

    PomodoroControls {
        id: controlsWidget
        Layout.alignment: Qt.AlignHCenter
    }
}
