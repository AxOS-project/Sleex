import qs.modules.common
import SleexUiKit.Widgets
import qs.services
import SleexUiKit.Functions
import SleexUiKit.Appearance
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts

Item {
    id: root
    property bool showDialog: false
    property bool isDialogEdit: false
    property int dialogMargins: 400
    property int fabSize: 48
    property int fabMargins: 14

    Keys.onPressed: (event) => {
        // Open add dialog on "N" (any modifiers)
        if (event.key === Qt.Key_N) {
            root.showDialog = true
            event.accepted = true;
        }
        // Close dialog on Esc if open
        else if (event.key === Qt.Key_Escape && root.showDialog) {
            root.showDialog = false
            root.isDialogEdit = false
            Todo.currentTodoItemData = undefined
            event.accepted = true;
        }
    }

    RowLayout {
        id: todoRowLayout
        anchors.fill: parent
        spacing: 10

        TaskList {
            id: unfinishedTaskList
            Layout.fillWidth: true
            Layout.fillHeight: true
            listBottomPadding: root.fabSize + root.fabMargins * 2
            emptyPlaceholderIcon: "check_circle"
            emptyPlaceholderText: qsTr("Nothing here!")
            editingCallback: root.editingCallback
            taskList: Todo.list
                .map(function(item, i) { return Object.assign({}, item, {originalIndex: i}); })
                .filter(function(item) { return !item.done; })
        }

        TaskList {
            id: doneTaskList
            Layout.fillWidth: true
            Layout.fillHeight: true
            listBottomPadding: root.fabSize + root.fabMargins * 2
            emptyPlaceholderIcon: "checklist_rtl"
            emptyPlaceholderText: qsTr("Finished tasks goes there!")
            editingCallback: root.editingCallback
            taskList: Todo.list
                .map(function(item, i) { return Object.assign({}, item, {originalIndex: i}); })
                .filter(function(item) { return item.done; })
        }
    }

    // + FAB
    StyledRectangularShadow {
        target: fabButton
        radius: Appearance.rounding.normal
    }
    
    Button { 
        id: fabButton
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: root.fabMargins
        anchors.bottomMargin: root.fabMargins
        width: root.fabSize
        height: root.fabSize
        PointingHandInteraction {}

        onClicked: root.showDialog = true

        background: Rectangle {
            id: fabBackground
            anchors.fill: parent
            radius: Appearance.rounding.normal
            color: (fabButton.down) ? Appearance.colors.colPrimaryContainerActive : (fabButton.hovered ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colPrimaryContainer)

            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }
        }

        contentItem: MaterialSymbol {
            text: "add"
            horizontalAlignment: Text.AlignHCenter
            iconSize: Appearance.font.pixelSize.huge
            color: Appearance.m3colors.m3onPrimaryContainer
        }
    }

    Item {
        anchors.fill: parent
        z: 9999

        visible: opacity > 0
        opacity: root.showDialog ? 1 : 0
        Behavior on opacity {
            NumberAnimation { 
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        onVisibleChanged: {
            if (!visible) {
                todoInput.text = ""
                fabButton.focus = true
            }
        }

        Rectangle { // Scrim
            anchors.fill: parent
            radius: Appearance.rounding.small
            color: Appearance.colors.colScrim
            MouseArea {
                hoverEnabled: true
                anchors.fill: parent
                preventStealing: true
                propagateComposedEvents: false
            }
        }

        Rectangle { // The dialog
            id: dialog
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: root.dialogMargins
            implicitHeight: dialogColumnLayout.implicitHeight

            color: Appearance.colors.colSurfaceContainerHigh
            radius: Appearance.rounding.normal

            function addTask() {
                if (todoInput.text.length > 0) {
                    Todo.addTask(todoInput.text)
                    todoInput.text = ""
                    root.showDialog = false
                }
            }

            function editTask() {
                if (todoInput.text.length > 0) {
                    Todo.editTask(todoInput.text)
                    todoInput.text = ""
                    root.showDialog = false
                    root.isDialogEdit = false
                    Todo.currentTodoItemData = undefined
                }
            }

            ColumnLayout {
                id: dialogColumnLayout
                anchors.fill: parent
                spacing: 16

                StyledText {
                    Layout.topMargin: 16
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.alignment: Qt.AlignLeft
                    color: Appearance.m3colors.m3onSurface
                    font.pixelSize: Appearance.font.pixelSize.larger
                    text: root.isDialogEdit ? qsTr("Edit Task") : root.showDialog ? qsTr("Add Task") : ""
                }

                TextField {
                    id: todoInput
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    padding: 10
                    color: activeFocus ? Appearance.m3colors.m3onSurface : Appearance.m3colors.m3onSurfaceVariant
                    renderType: Text.NativeRendering
                    selectedTextColor: Appearance.m3colors.m3onSecondaryContainer
                    selectionColor: Appearance.colors.colSecondaryContainer
                    placeholderText: qsTr("Task description")
                    placeholderTextColor: Appearance.m3colors.m3outline
                    focus: root.showDialog
                    onAccepted: root.isDialogEdit ? dialog.editTask() : dialog.addTask()

                    background: Rectangle {
                        anchors.fill: parent
                        radius: Appearance.rounding.verysmall
                        border.width: 2
                        border.color: todoInput.activeFocus ? Appearance.colors.colPrimary : Appearance.m3colors.m3outline
                        color: "transparent"
                    }

                    cursorDelegate: Rectangle {
                        width: 1
                        color: todoInput.activeFocus ? Appearance.colors.colPrimary : "transparent"
                        radius: 1
                    }
                }

                RowLayout {
                    Layout.bottomMargin: 16
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.alignment: Qt.AlignRight
                    spacing: 5

                    DialogButton {
                        buttonText: qsTr("Cancel")
                        onClicked: {
                            root.showDialog = false
                            root.isDialogEdit = false
                            Todo.currentTodoItemData = undefined
                        }
                    }
                    DialogButton {
                        buttonText: root.isDialogEdit ? qsTr("Edit") : qsTr("Add")
                        enabled: todoInput.text.length > 0 && (!root.isDialogEdit || todoInput.text != Todo.currentTodoItemData?.content)
                        onClicked: root.isDialogEdit ? dialog.editTask() : dialog.addTask()
                    }
                }
            }
        }
    }

    function editingCallback() {
        todoInput.text = Todo.currentTodoItemData.content
        root.isDialogEdit = true
        root.showDialog = true
    }
}
