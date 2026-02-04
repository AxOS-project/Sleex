import qs.modules.common
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

ComboBox {
    id: comboBox
    implicitHeight: 56
    Layout.fillWidth: true

    Material.theme: Material.System
    Material.accent: Appearance.m3colors.m3primary
    Material.background: Appearance.m3colors.m3surface
    Material.foreground: Appearance.m3colors.m3onSurface
    Material.containerStyle: Material.Filled

    font.family: Appearance.font.family.main
    font.pixelSize: Appearance.font.pixelSize.small

    contentItem: Text {
        text: comboBox.displayText
        font: comboBox.font
        color: Appearance.m3colors.m3onSurface
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 12
    }

    indicator: Canvas {
        width: 16
        height: 16
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        contextType: "2d"

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.fillStyle = Appearance.m3colors.m3onSurface;
            ctx.beginPath();
            ctx.moveTo(4, 6);
            ctx.lineTo(8, 10);
            ctx.lineTo(12, 6);
            ctx.closePath();
            ctx.fill();
        }
    }

    background: Rectangle {
        radius: 6
        color: Appearance.m3colors.m3surface

        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            height: 1
            color: comboBox.focus
                ? Appearance.m3colors.m3primary
                : comboBox.hovered
                    ? Appearance.m3colors.m3outline
                    : Appearance.m3colors.m3outlineVariant

            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }
        }
    }

    popup: Popup {
        y: comboBox.height
        width: comboBox.width
        // implicitHeight: contentItem.implicitHeight + 30

        background: Rectangle {
            color: Appearance.m3colors.m3surface
            radius: 6
            border.color: Appearance.m3colors.m3outlineVariant
        }

        contentItem: ListView {
            model: comboBox.delegateModel
            clip: true
            implicitHeight: contentHeight

            delegate: ItemDelegate {
                width: comboBox.width
             

                background: Rectangle {
                    color: highlighted
                        ? Appearance.m3colors.m3secondaryContainer
                        : "transparent"
                }

                contentItem: Text {
                    
                    text: typeof model.display !== "undefined" ? model.display : modelData
                    color: highlighted
                        ? Appearance.m3colors.m3onSecondaryContainer
                        : Appearance.m3colors.m3onSurface
                    verticalAlignment: Text.AlignVCenter
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                }

                onClicked: comboBox.currentIndex = index
            }
        }
    }

}