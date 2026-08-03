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
        spacing: 24

        StopwatchTimer {
            id: timerWidget
            Layout.alignment: Qt.AlignVCenter
        }

        StopwatchLaps {
            id: lapsWidget
            Layout.alignment: Qt.AlignVCenter
        }
    }

    StopwatchControls {
        id: controlsWidget
        Layout.alignment: Qt.AlignHCenter
    }
}
