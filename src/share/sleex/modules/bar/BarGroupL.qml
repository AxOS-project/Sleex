import qs.modules.common
import SleexUiKit.Widgets
import qs.services
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property real padding: 5
    implicitHeight: 40
    implicitWidth: rowLayout.implicitWidth + padding * 2
    default property alias items: rowLayout.children

    RowLayout {
        id: rowLayout
        anchors {
            verticalCenter: parent.verticalCenter
            left: parent.left
            right: parent.right
            leftMargin: root.padding
            rightMargin: root.padding
        }
        spacing: 4

    }
}