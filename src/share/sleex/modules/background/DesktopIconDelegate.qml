import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services

Item {
    id: delegateRoot
    
    required property string fileName
    required property string filePath
    required property bool fileIsDir

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

    property int gridX: root.iconLayout[fileName] ? root.iconLayout[fileName].x : 0
    property int gridY: root.iconLayout[fileName] ? root.iconLayout[fileName].y : 0

    x: gridX * root.cellWidth
    y: gridY * root.cellHeight

    property bool isSnapping: snapAnimX.running || snapAnimY.running

    Behavior on x { 
        enabled: !mouseArea.drag.active && !delegateRoot.isSnapping
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic } 
    }
    Behavior on y { 
        enabled: !mouseArea.drag.active && !delegateRoot.isSnapping
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic } 
    }

    Component.onCompleted: root.registerNewIcon(fileName)

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
                                    
                                    root.renameIconInLayout(fileName, newName);
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
            opacity: root.selectedIcon === filePath ? 0.2 : 0.0
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

            onReleased: {
                if (drag.active) {
                    let absoluteX = delegateRoot.x + dragContainer.x;
                    let absoluteY = delegateRoot.y + dragContainer.y;

                    let snapX = Math.max(0, Math.round(absoluteX / root.cellWidth));
                    let snapY = Math.max(0, Math.round(absoluteY / root.cellHeight));

                    let targetRootX = snapX * root.cellWidth;
                    let targetRootY = snapY * root.cellHeight;

                    dragContainer.x = absoluteX - targetRootX;
                    dragContainer.y = absoluteY - targetRootY;

                    snapAnimX.start();
                    snapAnimY.start();

                    root.handleDrop(fileName, snapX, snapY);
                }
            }

            onClicked: (mouse) => {
                root.forceActiveFocus()
                
                if (mouse.button === Qt.RightButton) {
                    root.selectedIcon = filePath
                    let pos = mapToItem(root, mouse.x, mouse.y)
                    root.contextMenu.openAt(pos.x, pos.y, filePath, fileIsDir, appEntry, root.width, root.height)
                } else {
                    root.selectedIcon = (root.selectedIcon === filePath) ? "" : filePath
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