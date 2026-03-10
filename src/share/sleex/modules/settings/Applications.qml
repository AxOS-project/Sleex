import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    forceWidth: true

    ContentSection {
        title: "Default Applications"

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 20
            Layout.topMargin: 10
            Layout.bottomMargin: 10

            MaterialTextField {
                id: browserField
                placeholderText: "Web Browser"
                text: Config.options.apps.webBrowser
                Layout.fillWidth: true
                onTextChanged: {
                    Config.options.apps.webBrowser = text
                }
            }

            MaterialTextField {
                id: terminalField
                placeholderText: "Terminal Emulator"
                text: Config.options.apps.terminal
                Layout.fillWidth: true
                onTextChanged: {
                    Config.options.apps.terminal = text
                }
            }

            MaterialTextField {
                id: fileManagerField
                placeholderText: "File Manager"
                text: Config.options.apps.fileManager
                Layout.fillWidth: true
                onTextChanged: {
                    Config.options.apps.fileManager = text
                }
            }

            MaterialTextField {
                id: imageViewerField
                placeholderText: "Image Viewer"
                text: Config.options.apps.imageViewer
                Layout.fillWidth: true
                onTextChanged: {
                    Config.options.apps.imageViewer = text
                }
            }

            MaterialTextField {
                id: videoPlayerField
                placeholderText: "Video Player"
                text: Config.options.apps.videoPlayer
                Layout.fillWidth: true
                onTextChanged: {
                    Config.options.apps.videoPlayer = text
                }
            }

            MaterialTextField {
                id: taskManagerField
                placeholderText: "Task Manager"
                text: Config.options.apps.taskManager
                Layout.fillWidth: true
                onTextChanged: {
                    Config.options.apps.taskManager = text
                }
            }

            MaterialTextField {
                id: archiveManagerField
                placeholderText: "Archive Manager"
                text: Config.options.apps.archiveManager
                Layout.fillWidth: true
                onTextChanged: {
                    Config.options.apps.archiveManager = text
                }
            }
        }
    }
}