import QtQuick
import Quickshell
import Qt.labs.folderlistmodel
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
    property bool isMassDropping: false

    property real startX: 0
    property real startY: 0


    property string editingFilePath: ""
    property var contextMenu: desktopMenu

    property var iconLayout: ({})
    property bool layoutLoaded: false

    // Timer {
    //     id: debugTimer
    //     interval: 1000
    //     running: true
    //     repeat: true
    //     onTriggered: {
    //         console.log(selectedIcons)
    //     }
    // }

    Component.onCompleted: {
        let savedLayout = DesktopStateManager.getLayout();
        let layout = {};
        
        for (let file in savedLayout) {
            layout[file] = { 
                x: parseInt(savedLayout[file].x || 0), 
                y: parseInt(savedLayout[file].y || 0) 
            };
        }
        
        iconLayout = layout;
        layoutLoaded = true;
    }

    function saveLayout() {
        DesktopStateManager.saveLayout(iconLayout);
    }

    function handleDrop(draggedFilePath, gridX, gridY) {
        root.isMassDropping = true;
        
        let draggedFileName = draggedFilePath.substring(draggedFilePath.lastIndexOf('/') + 1);

        let maxCol = Math.max(0, Math.floor(gridArea.width / cellWidth) - 1);
        let maxRow = Math.max(0, Math.floor(gridArea.height / cellHeight) - 1);
        gridX = Math.max(0, Math.min(gridX, maxCol));
        gridY = Math.max(0, Math.min(gridY, maxRow));

        let layout = Object.assign({}, iconLayout);

        let oldX = layout[draggedFileName] ? layout[draggedFileName].x : 0;
        let oldY = layout[draggedFileName] ? layout[draggedFileName].y : 0;
        let deltaX = gridX - oldX;
        let deltaY = gridY - oldY;

        if (deltaX !== 0 || deltaY !== 0) {
            let selectedNames = selectedIcons.map(path => path.substring(path.lastIndexOf('/') + 1));
            let movingFiles = [];
            for (let i = 0; i < selectedNames.length; i++) {
                let name = selectedNames[i];
                if (layout[name]) {
                    movingFiles.push({ name: name, x: layout[name].x, y: layout[name].y });
                    delete layout[name]; 
                }
            }

            for (let i = 0; i < movingFiles.length; i++) {
                let file = movingFiles[i];
                let targetX = Math.max(0, Math.min(file.x + deltaX, maxCol));
                let targetY = Math.max(0, Math.min(file.y + deltaY, maxRow));

                let collision = false;
                for (let existingFile in layout) {
                    if (layout[existingFile].x === targetX && layout[existingFile].y === targetY) {
                        collision = true; break;
                    }
                }

                if (collision) {
                    layout[file.name] = getEmptySpot(layout);
                } else {
                    layout[file.name] = { x: targetX, y: targetY };
                }
            }
        }

        let visuals = [];
        for (let i = 0; i < gridArea.children.length; i++) {
            let child = gridArea.children[i];
            if (child.filePath && root.selectedIcons.indexOf(child.filePath) !== -1) {
                let offsetX = (root.dragLeader === child.filePath) ? child.getDragX() : root.groupDragX;
                let offsetY = (root.dragLeader === child.filePath) ? child.getDragY() : root.groupDragY;
                visuals.push({
                    childRef: child,
                    absX: child.x + offsetX,
                    absY: child.y + offsetY
                });
            }
        }

        iconLayout = layout; 
        if (deltaX !== 0 || deltaY !== 0) saveLayout();

        for (let i = 0; i < visuals.length; i++) {
            visuals[i].childRef.compensateAndSnap(visuals[i].absX, visuals[i].absY);
        }

        root.dragLeader = "";
        root.groupDragX = 0;
        root.groupDragY = 0;
        root.isMassDropping = false;
    }

    function getEmptySpot(layout) {
        let safeW = gridArea.width > 0 ? gridArea.width : Screen.width - 40;
        let safeH = gridArea.height > 0 ? gridArea.height : Screen.height - 60;
        
        let maxCol = Math.max(1, Math.floor(safeW / cellWidth));
        let maxRow = Math.max(1, Math.floor(safeH / cellHeight));
        
        for (let x = 0; x < maxCol; x++) {
            for (let y = 0; y < maxRow; y++) {
                let taken = false;
                for (let file in layout) {
                    if (layout[file].x === x && layout[file].y === y) {
                        taken = true; break;
                    }
                }
                if (!taken) return { x: x, y: y };
            }
        }
        return { x: maxCol - 1, y: maxRow - 1 };
    }

    function renameIconInLayout(oldName, newName) {
        if (iconLayout[oldName]) {
            let layout = Object.assign({}, iconLayout);
            layout[newName] = layout[oldName];
            delete layout[oldName];
            iconLayout = layout;
            saveLayout();
        }
    }

    function registerNewIcon(fileName) {
        if (layoutLoaded && !iconLayout[fileName]) {
            let layout = Object.assign({}, iconLayout);
            layout[fileName] = getEmptySpot(layout);
            iconLayout = layout;
            saveLayout();
        }
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
                lasso.x = Math.min(mouse.x, root.startX)
                lasso.y = Math.min(mouse.y, root.startY)
                lasso.width = Math.abs(mouse.x - root.startX)
                lasso.height = Math.abs(mouse.y - root.startY)
                
                let newSelection = []
                
                for (let i = 0; i < gridArea.children.length; i++) {
                    let child = gridArea.children[i]
                    
                    if (child.filePath !== undefined) {
                        let iconX = gridArea.x + child.x
                        let iconY = gridArea.y + child.y
                        
                        if (iconX < lasso.x + lasso.width && iconX + child.width > lasso.x &&
                            iconY < lasso.y + lasso.height && iconY + child.height > lasso.y) {
                            
                            newSelection.push(child.filePath)
                        }
                    }
                }
                
                root.selectedIcons = newSelection
            }
        }
        
        onReleased: {
            lasso.visible = false
        }
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_F2 && selectedIcons.length > 0) editingFilePath = selectedIcons[0]
    }

    FolderListModel {
        id: folderModel
        folder: Directories.desktop
        showDotAndDotDot: false
        nameFilters: ["*"] 
    }

    Item {
        id: gridArea
        visible: Config.options.background.showDesktopIcons
        anchors.fill: parent
        anchors.margins: 20
        anchors.topMargin: 40

        Repeater {
            model: folderModel
            delegate: DesktopIconDelegate {}
        }
    }

    DesktopIconContextMenu {
        id: desktopMenu
        onOpenFileRequested: (path, isDir) => root.exec(path, isDir)
        onRenameRequested: (path) => { root.editingFilePath = path }
    }

    BackgroundContextMenu {
        id: bgContextMenu
    }
}