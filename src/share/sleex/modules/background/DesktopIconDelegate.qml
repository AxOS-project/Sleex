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
    required property var gridView

    width: gridView.cellWidth
    height: gridView.cellHeight

    property int visualIndex: DelegateModel.itemsIndex

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

    Item {
        id: dragContainer
        anchors.fill: mouseArea.drag.active ? undefined : parent

        Drag.active: mouseArea.drag.active
        Drag.source: delegateRoot
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2

        states: State {
            when: mouseArea.drag.active
            ParentChange { target: dragContainer; parent: gridView }
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
                    
                    active: gridView.editingFilePath === filePath

                    sourceComponent: StyledTextInput {
                        id: renameInput
                        text: fileName
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        width: 110
                        color: "white"

                        onEditingFinished: gridView.editingFilePath = ""

                        Component.onCompleted: {
                            forceActiveFocus()
                            selectAll()
                        }

                        onVisibleChanged: {
                            if (visible) {
                                forceActiveFocus()
                                selectAll()
                            }
                        }

                        onActiveFocusChanged: {
                            if (!activeFocus && gridView.editingFilePath === filePath) {
                                gridView.editingFilePath = ""
                            }
                        }

                        Keys.onPressed: function (event) {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (text.trim() !== "" && text !== fileName) {
                                    let newPath = filePath.substring(0, filePath.lastIndexOf('/') + 1) + text.trim()
                                    
                                    Quickshell.execDetached(["mv", filePath, newPath])
                                }
                                gridView.editingFilePath = ""
                            } else if (event.key === Qt.Key_Escape) {
                                gridView.editingFilePath = ""
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
            opacity: gridView.selectedIcon === filePath ? 0.2 : 0.0
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

            onPositionChanged: (mouse) => {
                if (drag.active) {
                    let mappedPos = mapToItem(gridView, mouseX, mouseY)
                    let targetIndex = gridView.indexAt(mappedPos.x, mappedPos.y)                    
                    if (targetIndex !== -1 && targetIndex !== delegateRoot.visualIndex) {
                        gridView.model.items.move(delegateRoot.visualIndex, targetIndex)
                    }
                }
            }
            
            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                color: "white"
                opacity: parent.containsMouse ? 0.1 : 0.0
                radius: 8
                Behavior on opacity { NumberAnimation { duration: 100 } }
            }

            onClicked: (mouse) => {
                gridView.forceActiveFocus()

                if (mouse.button === Qt.RightButton) {
                    gridView.selectedIcon = filePath
                    
                    let pos = mapToItem(gridView.parent, mouse.x, mouse.y)
                    
                    gridView.contextMenu.openAt(
                        pos.x, pos.y, 
                        filePath, fileIsDir, appEntry, 
                        gridView.parent.width, gridView.parent.height
                    )
                } else {
                    gridView.selectedIcon = (gridView.selectedIcon === filePath) ? "" : filePath
                    gridView.contextMenu.close()
                }
            }

            onDoubleClicked: {
                if (filePath.endsWith(".desktop") && appEntry) {
                    appEntry.execute()
                } else {
                    gridView.execFile(filePath, fileIsDir)
                }
            }

            onReleased: {
                if (typeof gridView.saveOrder === "function") {
                    gridView.saveOrder()
                }
            }
        }
    }
}