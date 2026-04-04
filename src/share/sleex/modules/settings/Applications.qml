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
    id: root
    forceWidth: true

    property var browserApps: []
    property var fileManagerApps: []
    property var imageViewerApps: []
    property var videoPlayerApps: []
    property var documentViewerApps: []

    Process {
        id: mimeScanner
        running: true
        command: ["sh", "-c", `
            scan() {
                tag=$1; pattern=$2
                echo "TAG:$tag"
                grep -l "$pattern" /usr/share/applications/*.desktop | xargs -I {} sh -c 'printf "%s|%s\\n" "$(grep -m1 "^Name=" "{}" | cut -d= -f2-)" "$(basename "{}")"'
            }
            scan "BROWSER" "x-scheme-handler/http"
            scan "FILE" "inode/directory"
            scan "IMAGE" "image/"
            scan "VIDEO" "video/"
            scan "DOCUMENT" "vnd.openxmlformats-officedocument.wordprocessingml.document"
        `]

        stdout: StdioCollector{
            onStreamFinished: {
                let lines = text.trim().split("\n");
                let currentCat = "";
                let temp = { BROWSER: [], FILE: [], IMAGE: [], VIDEO: [], DOCUMENT: []};

                lines.forEach(line => {
                    if (line.startsWith("TAG:")) {
                        currentCat = line.split(":")[1];
                    } else if (line.includes("|")) {
                        let parts = line.split("|");
                        if (parts[0] && parts[1]) {
                            temp[currentCat].push({ name: parts[0], value: parts[1] });
                        }
                    }
                });

                const sortFn = (a, b) => a.name.localeCompare(b.name);
                root.browserApps = temp.BROWSER.sort(sortFn);
                root.fileManagerApps = temp.FILE.sort(sortFn);
                root.imageViewerApps = temp.IMAGE.sort(sortFn);
                root.videoPlayerApps = temp.VIDEO.sort(sortFn);
                root.documentViewerApps = temp.DOCUMENT.sort(sortFn);
            }
        }
    }

    function getAppValue(array, index) {
        if (array && index >= 0 && index < array.length) {
            return array[index].value;
        }
        return "";
    }

    ContentSection {
        title: "Default Applications"

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 20
            Layout.topMargin: 10
            Layout.bottomMargin: 10

            StyledText {
                text: "Web Browser"
                color: Appearance.colors.colSubtext
            }

            StyledComboBox {
                id: browserComboBox
                Layout.fillWidth: true
                model: browserApps.map(app => app.name)
                currentIndex: Math.max(0, browserApps.findIndex(app => app.value === Config.options.apps.browser))

                onActivated: (index) => {
                    let desktopFile = getAppValue(root.browserApps, index);
                    
                    Config.options.apps.webBrowser = desktopFile
                    Quickshell.execDetached(["xdg-mime", "default", desktopFile, "x-scheme-handler/http", "x-scheme-handler/https"])
                }
            }

            StyledText {
                text: "File Manager"
                color: Appearance.colors.colSubtext
            }

            StyledComboBox {
                id: fileManagerComboBox
                Layout.fillWidth: true
                model: fileManagerApps.map(app => app.name)
                currentIndex: Math.max(0, fileManagerApps.findIndex(app => app.value === Config.options.apps.fileManager))

                onActivated: (index) => {
                    let desktopFile = getAppValue(root.fileManagerApps, index);

                    Config.options.apps.fileManager = desktopFile
                    Quickshell.execDetached(["xdg-mime", "default", desktopFile, "inode/directory"])
                }
            }

            StyledText {
                text: "Image Viewer"
                color: Appearance.colors.colSubtext
            }

            StyledComboBox {
                id: imageViewerComboBox
                Layout.fillWidth: true
                model: imageViewerApps.map(app => app.name)
                currentIndex: Math.max(0, imageViewerApps.findIndex(app => app.value === Config.options.apps.imageViewer))

                onActivated: (index) => {
                    let desktopFile = getAppValue(root.imageViewerApps, index);

                    Config.options.apps.imageViewer = desktopFile
                    Quickshell.execDetached(["xdg-mime", "default", desktopFile, "image/png", "image/jpeg", "image/gif", "image/webp", "image/svg+xml", "image/bmp"])
                }
            }

            StyledText {
                text: "Video Player"
                color: Appearance.colors.colSubtext
            }

            StyledComboBox {
                id: videoPlayerComboBox
                Layout.fillWidth: true
                model: videoPlayerApps.map(app => app.name)
                currentIndex: Math.max(0, videoPlayerApps.findIndex(app => app.value === Config.options.apps.videoPlayer))

                onActivated: (index) => {
                    let desktopFile = getAppValue(root.videoPlayerApps, index);

                    Config.options.apps.videoPlayer = desktopFile
                    Quickshell.execDetached(["xdg-mime", "default", desktopFile, "video/mp4", "video/mkv", "video/webm", "video/avi", "video/x-matroska"])
                }
            }

            StyledText {
                text: "Document Viewer"
                color: Appearance.colors.colSubtext
            }

            StyledComboBox {
                id: documentViewerComboBox
                Layout.fillWidth: true
                model: documentViewerApps.map(app => app.name)
                currentIndex: Math.max(0, documentViewerApps.findIndex(app => app.value === Config.options.apps.documentViewer))

                onActivated: (index) => {
                    let desktopFile = getAppValue(root.documentViewerApps, index);

                    Config.options.apps.documentViewer = desktopFile
                    Quickshell.execDetached(["xdg-mime", "default", desktopFile, "application/pdf", "application/vnd.openxmlformats-officedocument.wordprocessingml.document", "application/msword", "application/vnd.oasis.opendocument.text", "application/vnd.ms-excel", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "application/vnd.oasis.opendocument.spreadsheet", "application/vnd.ms-powerpoint", "application/vnd.openxmlformats-officedocument.presentationml.presentation", "application/vnd.oasis.opendocument.presentation"])
                }
            }
        }
    }
}