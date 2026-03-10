import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services

Item {
    id: delegateRoot
    
    property string fileName: model.fileName
    property string filePath: model.filePath
    property bool fileIsDir: model.isDir
    property int gridX: model.gridX
    property int gridY: model.gridY

    function getDragX() { return dragContainer.x; }
    function getDragY() { return dragContainer.y; }

    function compensateAndSnap(absVisX, absVisY) {
        dragContainer.x = absVisX - delegateRoot.x;
        dragContainer.y = absVisY - delegateRoot.y;
        snapAnimX.start();
        snapAnimY.start();
    }

    width: root.cellWidth
    height: root.cellHeight

    property var appEntry: fileName.endsWith(".desktop") ? DesktopEntries.byId(DesktopUtils.getAppId(fileName)) : null

    property string resolvedIcon: {
        if (fileName.endsWith(".desktop")) {
            if (appEntry && appEntry.icon && appEntry.icon !== "") return appEntry.icon;
            return AppSearch.guessIcon(DesktopUtils.getAppId(fileName));
        } else if (DesktopUtils.getFileType(fileName, fileIsDir) === "image") {
            return "file://" + filePath;
        } else {
            return DesktopUtils.getIconName(fileName, fileIsDir);
        }
    }

    x: gridX * root.cellWidth
    y: gridY * root.cellHeight

    property bool isSnapping: snapAnimX.running || snapAnimY.running
    Behavior on x { 
        enabled: !mouseArea.drag.active && !isSnapping && !root.selectedIcons.includes(filePath)
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic } 
    }
    Behavior on y { 
        enabled: !mouseArea.drag.active && !isSnapping && !root.selectedIcons.includes(filePath)
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic } 
    }

    Item {
        id: dragContainer
        width: parent.width
        height: parent.height

        PropertyAnimation { id: snapAnimX; target: dragContainer; property: "x"; to: 0; duration: 250; easing.type: Easing.OutCubic }
        PropertyAnimation { id: snapAnimY; target: dragContainer; property: "y"; to: 0; duration: 250; easing.type: Easing.OutCubic }

        states: State {
            when: mouseArea.drag.active
            PropertyChanges { target: dragContainer; opacity: 0.8; scale: 1.1; z: 100 }
        }
        transitions: Transition { NumberAnimation { properties: "scale,opacity"; duration: 150 } }

        transform: Translate {
            x: (root.selectedIcons.includes(filePath) && root.dragLeader !== "" && root.dragLeader !== filePath) ? root.groupDragX : 0
            y: (root.selectedIcons.includes(filePath) && root.dragLeader !== "" && root.dragLeader !== filePath) ? root.groupDragY : 0
        }

        onXChanged: {
            if (mouseArea.drag.active) {
                root.dragLeader = filePath;
                root.groupDragX = x;
            }
        }
        onYChanged: {
            if (mouseArea.drag.active) {
                root.dragLeader = filePath;
                root.groupDragY = y;
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 6

            IconImage {
                anchors.horizontalCenter: parent.horizontalCenter
                implicitSize: 48
                source: {
                    if (delegateRoot.resolvedIcon.startsWith("file://") || delegateRoot.resolvedIcon.startsWith("/")) {
                        return delegateRoot.resolvedIcon
                    } else {
                        return Quickshell.iconPath(delegateRoot.resolvedIcon, fileIsDir ? "folder" : "text-x-generic")
                    }
                }
            }

            Item {
                width: 88
                height: 40

                StyledText {
                    anchors.fill: parent
                    text: (appEntry && appEntry.name !== "") ? appEntry.name : fileName
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    style: Text.Outline
                    styleColor: "black"
                    color: "white"
                    visible: !renameLoader.active
                }

                Loader {
                    id: renameLoader
                    anchors.centerIn: parent
                    width: 110
                    height: 24
                    active: root.editingFilePath === filePath

                    sourceComponent: StyledTextInput {
                        anchors.fill: parent
                        anchors.margins: 2
                        text: fileName
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        color: "white"

                        Component.onCompleted: {
                            forceActiveFocus()
                            selectAll()
                        }

                        onActiveFocusChanged: {
                            if (!activeFocus && root.editingFilePath === filePath) {
                                root.editingFilePath = ""
                            }
                        }

                        Keys.onPressed: function (event) {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (text.trim() !== "" && text !== fileName) {
                                    let newName = text.trim();
                                    let newPath = filePath.substring(0, filePath.lastIndexOf('/') + 1) + newName;
                                    
                                    Quickshell.execDetached(["mv", filePath, newPath])
                                }
                                root.editingFilePath = ""
                                event.accepted = true
                            } else if (event.key === Qt.Key_Escape) {
                                root.editingFilePath = ""
                                event.accepted = true
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 4
            color: "white"
            opacity: root.selectedIcons.includes(filePath) ? 0.2 : 0.0
            radius: 8
            Behavior on opacity { NumberAnimation { duration: 100 } }
        }
        
        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            
            drag.target: dragContainer

            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                color: "white"
                opacity: parent.containsMouse ? 0.1 : 0.0
                radius: 8
                Behavior on opacity { NumberAnimation { duration: 100 } }
            }

            onPressed: (mouse) => {
                if (mouse.button === Qt.LeftButton && !root.selectedIcons.includes(filePath)) {
                    root.selectedIcons = [filePath]
                }
            }

            onReleased: {
                if (drag.active) {
                    let absoluteX = delegateRoot.x + dragContainer.x;
                    let absoluteY = delegateRoot.y + dragContainer.y;
                    let snapX = Math.max(0, Math.round(absoluteX / root.cellWidth));
                    let snapY = Math.max(0, Math.round(absoluteY / root.cellHeight));

                    root.performMassDrop(filePath, snapX, snapY);
                }
            }

            onClicked: (mouse) => {
                root.forceActiveFocus() 
                
                if (mouse.button === Qt.RightButton) {
                    if (!root.selectedIcons.includes(filePath)) {
                        root.selectedIcons = [filePath]
                    }
                    let pos = mapToItem(root, mouse.x, mouse.y)
                    root.contextMenu.openAt(pos.x, pos.y, filePath, fileIsDir, appEntry, root.width, root.height, root.selectedIcons)
                } else {
                    root.selectedIcons = [filePath]
                    root.contextMenu.close()
                }
            }

            onDoubleClicked: (mouse) => {
                if (mouse.button === Qt.LeftButton) {
                    if (filePath.endsWith(".desktop") && appEntry) appEntry.execute()
                    else root.exec(filePath, fileIsDir)
                }
            }
        }
    }
}