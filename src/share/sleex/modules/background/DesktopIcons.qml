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
    
    property string selectedIcon: ""
    property string editingFilePath: ""
    property var contextMenu: desktopMenu

    property var iconLayout: ({})
    property bool layoutLoaded: false

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

    function handleDrop(fileName, gridX, gridY) {
        let maxCol = Math.max(0, Math.floor(gridArea.width / cellWidth) - 1);
        let maxRow = Math.max(0, Math.floor(gridArea.height / cellHeight) - 1);
        gridX = Math.max(0, Math.min(gridX, maxCol));
        gridY = Math.max(0, Math.min(gridY, maxRow));

        let layout = Object.assign({}, iconLayout);

        let existingFile = null;
        for (let file in layout) {
            if (file !== fileName && layout[file].x === gridX && layout[file].y === gridY) {
                existingFile = file;
                break;
            }
        }

        let oldX = layout[fileName] ? layout[fileName].x : 0;
        let oldY = layout[fileName] ? layout[fileName].y : 0;

        layout[fileName] = { x: gridX, y: gridY };

        if (existingFile) {
            layout[existingFile] = { x: oldX, y: oldY };
        }

        iconLayout = layout;
        saveLayout();
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

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: (mouse) => {
            root.selectedIcon = ""
            desktopMenu.close()
            root.editingFilePath = ""
            
            if (mouse.button === Qt.RightButton) {
                bgContextMenu.openAt(mouse.x, mouse.y, root.width, root.height)
            } else {
                bgContextMenu.close()
            }
        }
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_F2 && selectedIcon !== "") {
            editingFilePath = selectedIcon
            event.accepted = true
        }
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