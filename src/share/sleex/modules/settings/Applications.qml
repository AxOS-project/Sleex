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

    readonly property var kinds: ({
        webBrowser:     ["x-scheme-handler/http", "x-scheme-handler/https", "text/html"],
        fileManager:    ["inode/directory"],
        imageViewer:    ["image/png", "image/jpeg", "image/gif", "image/webp", "image/svg+xml", "image/bmp"],
        videoPlayer:    ["video/mp4", "video/mkv", "video/webm", "video/avi", "video/x-matroska"],
        musicPlayer:    ["audio/mpeg", "audio/mp3", "audio/flac", "audio/ogg", "audio/x-flac", "audio/x-wav", "audio/wav", "audio/aac", "audio/x-m4a", "audio/mp4"],
        documentViewer: [
            "application/pdf",
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "application/msword",
            "application/vnd.oasis.opendocument.text",
            "application/vnd.ms-excel",
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "application/vnd.oasis.opendocument.spreadsheet",
            "application/vnd.ms-powerpoint",
            "application/vnd.openxmlformats-officedocument.presentationml.presentation",
            "application/vnd.oasis.opendocument.presentation"
        ]
    })

    property var currentDefaults: ({})
    property var offeredByMime: ({})
    property bool scanFinished: false

    function entryFor(desktopId) {
        if (!desktopId) return null;
        const shortId = desktopId.replace(/\.desktop$/, "");
        return DesktopEntries.byId(shortId)
            ?? DesktopEntries.applications.values.find(a => a.id === shortId)
            ?? null;
    }

    function appItemsFor(kind) {
        const primaryMime = kinds[kind][0];
        const rawIds = (offeredByMime[primaryMime] ?? []).slice();
        const cur = currentDefaults[kind] || Config.options.apps[kind] || "";
        if (cur && !rawIds.includes(cur))
            rawIds.unshift(cur);

        const seen = new Set();
        const items = [];

        for (const id of rawIds) {
            if (!id || seen.has(id)) continue;
            seen.add(id);

            const entry = entryFor(id);
            if (entry && entry.noDisplay) continue;

            const name = entry?.name ?? id.replace(/\.desktop$/, "");
            const iconSource = entry?.icon
                ? Quickshell.iconPath(entry.icon, "image-missing")
                : Quickshell.iconPath("image-missing");

            items.push({ id, name, iconSource });
        }

        // Keep the active default first, sort the rest alphabetically
        return items.sort((a, b) => {
            if (a.id === cur) return -1;
            if (b.id === cur) return 1;
            return a.name.localeCompare(b.name);
        });
    }

    function setDefault(kind, desktopId) {
        const next = Object.assign({}, currentDefaults);
        next[kind] = desktopId;
        currentDefaults = next;
        Config.options.apps[kind] = desktopId;
        Quickshell.execDetached(["xdg-mime", "default", desktopId].concat(kinds[kind]));
    }

    Process {
        id: reader
        running: true
        command: [
            "sh", "-c",
            `for k in "$@"; do
                printf "default %s %s\\n" "\${k%%=*}" "$(xdg-mime query default "\${k#*=}" 2>/dev/null)"
            done
            cat /usr/share/applications/mimeinfo.cache \\
                /usr/local/share/applications/mimeinfo.cache \\
                /var/lib/flatpak/exports/share/applications/mimeinfo.cache \\
                "$HOME/.local/share/flatpak/exports/share/applications/mimeinfo.cache" \\
                "$HOME/.local/share/applications/mimeinfo.cache" 2>/dev/null`,
            "sh"
        ].concat(Object.keys(root.kinds).map(k => k + "=" + root.kinds[k][0]))

        stdout: StdioCollector {
            onStreamFinished: {
                const cur = {};
                const off = {};

                for (const line of text.split("\n")) {
                    const defMatch = line.match(/^default (\w+) ?(.*)$/);
                    if (defMatch) {
                        cur[defMatch[1]] = defMatch[2].trim();
                        continue;
                    }
                    const eq = line.indexOf("=");
                    if (eq > 0 && !line.startsWith("[")) {
                        const mime = line.slice(0, eq).trim();
                        const apps = line.slice(eq + 1).split(";").filter(Boolean);
                        if (!off[mime]) off[mime] = [];
                        for (const app of apps) {
                            if (!off[mime].includes(app)) off[mime].push(app);
                        }
                    }
                }

                root.currentDefaults = cur;
                root.offeredByMime = off;
                root.scanFinished = true;
            }
        }
    }

    component AppPicker: ColumnLayout {
        id: pickerRoot

        property string title
        property string subtitle
        property string materialIcon
        property string kind
        property bool expanded: false

        readonly property var apps: root.scanFinished ? root.appItemsFor(kind) : []
        readonly property string activeId: root.currentDefaults[kind] || Config.options.apps[kind] || ""

        Layout.fillWidth: true
        spacing: 8

        MouseArea {
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

        Flow {
            Layout.fillWidth: true
            spacing: 10
            visible: pickerRoot.expanded && pickerRoot.apps.length > 0

            Repeater {
                model: pickerRoot.expanded ? pickerRoot.apps : []

                delegate: Rectangle {
                    id: card
                    required property var modelData

                    readonly property bool selected: pickerRoot.activeId === modelData.id
                    readonly property bool cardHovered: cardMouseArea.containsMouse

                    width: 150
                    height: 110
                    radius: Appearance.rounding.normal
                    scale: cardMouseArea.pressed ? 0.95 : 1.0

                    color: selected ? Appearance.colors.colPrimaryContainer :
                           cardHovered ? Appearance.colors.colLayer2 :
                           Appearance.colors.colLayer1
                    border.color: selected ? Appearance.colors.colPrimary : "transparent"
                    border.width: 1.5

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

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
                            asynchronous: true
                            source: card.modelData.iconSource
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
                        onClicked: root.setDefault(pickerRoot.kind, card.modelData.id)
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: emptyText.implicitHeight + 4
            visible: pickerRoot.expanded && root.scanFinished && pickerRoot.apps.length === 0

            StyledText {
                id: emptyText
                anchors.centerIn: parent
                text: "No applications found for this category"
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
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

            AppPicker { title: "Web Browser"; subtitle: "Opens links and web pages"; materialIcon: "language"; kind: "webBrowser" }
            AppPicker { title: "File Manager"; subtitle: "Opens folders and directories"; materialIcon: "folder_open"; kind: "fileManager" }
            AppPicker { title: "Image Viewer"; subtitle: "Opens pictures and images"; materialIcon: "image"; kind: "imageViewer" }
            AppPicker { title: "Video Player"; subtitle: "Opens videos and movies"; materialIcon: "movie"; kind: "videoPlayer" }
            AppPicker { title: "Music Player"; subtitle: "Plays music and audio files"; materialIcon: "music_note"; kind: "musicPlayer" }
            AppPicker { title: "Document Viewer"; subtitle: "Opens PDFs and office documents"; materialIcon: "description"; kind: "documentViewer" }
        }
    }
}