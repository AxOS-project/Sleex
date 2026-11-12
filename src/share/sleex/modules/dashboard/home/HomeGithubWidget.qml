import qs.modules.common
import qs.services
import qs.modules.dashboard.calendar
import QtQuick
import Quickshell
import SleexUiKit.Widgets
import SleexUiKit.Appearance

Rectangle {
    id: root
    property bool connected: false
    color: Appearance.colors.colLayer1
    radius: Appearance.rounding.normal
    clip: true

    Column {
        anchors.centerIn: parent
        spacing: 10

        StyledText {
            visible: root.connected
            text: root.connected ? Github.contribution_number || qsTr("Loading...") : qsTr("--")
            color: Appearance.colors.colPrimary
            font.pixelSize: 60
            font.bold: true
            anchors.horizontalCenter: parent.horizontalCenter
        }

        StyledText {
            text: root.connected ? qsTr("contributions in the last year") : "No network connection"
            color: Appearance.colors.colOnLayer1
            font.pixelSize: 20
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Loader {
            asynchronous: true
            active: root.connected
            anchors.horizontalCenter: parent.horizontalCenter
            sourceComponent: GhCalendar {}
        }

        Loader {
            asynchronous: true
            active: !root.connected
            anchors.horizontalCenter: parent.horizontalCenter
            sourceComponent: GhCalendarNoNet {}
        }

        StyledText {
            text: `@${Github.author}`
            color: Appearance.colors.colOnLayer1
            font.pixelSize: 16
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
