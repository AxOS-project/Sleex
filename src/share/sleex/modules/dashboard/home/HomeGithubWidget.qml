import qs.modules.common
import qs.services
import qs.modules.dashboard.calendar
import QtQuick
import Quickshell
import SleexUiKit.Appearance

Rectangle {
    id: root
    property bool connected: false
    color: Appearance.colors.colLayer1
    radius: Appearance.rounding.normal

    Column {
        anchors.centerIn: parent
        spacing: 10

        Text {
            visible: root.connected
            text: root.connected ? Github.contribution_number || qsTr("Loading...") : qsTr("--")
            color: Appearance.colors.colPrimary
            font.pixelSize: 60
            font.bold: true
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            text: root.connected ? qsTr("contributions in the last year") : "No network connection"
            color: Appearance.colors.colOnLayer1
            font.pixelSize: 20
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Item {
            width: 358
            height: 61
            anchors.horizontalCenter: parent.horizontalCenter

            Loader {
                anchors.fill: parent
                active: true
                visible: root.connected
                sourceComponent: GhCalendar {}
            }

            Loader {
                anchors.fill: parent
                active: true
                visible: !root.connected
                sourceComponent: GhCalendarNoNet {}
            }
        }

        Text {
            text: `@${Github.author}`
            color: Appearance.colors.colOnLayer1
            font.pixelSize: 16
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
