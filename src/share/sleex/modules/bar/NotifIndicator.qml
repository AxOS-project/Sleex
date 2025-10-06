import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root
    property int count: Notifications.list.length
    height: 20
    width: notifRow.width
    visible: count > 0

    RowLayout {
        id: notifRow
        anchors.margins: 2
        spacing: 2

        StyledText {
            font.pixelSize: 15
            text: count > 99 ? "99+" : count.toString()
            color: Appearance.colors.colOnLayer0
        }

        MaterialSymbol {
            id: icon
            iconSize: 20
            text: "notifications"
            color: Appearance.colors.colOnLayer0
        }
    }
}