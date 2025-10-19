import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.modules.dashboard.calendar
import qs.modules.dashboard.todo
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Rectangle {
    id: root
    color: "transparent"
    clip: true

    
    TodoWidget {
        anchors.fill: parent
        anchors.margins: 5
    }
}