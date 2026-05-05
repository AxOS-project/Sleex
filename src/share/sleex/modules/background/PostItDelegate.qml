import QtQuick
import QtQuick.Controls
import qs.modules.common.widgets
import qs.modules.common

Rectangle {
    id: postitRoot
    width: 200
    height: 200
    color: "#fdfd96"
    border.color: "#d9d97c"
    border.width: 1
    radius: 4
    
    property string noteText: ""
    signal deleteRequested()
    signal textUpdated(string newText)
    signal positionUpdated(real newX, real newY)

    DragHandler {
        target: postitRoot
        cursorShape: active ? Qt.ClosedHandCursor : Qt.OpenHandCursor

        onActiveChanged: {
            if (!active) {
                postitRoot.positionUpdated(postitRoot.x, postitRoot.y)
            }
        }
    }

    TextEdit {
        id: editor
        anchors.fill: parent
        anchors.margins: 12
        text: postitRoot.noteText
        wrapMode: TextEdit.Wrap
        font.pointSize: 12
        color: "#222"
        readOnly: true

        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Escape) {
                readOnly = true
                postitRoot.textUpdated(text)
                readOnly = true
                event.accepted = true
            }
        }
    }

    RippleButton {
        id: deleteButton
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 4
        width: 24
        height: 24
        buttonRadius: width / 2
        z: 100

        MaterialSymbol {
            anchors.centerIn: parent;
            text: "close";
            iconSize: 16
            color: Appearance.colors.colOnError
        }

        onClicked: postitRoot.deleteRequested()
    }

    MouseArea {
        anchors.fill: parent
        onDoubleClicked: {
            editor.readOnly = false
            editor.forceActiveFocus()
        }
    }
}