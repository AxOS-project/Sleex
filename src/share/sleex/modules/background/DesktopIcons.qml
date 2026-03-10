import QtQuick
import Quickshell
import Qt.labs.folderlistmodel
import QtQml.Models
import Sleex.Utils
import qs.modules.common
import qs.modules.common.functions

Item {
    id: root
    anchors.fill: parent

    function exec(filePath, isDir) {
        let type = DesktopUtils.getFileType(filePath, isDir);
        let cmd = [];

        switch(type) {
            case "image": cmd = [Config.options.apps.imageViewer, filePath]; break;
            case "video": cmd = [Config.options.apps.videoPlayer, filePath]; break;
            case "audio": cmd = [Config.options.apps.audioPlayer, filePath]; break;
            case "archive": cmd = [Config.options.apps.archiveManager, filePath]; break;
            case "directory": cmd = [Config.options.apps.fileManager, filePath]; break;
            case "code":
            case "text": cmd = [Config.options.apps.textEditor, filePath]; break;
            case "document": cmd = [Config.options.apps.documentViewer, filePath]; break;
            default: cmd = ["xdg-open", filePath];
        }
        Quickshell.execDetached(cmd)
    }

    function saveCurrentOrder() {
        let currentOrder = [];
        for (let i = 0; i < visualModel.items.count; i++) {
            let item = visualModel.items.get(i);
            if (item && item.model) {
                currentOrder.push(item.model.fileName);
            }
        }
        DesktopStateManager.saveOrder(currentOrder);
    }
    
    FolderListModel {
        id: folderModel
        folder: Directories.desktop
        showDotAndDotDot: false
        nameFilters: ["*"]

        onStatusChanged: {
            if (status === FolderListModel.Ready) {
                restoreOrderTimer.start()
            }
        }
    }

    Timer {
        id: restoreOrderTimer
        interval: 100 
        onTriggered: {
            let savedOrder = DesktopStateManager.getOrder();
            if (savedOrder.length === 0) return;

            let targetIndex = 0;
            for (let i = 0; i < savedOrder.length; i++) {
                let savedFileName = savedOrder[i];
                let currentIndex = -1;
                
                for (let j = targetIndex; j < visualModel.items.count; j++) {
                    let item = visualModel.items.get(j);
                    if (item && item.model && item.model.fileName === savedFileName) {
                        currentIndex = j;
                        break;
                    }
                }
                
                if (currentIndex !== -1) {
                    if (currentIndex !== targetIndex) {
                        visualModel.items.move(currentIndex, targetIndex);
                    }
                    targetIndex++;
                }
            }
        }
    }

    DelegateModel {
        id: visualModel
        model: folderModel
        delegate: DesktopIconDelegate {
            gridView: grid
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        
        onPressed: (mouse) => {
            grid.selectedIcon = ""
            desktopMenu.close()
            grid.editingFilePath = ""

            if (mouse.button === Qt.RightButton) {
                // TODO: global context
            }
        }
    }

    GridView {
        id: grid
        anchors.fill: parent
        anchors.margins: 20
        anchors.topMargin: 40
        cellWidth: 100
        cellHeight: 110
        model: visualModel
        interactive: false
        flow: GridView.FlowTopToBottom

        property string selectedIcon: ""
        property string editingFilePath: ""

        property var contextMenu: desktopMenu

        function saveOrder() { root.saveCurrentOrder() }

        focus: true

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_F2 && selectedIcon !== "") {
                editingFilePath = selectedIcon
                event.accepted = true
            }
        }

        function execFile(path, dir) { root.exec(path, dir) }

        moveDisplaced: Transition {
            NumberAnimation { 
                properties: "x,y" 
                duration: 150 
                easing.type: Easing.OutCubic
            }
        }
    }

    DesktopIconContextMenu {
        id: desktopMenu
        onOpenFileRequested: (path, isDir) => root.exec(path, isDir)
        onRenameRequested: (path) => { grid.editingFilePath = path }
    }
}