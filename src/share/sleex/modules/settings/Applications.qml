import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.services
import qs.modules.common
import SleexUiKit.Widgets
import SleexUiKit.Appearance

ContentPage {
    id: root
    // forceWidth: true

    property var browserApps: []
    property var fileManagerApps: []
    property var imageViewerApps: []
    property var videoPlayerApps: []
    property var musicPlayerApps: []
    property var documentViewerApps: []

    property bool scanFinished: false

    Process {
        id: mimeScanner
        running: true
        command: ["sh", "-c", `
            PATHS="$HOME/.local/share/applications/*.desktop $HOME/.local/share/flatpak/exports/share/applications/*.desktop /var/lib/flatpak/exports/share/applications/*.desktop /usr/local/share/applications/*.desktop /usr/share/applications/*.desktop"
            seen=""
            for file in $PATHS; do
                [ -f "$file" ] || continue
                b=$(basename "$file")
                case "$seen" in *"|$b|"*) continue;; esac
                seen="$seen|$b|"
                awk -v b="$b" '
                    /^Name=/ && !name { name=$0; sub(/^Name=/, "", name) }
                    /^Icon=/ && !icon { icon=$0; sub(/^Icon=/, "", icon) }
                    /^MimeType=/ && !mime { mime=$0; sub(/^MimeType=/, "", mime) }
                    END { printf "%s|%s|%s|%s\\n", name, b, icon, mime }
                ' "$file"
            done
        `]

        stdout: StdioCollector{
            onStreamFinished: {
                const patterns = {
                    BROWSER: /x-scheme-handler\/http/,
                    FILE: /inode\/directory/,
                    IMAGE: /image\//,
                    VIDEO: /video\//,
                    MUSIC: /audio\//,
                    DOCUMENT: /application\/(pdf|vnd\.openxmlformats|vnd\.oasis)/
                };
                let temp = { BROWSER: [], FILE: [], IMAGE: [], VIDEO: [], MUSIC: [], DOCUMENT: [] };

                text.trim().split("\n").forEach(line => {
                    if (!line) return;
                    const parts = line.split("|");
                    if (parts.length < 4) return;
                    const name = parts[0];
                    const value = parts[1];
                    const icon = parts[2];
                    const mime = parts.slice(3).join("|");
                    if (!name || !value) return;

                    for (const cat in patterns) {
                        if (patterns[cat].test(mime)) {
                            temp[cat].push({ name, value, icon: icon ?? "" });
                        }
                    }
                });

                const sortFn = (a, b) => a.name.localeCompare(b.name);
                root.browserApps = temp.BROWSER.sort(sortFn);
                root.fileManagerApps = temp.FILE.sort(sortFn);
                root.imageViewerApps = temp.IMAGE.sort(sortFn);
                root.videoPlayerApps = temp.VIDEO.sort(sortFn);
                root.musicPlayerApps = temp.MUSIC.sort(sortFn);
                root.documentViewerApps = temp.DOCUMENT.sort(sortFn);
                root.scanFinished = true;
            }
        }
    }

    function appIcon(app) {
        if (!app) return "image-missing";
        if (app.icon && app.icon.length > 0 && Quickshell.iconPath(app.icon, true).length > 0 && !app.icon.includes("image-missing"))
            return app.icon;
        const entry = DesktopEntries.byId(String(app.value).replace(/\.desktop$/, ""));
        if (entry && entry.icon && Quickshell.iconPath(entry.icon, true).length > 0 && !entry.icon.includes("image-missing"))
            return entry.icon;
        return "image-missing";
    }

    function defaultAppEntry(currentValue) {
        if (!currentValue) return null;
        return DesktopEntries.byId(String(currentValue).replace(/\.desktop$/, ""));
    }

    function defaultAppName(currentValue) {
        if (!currentValue) return "None";
        const entry = root.defaultAppEntry(currentValue);
        if (entry && entry.name) return entry.name;
        return String(currentValue).replace(/\.desktop$/, "");
    }

    function defaultAppIcon(currentValue) {
        const entry = root.defaultAppEntry(currentValue);
        if (entry && entry.icon && Quickshell.iconPath(entry.icon, true).length > 0)
            return entry.icon;
        return "image-missing";
    }

    function setDefault(configKey, mimetypes, desktopFile) {
        Config.options.apps[configKey] = desktopFile;
        Quickshell.execDetached(["xdg-mime", "default", desktopFile].concat(mimetypes));
    }

    Component {
        id: appPicker

        ColumnLayout {
            id: pickerRoot
            anchors.fill: parent

            property string title
            property string subtitle
            property string materialIcon
            property string configKey
            property var apps: []
            property string currentValue: ""
            property var mimetypes: []
            property bool expanded: false

            spacing: 8

            // Clickable category header — click to expand/collapse the section.
            // Sections start minimised so the icon scan has time to finish
            // loading everything before the cards are revealed.
            MouseArea {
                id: headerArea
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                cursorShape: Qt.PointingHandCursor
                onClicked: pickerRoot.expanded = !pickerRoot.expanded

                RowLayout {
                    anchors.fill: parent
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        radius: Appearance.rounding.small
                        color: Appearance.colors.colLayer2

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: pickerRoot.materialIcon
                            iconSize: 22
                            color: Appearance.colors.colPrimary
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: pickerRoot.title
                            font.pixelSize: Appearance.font.pixelSize.larger
                            font.weight: Font.Medium
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: pickerRoot.subtitle
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                    }

                }
            }

            // App cards
            Flow {
                Layout.fillWidth: true
                spacing: 10
                visible: pickerRoot.apps.length > 0 && pickerRoot.expanded
                opacity: (pickerRoot.apps.length > 0 && root.scanFinished && pickerRoot.expanded) ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                Repeater {
                    model: pickerRoot.apps

                    delegate: Rectangle {
                        id: card
                        required property var modelData

                        property bool selected: pickerRoot.currentValue === card.modelData.value
                        property bool cardHovered: cardMouseArea.containsMouse

                        width: 150
                        height: 110
                        radius: Appearance.rounding.normal
                        scale: cardMouseArea.pressed ? 0.95 : 1.0

                        color: card.selected ? Appearance.colors.colPrimaryContainer :
                               card.cardHovered ? Appearance.colors.colLayer2 :
                               Appearance.colors.colLayer1
                        border.color: card.selected ? Appearance.colors.colPrimary : "transparent"
                        border.width: 1.5

                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                        // Selection badge
                        Rectangle {
                            visible: card.selected
                            anchors { top: parent.top; right: parent.right; topMargin: 7; rightMargin: 7 }
                            width: 24
                            height: 24
                            radius: 12
                            color: Appearance.colors.colPrimary

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "check"
                                iconSize: 16
                                color: Appearance.colors.colOnPrimary
                            }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 8

                            IconImage {
                                Layout.preferredWidth: 46
                                Layout.preferredHeight: 46
                                Layout.alignment: Qt.AlignHCenter
                                asynchronous: false
                                source: Quickshell.iconPath(root.appIcon(card.modelData), "image-missing")
                            }

                            StyledText {
                                text: card.modelData.name
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: card.selected ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer1
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                Layout.maximumWidth: 138
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }

                        MouseArea {
                            id: cardMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setDefault(pickerRoot.configKey, pickerRoot.mimetypes, card.modelData.value)
                        }
                    }
                }
            }

            // Empty state
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: emptyText.implicitHeight + 4
                visible: pickerRoot.apps.length === 0 && root.scanFinished && pickerRoot.expanded

                StyledText {
                    id: emptyText
                    anchors.centerIn: parent
                    text: "No applications found for this category"
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }
            }
        }
    }

    ContentSection {
        title: "Default Applications"
        icon: "apps"

        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: 6
            Layout.bottomMargin: 6
            spacing: 28

            StyledText {
                text: "Choose which app opens each type of content. Click a card to set it as the default."
                Layout.fillWidth: true
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                wrapMode: Text.Wrap
            }

            Loader {
                id: browserPicker
                Layout.fillWidth: true
                active: true
                sourceComponent: appPicker
                Binding { target: browserPicker.item; property: "title"; value: "Web Browser" }
                Binding { target: browserPicker.item; property: "subtitle"; value: "Opens links and web pages" }
                Binding { target: browserPicker.item; property: "materialIcon"; value: "language" }
                Binding { target: browserPicker.item; property: "configKey"; value: "webBrowser" }
                Binding { target: browserPicker.item; property: "apps"; value: root.browserApps }
                Binding { target: browserPicker.item; property: "currentValue"; value: Config.options.apps.webBrowser }
                Binding { target: browserPicker.item; property: "mimetypes"; value: ["x-scheme-handler/http", "x-scheme-handler/https"] }
            }

            Loader {
                id: fileManagerPicker
                Layout.fillWidth: true
                active: true
                sourceComponent: appPicker
                Binding { target: fileManagerPicker.item; property: "title"; value: "File Manager" }
                Binding { target: fileManagerPicker.item; property: "subtitle"; value: "Opens folders and directories" }
                Binding { target: fileManagerPicker.item; property: "materialIcon"; value: "folder_open" }
                Binding { target: fileManagerPicker.item; property: "configKey"; value: "fileManager" }
                Binding { target: fileManagerPicker.item; property: "apps"; value: root.fileManagerApps }
                Binding { target: fileManagerPicker.item; property: "currentValue"; value: Config.options.apps.fileManager }
                Binding { target: fileManagerPicker.item; property: "mimetypes"; value: ["inode/directory"] }
            }

            Loader {
                id: imageViewerPicker
                Layout.fillWidth: true
                active: true
                sourceComponent: appPicker
                Binding { target: imageViewerPicker.item; property: "title"; value: "Image Viewer" }
                Binding { target: imageViewerPicker.item; property: "subtitle"; value: "Opens pictures and images" }
                Binding { target: imageViewerPicker.item; property: "materialIcon"; value: "image" }
                Binding { target: imageViewerPicker.item; property: "configKey"; value: "imageViewer" }
                Binding { target: imageViewerPicker.item; property: "apps"; value: root.imageViewerApps }
                Binding { target: imageViewerPicker.item; property: "currentValue"; value: Config.options.apps.imageViewer }
                Binding { target: imageViewerPicker.item; property: "mimetypes"; value: ["image/png", "image/jpeg", "image/gif", "image/webp", "image/svg+xml", "image/bmp"] }
            }

            Loader {
                id: videoPlayerPicker
                Layout.fillWidth: true
                active: true
                sourceComponent: appPicker
                Binding { target: videoPlayerPicker.item; property: "title"; value: "Video Player" }
                Binding { target: videoPlayerPicker.item; property: "subtitle"; value: "Opens videos and movies" }
                Binding { target: videoPlayerPicker.item; property: "materialIcon"; value: "movie" }
                Binding { target: videoPlayerPicker.item; property: "configKey"; value: "videoPlayer" }
                Binding { target: videoPlayerPicker.item; property: "apps"; value: root.videoPlayerApps }
                Binding { target: videoPlayerPicker.item; property: "currentValue"; value: Config.options.apps.videoPlayer }
                Binding { target: videoPlayerPicker.item; property: "mimetypes"; value: ["video/mp4", "video/mkv", "video/webm", "video/avi", "video/x-matroska"] }
            }

            Loader {
                id: musicPlayerPicker
                Layout.fillWidth: true
                active: true
                sourceComponent: appPicker
                Binding { target: musicPlayerPicker.item; property: "title"; value: "Music Player" }
                Binding { target: musicPlayerPicker.item; property: "subtitle"; value: "Plays music and audio files" }
                Binding { target: musicPlayerPicker.item; property: "materialIcon"; value: "music_note" }
                Binding { target: musicPlayerPicker.item; property: "configKey"; value: "musicPlayer" }
                Binding { target: musicPlayerPicker.item; property: "apps"; value: root.musicPlayerApps }
                Binding { target: musicPlayerPicker.item; property: "currentValue"; value: Config.options.apps.musicPlayer }
                Binding { target: musicPlayerPicker.item; property: "mimetypes"; value: ["audio/mpeg", "audio/mp3", "audio/flac", "audio/ogg", "audio/x-flac", "audio/x-wav", "audio/wav", "audio/aac", "audio/x-m4a", "audio/mp4"] }
            }

            Loader {
                id: documentViewerPicker
                Layout.fillWidth: true
                active: true
                sourceComponent: appPicker
                Binding { target: documentViewerPicker.item; property: "title"; value: "Document Viewer" }
                Binding { target: documentViewerPicker.item; property: "subtitle"; value: "Opens PDFs and office documents" }
                Binding { target: documentViewerPicker.item; property: "materialIcon"; value: "description" }
                Binding { target: documentViewerPicker.item; property: "configKey"; value: "documentViewer" }
                Binding { target: documentViewerPicker.item; property: "apps"; value: root.documentViewerApps }
                Binding { target: documentViewerPicker.item; property: "currentValue"; value: Config.options.apps.documentViewer }
                Binding { target: documentViewerPicker.item; property: "mimetypes"; value: ["application/pdf", "application/vnd.openxmlformats-officedocument.wordprocessingml.document", "application/msword", "application/vnd.oasis.opendocument.text", "application/vnd.ms-excel", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "application/vnd.oasis.opendocument.spreadsheet", "application/vnd.ms-powerpoint", "application/vnd.openxmlformats-officedocument.presentationml.presentation", "application/vnd.oasis.opendocument.presentation"] }
            }
        }
    }
}
