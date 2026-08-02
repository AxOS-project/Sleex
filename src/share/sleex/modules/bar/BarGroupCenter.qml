import qs.modules.common
import SleexUiKit.Widgets
import qs.services
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property real padding: 5
    property real margin: 0
    implicitHeight: 40
    implicitWidth: rowLayout.implicitWidth + padding * 2
    default property alias items: rowLayout.children

    Rectangle {
        id: background
        color: "transparent"
        anchors.fill: parent
        
        
        RowLayout {
            id: rowLayout
            spacing: 0
            
            anchors {
                verticalCenter: parent.verticalCenter
                leftMargin: root.margin
                rightMargin: root.margin
            }
            
        }

    }

}