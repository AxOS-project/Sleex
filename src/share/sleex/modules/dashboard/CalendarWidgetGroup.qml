import qs.modules.dashboard.calendar
import QtQuick

Rectangle {
    id: root
    color: "transparent"
    clip: true

    CalendarTimeTable {
        anchors.fill: parent
    }
}