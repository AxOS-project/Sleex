import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

ColumnLayout {
    id: root
    property string title
    property string icon
    property color backgroundColor: Appearance.colors.colLayer1
    default property alias data: sectionContent.data

    Layout.fillWidth: true
    spacing: 8
    
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: contentColumn.implicitHeight + 24
        color: root.backgroundColor
        radius: 8

        ColumnLayout {
            id: contentColumn
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 12
            }
            spacing: 8

            RowLayout {
                spacing: 5

                MaterialSymbol {
                    text: root.icon
                    iconSize: 20
                    color: Appearance.colors.colOnLayer1
                }
                StyledText {
                    text: root.title
                    font.pixelSize: Appearance.font.pixelSize.larger
                    font.weight: Font.Medium
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Appearance.colors.colOutline
                opacity: 0.6
            }

            ColumnLayout {
                id: sectionContent
                Layout.fillWidth: true
                spacing: 4
            }
        }
    }
}