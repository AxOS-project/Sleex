import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common.widgets
import qs.modules.common

ComboBox {
    id: control
    required property string icon

    implicitWidth: contentLayout.implicitWidth + leftPadding + rightPadding
    implicitHeight: 40
    leftPadding: 12
    rightPadding: 12

    // Kill the default arrow
    indicator: Item {} 

    contentItem: RowLayout {
        id: contentLayout
        spacing: 8
        
        MaterialSymbol {
            text: control.icon
            iconSize: 20
            fill: 1
            color: Appearance.colors.colOnLayer0
        }
        
        StyledText {
            text: control.displayText
            color: Appearance.colors.colOnLayer0
            font.pixelSize: 15
            Layout.alignment: Qt.AlignVCenter
        }
    }

    background: Rectangle {
        color: control.hovered || control.pressed ? Appearance.colors.colLayer1 : "transparent"
        radius: Appearance.rounding.full
        
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    delegate: ItemDelegate {
        width: control.popup.width - 8
        height: 40
        x: 4 // Give it a little margin inside the popup
        
        contentItem: StyledText {
            text: modelData
            color: highlighted ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer0
            font.pixelSize: 14
            verticalAlignment: Text.AlignVCenter
        }
        
        background: Rectangle {
            color: highlighted ? Appearance.colors.colPrimary : "transparent"
            radius: Appearance.rounding.small ?? 8
        }
    }

    popup: Popup {
        y: control.height + 8
        width: control.width >= 200 ? control.width : 200
        implicitHeight: contentItem.implicitHeight + 8
        padding: 4

        property bool fullyOpened: false
        onOpened: fullyOpened = true
        onClosed: fullyOpened = false

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
            ScrollIndicator.vertical: ScrollIndicator { }
            highlightMoveDuration: 0  
            highlightResizeDuration: 0
            highlight: Rectangle {
                color: Appearance.colors.colPrimaryContainer
                radius: Appearance.rounding.small ?? 8
            }
        }

        background: Rectangle {
            color: Appearance.colors.colLayer0
            radius: Appearance.rounding.medium ?? 12
            border.color: Appearance.colors.colLayer2
            border.width: 1
        }
    }
}