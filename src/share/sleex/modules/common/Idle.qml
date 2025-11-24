pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property alias hypnos: hypnosJsonAdapter
    property string fileDir: Directories.shellConfig
    property string fileName: "hypnos.json"
    property string filePath: `${root.fileDir}/${root.fileName}`
    property bool ready: false
    property int readWriteTimer: 50

    Timer {
        id: fileReloadTimer
        interval: root.readWriteTimer
        repeat: false
        onTriggered: {
            hypnosFileView.reload();
        }
    }

    Timer {
        id: fileWriteTimer
        interval: root.readWriteTimer
        repeat: false
        onTriggered: {
            hypnosFileView.writeAdapter();
        }
    }

    function init() {
        hypnosFileView.reload();
    }


    FileView {
        id: hypnosFileView
        path: root.filePath

        watchChanges: true
        onFileChanged: fileReloadTimer.restart()
        onAdapterUpdated: fileWriteTimer.restart()
        onLoaded: root.ready = true
        onLoadFailed: error => {
            console.log("Failed to load Hypnos settings file:", error);
            if (error == FileViewError.FileNotFound) {
                writeAdapter();
            }
        }

        adapter: JsonAdapter {
            id: hypnosJsonAdapter
            property bool enabled: true
            property JsonObject rules: JsonObject {
                property JsonObject dim: JsonObject {
                    property int timeout: 60
                    property string actions: "brightnessctl -s set 10"
                    property string restore: "brightnessctl -r"
                    property bool on_battery: true
                    property bool enabled: true
                }
                property JsonObject lock: JsonObject {
                    property int timeout: 120
                    property string actions: "loginctl lock-session"
                    property bool on_battery: false
                    property bool enabled: true
                }
                property JsonObject suspend: JsonObject {
                    property int timeout: 300
                    property string actions: "systemctl suspend"
                    property bool on_battery: true
                    property bool enabled: true
                }
            }
        }
    }
}