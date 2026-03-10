import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.functions
import Sleex.Utils

Item {
    id: root
    anchors.fill: parent
    focus: true

    property int cellWidth: 100
    property int cellHeight: 110
    
    property var selectedIcons: []
    property string dragLeader: ""
    property real groupDragX: 0
    property real groupDragY: 0

    property real startX: 0
    property real startY: 0
    property string editingFilePath: ""
    property var contextMenu: desktopMenu

    DesktopModel {
        id: desktopModel
        Component.onCompleted: loadDirectory(FileUtils.trimFileProtocol(Directories.desktop))
    }

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

    function performMassDrop(leaderPath, targetX, targetY) {

        let maxCol = Math.max(0, Math.floor(gridArea.width / cellWidth) - 1);
        let maxRow = Math.max(0, Math.floor(gridArea.height / cellHeight) - 1);

        let visuals = [];
        for (let i = 0; i < gridArea.children.length; i++) {
            let child = gridArea.children[i];
            if (child.filePath && root.selectedIcons.includes(child.filePath)) {
                let isLeader = (root.dragLeader === child.filePath);
                let offsetX = isLeader ? child.getDragX() : root.groupDragX;
                let offsetY = isLeader ? child.getDragY() : root.groupDragY;
                visuals.push({
                    childRef: child,
                    absX: child.x + offsetX,
                    absY: child.y + offsetY
                });
            }
        }

        desktopModel.massMove(root.selectedIcons, leaderPath, targetX, targetY, maxCol, maxRow);

        for (let i = 0; i < visuals.length; i++) {
            visuals[i].childRef.compensateAndSnap(visuals[i].absX, visuals[i].absY);
        }

        root.dragLeader = "";
        root.groupDragX = 0;
        root.groupDragY = 0;
    }

    Rectangle {
        id: lasso
        color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.3)
        border.color: Appearance.colors.colPrimary
        border.width: 1
        visible: false
        radius: Appearance.rounding.small
        z: 99
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        
        onPressed: (mouse) => {
            root.editingFilePath = ""
            desktopMenu.close()
            
            if (mouse.button === Qt.RightButton) {
                root.selectedIcons = []
                bgContextMenu.openAt(mouse.x, mouse.y, root.width, root.height)
            } else {
                bgContextMenu.close()
                root.selectedIcons = []
                root.startX = mouse.x
                root.startY = mouse.y
                lasso.x = mouse.x
                lasso.y = mouse.y
                lasso.width = 0
                lasso.height = 0
                lasso.visible = true
            }
        }
        
        onPositionChanged: (mouse) => {
            if (lasso.visible) {
                lasso.x = Math.min(mouse.x, root.startX);
                lasso.y = Math.min(mouse.y, root.startY);
                lasso.width = Math.abs(mouse.x - root.startX);
                lasso.height = Math.abs(mouse.y - root.startY);
                
                let minCol = Math.floor((lasso.x - gridArea.x) / cellWidth);
                let maxCol = Math.floor((lasso.x + lasso.width - gridArea.x) / cellWidth);
                let minRow = Math.floor((lasso.y - gridArea.y) / cellHeight);
                let maxRow = Math.floor((lasso.y + lasso.height - gridArea.y) / cellHeight);

                let newSelection = [];
                for (let i = 0; i < gridArea.children.length; i++) {
                    let child = gridArea.children[i];
                    if (child.filePath !== undefined && 
                        child.gridX >= minCol && child.gridX <= maxCol &&
                        child.gridY >= minRow && child.gridY <= maxRow) {
                        newSelection.push(child.filePath);
                    }
                }
                root.selectedIcons = newSelection;
            }
        }
        
        onReleased: { lasso.visible = false }
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_F2 && selectedIcons.length > 0) editingFilePath = selectedIcons[0]
    }

    Item {
        id: gridArea
        visible: Config.options.background.showDesktopIcons
        anchors.fill: parent
        anchors.margins: 20
        anchors.topMargin: 40

        Repeater {
            model: desktopModel
            delegate: DesktopIconDelegate {
                property int itemIndex: index 
            }
        }
    }

    DesktopIconContextMenu {
        id: desktopMenu
        onOpenFileRequested: (path, isDir) => root.exec(path, isDir)
        onRenameRequested: (path) => { root.editingFilePath = path }
    }

    BackgroundContextMenu { id: bgContextMenu }
}