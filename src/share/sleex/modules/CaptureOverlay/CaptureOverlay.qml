import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import qs.modules.common
import SleexUiKit.Functions
import SleexUiKit.Widgets
import SleexUiKit.Appearance

Scope {
    id: scopeRoot

    property bool pendingEditDefault: false
    property bool pendingOcrMode: false
    property bool isOverlayOpen: false

    // ---- State/run dir helpers ----
    readonly property string qsHome: Quickshell.env("HOME")
    readonly property string qsRuntimeDir: Quickshell.env("XDG_RUNTIME_DIR")
    readonly property string qsCacheDirBase: qsHome + "/.cache/quickshell"
    readonly property string qsStateDirBase: qsHome + "/.local/state/quickshell"
    readonly property string qsRunDirBase: (qsRuntimeDir !== "" ? qsRuntimeDir : "/tmp") + "/quickshell"

    function getCacheDir(widgetName) {
        var envPath = Quickshell.env("QS_CACHE_" + widgetName.toUpperCase());
        var finalPath = envPath ? envPath : (qsCacheDirBase + "/" + widgetName);
        Quickshell.execDetached(["mkdir", "-p", finalPath]);
        return finalPath;
    }
    function getStateDir(widgetName) {
        var envPath = Quickshell.env("QS_STATE_" + widgetName.toUpperCase());
        var finalPath = envPath ? envPath : (qsStateDirBase + "/" + widgetName);
        Quickshell.execDetached(["mkdir", "-p", finalPath]);
        return finalPath;
    }
    function getRunDir(widgetName) {
        var envPath = Quickshell.env("QS_RUN_" + widgetName.toUpperCase());
        var finalPath = envPath ? envPath : (qsRunDirBase + "/" + widgetName);
        Quickshell.execDetached(["mkdir", "-p", finalPath]);
        return finalPath;
    }
    // ---- Pre‑loaded state (video/audio) ----
    property string savedModeText: "false"
    property real savedDeskVol: 1.0
    property bool savedDeskMute: false
    property real savedMicVol: 1.0
    property bool savedMicMute: false
    property string savedMicDevice: ""
    property var savedMicList: []

    Process {
        id: stateLoader
        command: ["bash", "-c",
            "cat '" + scopeRoot.getCacheDir("screenshot") + "/video_mode' 2>/dev/null; echo '---'; " +
            "cat '" + scopeRoot.getStateDir("screenshot") + "/audio_prefs' 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                let parts = this.text.split("---");
                let modeStr = (parts[0] || "").trim();
                let audioStr = (parts[1] || "").trim();
                if (modeStr !== "") scopeRoot.savedModeText = modeStr;
                if (audioStr !== "") {
                    let a = audioStr.split(",");
                    if (a.length >= 5) {
                        scopeRoot.savedDeskVol = parseFloat(a[0]) || 1.0;
                        scopeRoot.savedDeskMute = a[1] === "true";
                        scopeRoot.savedMicVol = parseFloat(a[2]) || 1.0;
                        scopeRoot.savedMicMute = a[3] === "true";
                        scopeRoot.savedMicDevice = a.slice(4).join(",");
                    }
                }
            }
        }
    }

    Process {
        id: micListLoader
        command: ["pactl", "list", "sources"]
        stdout: StdioCollector {
            onStreamFinished: {
                let text = this.text || "";
                let blocks = text.split(/\n(?=Source #)/);
                let list = [];
                for (let block of blocks) {
                    let nameMatch = block.match(/Name:\s*(\S+)/);
                    if (!nameMatch) continue;
                    let name = nameMatch[1];
                    if (name.endsWith(".monitor")) continue;
                    let descMatch = block.match(/Description:\s*(.+)/);
                    let desc = descMatch ? descMatch[1].trim() : name;
                    list.push({ devName: name, devDesc: desc });
                }
                scopeRoot.savedMicList = list;
                if (scopeRoot.savedMicDevice === "" && list.length > 0) {
                    scopeRoot.savedMicDevice = list[0].devName;
                }
            }
        }
    }

    Component.onCompleted: {
        stateLoader.running = true
        micListLoader.running = true
    }

    // ---- Show / hide (never destroy) ----
    // The overlay is kept persistent by shell.qml; if a config reload
    // hasn't re-incubated it yet, force an async load instead.
    function showOverlay(editDefault, ocrMode) {
        scopeRoot.pendingEditDefault = editDefault || false
        scopeRoot.pendingOcrMode = ocrMode || false
        scopeRoot.isOverlayOpen = true

        let overlay = overlayLoader.item
        if (overlay) {
            overlay.visible = true
            overlay.resetToFullscreen(editDefault, ocrMode)
        } else {
            overlayLoader.active = false
            overlayLoader.loading = true
        }
    }

    function closeOverlay() {
        Quickshell.execDetached(["pkill", "-f", "hyprpicker"])
        scopeRoot.isOverlayOpen = false
        if (overlayLoader.active && overlayLoader.item) {
            overlayLoader.item.visible = false
        }
    }

    LazyLoader {
        id: overlayLoader

        PanelWindow {
            id: root
            color: "transparent"

            WlrLayershell.namespace: "qs-screenshot-overlay"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            exclusionMode: ExclusionMode.Ignore
            focusable: true

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            screen: {
                var mon = Hyprland.focusedMonitor;
                if (!mon) return Quickshell.screens[0];
                for (var i = 0; i < Quickshell.screens.length; i++) {
                    if (Quickshell.screens[i].name === mon.name) return Quickshell.screens[i];
                }
                return Quickshell.screens[0];
            }
            // width/height intentionally not set: the four anchors let Hyprland
            // stretch the layer surface to the output, and Quickshell reflects
            // that size back onto width/height.

            // ---- Reset geometry to fullscreen (used when reopening) ----
            function resetToFullscreen(editDefault, ocrMode) {
                root.resetState()

                root.isEditMode = editDefault || false;
                root.isOcrMode = ocrMode || false;
                root.isVideoMode = scopeRoot.savedModeText === "true";
                root.deskVol = scopeRoot.savedDeskVol;
                root.deskMute = scopeRoot.savedDeskMute;
                root.micVol = scopeRoot.savedMicVol;
                root.micMute = scopeRoot.savedMicMute;
                root.micDevice = scopeRoot.savedMicDevice;

                // Refresh mic list
                micModel.clear();
                for (let entry of scopeRoot.savedMicList) {
                    micModel.append(entry);
                }

                windowListReader.running = true;
            }

            function resetState() {
                root.blockAnimations = true;
                root.startX = 0;
                root.startY = 0;
                root.endX = root.screen.width;
                root.endY = root.screen.height;
                root.hasSelection = true;
                root.isMaximized = false;
                root.snapToWindowDisabled = false;
                root.showQrPopup = false;
                root.isScanningQr = false;
                root.showOcrPopup = false;
                root.isOcrRunning = false;
                root.blockAnimations = false;
            }

            // ---- Flag to block geometry animations during reset ----
            property bool blockAnimations: false

            // ---- Hide overlay without destroying ----
            // keepFrozen survives only for the capture path: hyprpicker's
            // frozen frame must persist until grim grabs it, then grimblast.sh
            // releases it. Every other closer unfreezes immediately.
            function hideOverlay(keepFrozen) {
                if (!keepFrozen)
                    Quickshell.execDetached(["pkill", "-f", "hyprpicker"]);
                root.visible = false;
                root.resetState();
                scopeRoot.isOverlayOpen = false;
            }

            // ---- Scaling ----
            property real uiScale: 1.0
            readonly property real baseScale: getScale(width, 1080.0, uiScale)

            function getScale(mw, mh, userScale) {
                if (mw <= 0 || mh <= 0) return 1.0;
                let rw = mw / 1920.0;
                let rh = mh / 1080.0;
                let r = Math.min(rw, rh);
                let bs = 1.0;
                if (r <= 1.0) {
                    bs = Math.max(0.35, Math.pow(r, 0.85));
                } else {
                    bs = Math.pow(r, 0.5);
                }
                return bs * userScale;
            }

            function s(val) {
                return Math.round(val * baseScale);
            }

            // ---- Theme ----
            // All colors are reactive Appearance.colors tokens; they follow
            // the active matugen palette via MaterialThemeLoader.

            // Snap-to-windows
            property var windowRects: []
            property bool snapToWindowDisabled: false

            Process {
                id: windowListReader
                command: ["hyprctl", "clients", "-j"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        try {
                            let clients = JSON.parse(this.text);
                            let rects = [];
                            let monitor = root.screen;
                            let monX = monitor.x;
                            let monY = monitor.y;
                            let monW = monitor.width;
                            let monH = monitor.height;

                            let workspaceId = Hyprland.focusedMonitor?.activeWorkspace?.id;
                            if (workspaceId === undefined) workspaceId = -1;

                            for (let c of clients) {
                                if (!c.at || !c.size) continue;
                                if (c.mapped === false) continue;
                                if (c.workspace?.id !== workspaceId) continue;

                                let gx = c.at[0];
                                let gy = c.at[1];
                                let gw = c.size[0];
                                let gh = c.size[1];

                                if (gx + gw <= monX || gx >= monX + monW ||
                                    gy + gh <= monY || gy >= monY + monH) continue;

                                let lx = Math.max(0, gx - monX);
                                let ly = Math.max(0, gy - monY);
                                let lw = Math.min(gw, monW - lx);
                                let lh = Math.min(gh, monH - ly);

                                rects.push({ x: lx, y: ly, w: lw, h: lh });
                            }
                            root.windowRects = rects;
                        } catch (e) {
                            root.windowRects = [];
                        }
                    }
                }
            }

            // Poll window rects only while visible and snap-to-windows is on
            Timer {
                interval: 150
                repeat: true
                running: root.visible && Config.options.display.snapToWindows
                triggeredOnStart: true
                onTriggered: windowListReader.running = true
            }

            function findHoveredWindow(mx, my) {
                for (let r of root.windowRects) {
                    if (mx >= r.x && mx <= r.x + r.w && my >= r.y && my <= r.y + r.h) {
                        return r;
                    }
                }
                return null;
            }

            property color accentColor: Appearance.colors.colPrimary
            property color dangerColor: Appearance.colors.colError
            property color successColor: Appearance.colors.colTertiary
            property color dimColor: Appearance.colors.colScrim
            property color selectionTint: Qt.alpha(Appearance.colors.colPrimaryContainer, 0.45)
            property color handleColor: Appearance.colors.colSurfaceContainerHigh

            function getStateHome() {
                var state = Quickshell.env("XDG_STATE_HOME");
                if (!state) state = Quickshell.env("HOME") + "/.local/state";
                return state;
            }

            // ---- Mode & audio ----
            property bool isEditMode: scopeRoot.pendingEditDefault
            property bool isOcrMode: scopeRoot.pendingOcrMode
            property bool isVideoMode: scopeRoot.savedModeText === "true"

            onIsVideoModeChanged: {
                Quickshell.execDetached(["bash", "-c", "echo '" + (root.isVideoMode ? "true" : "false") + "' > " + scopeRoot.getCacheDir("screenshot") + "/video_mode"]);
                scopeRoot.savedModeText = root.isVideoMode ? "true" : "false";
            }

            property real deskVol: scopeRoot.savedDeskVol
            property bool deskMute: scopeRoot.savedDeskMute
            property real micVol: scopeRoot.savedMicVol
            property bool micMute: scopeRoot.savedMicMute
            property string micDevice: scopeRoot.savedMicDevice

            function saveAudioPrefs() {
                let data = `${deskVol},${deskMute},${micVol},${micMute},${micDevice}`
                Quickshell.execDetached(["bash", "-c", `echo '${data}' > ${scopeRoot.getStateDir("screenshot")}/audio_prefs`]);
                scopeRoot.savedDeskVol = deskVol;
                scopeRoot.savedDeskMute = deskMute;
                scopeRoot.savedMicVol = micVol;
                scopeRoot.savedMicMute = micMute;
                scopeRoot.savedMicDevice = micDevice;
            }

            ListModel { id: micModel }

            // ---- Geometry ----
            property real startX: 0
            property real startY: 0
            property real endX: root.width
            property real endY: root.height

            // Behavior animations are disabled during resets and when selecting
            Behavior on startX { enabled: !root.isSelecting && !root.blockAnimations; NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve } }
            Behavior on startY { enabled: !root.isSelecting && !root.blockAnimations; NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve } }
            Behavior on endX   { enabled: !root.isSelecting && !root.blockAnimations; NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve } }
            Behavior on endY   { enabled: !root.isSelecting && !root.blockAnimations; NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve } }

            property bool hasSelection: true
            property bool isSelecting: false
            property bool isMaximized: false
            property real preStartX: 0
            property real preStartY: 0
            property real preEndX: 0
            property real preEndY: 0

            property real selX: Math.min(startX, endX)
            property real selY: Math.min(startY, endY)
            property real selW: Math.abs(endX - startX)
            property real selH: Math.abs(endY - startY)
            property string geometryString: `${Math.round(selX + screen.x)},${Math.round(selY + screen.y)} ${Math.round(selW)}x${Math.round(selH)}`
            property int interactionMode: 0
            property real anchorX: 0; property real anchorY: 0
            property real initX: 0; property real initY: 0
            property real initW: 0; property real initH: 0

            // ---- QR & OCR states ----
            property bool isScanningQr: false
            property bool showQrPopup: false
            ListModel { id: qrModel }

            property bool isOcrRunning: false
            property bool showOcrPopup: false
            ListModel { id: ocrModel }

            // ---- Maximize ----
            ParallelAnimation {
                id: maximizeAnim
                property real targetStartX; property real targetStartY
                property real targetEndX; property real targetEndY

                NumberAnimation { target: root; property: "startX"; to: maximizeAnim.targetStartX; duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
                NumberAnimation { target: root; property: "startY"; to: maximizeAnim.targetStartY; duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
                NumberAnimation { target: root; property: "endX"; to: maximizeAnim.targetEndX; duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
                NumberAnimation { target: root; property: "endY"; to: maximizeAnim.targetEndY; duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
            }

            function toggleMaximize() {
                if (!isMaximized) {
                    preStartX = root.startX; preStartY = root.startY;
                    preEndX = root.endX; preEndY = root.endY;
                    maximizeAnim.targetStartX = 0; maximizeAnim.targetStartY = 0;
                    maximizeAnim.targetEndX = root.width; maximizeAnim.targetEndY = root.height;
                    isMaximized = true;
                    root.snapToWindowDisabled = true;
                } else {
                    maximizeAnim.targetStartX = preStartX; maximizeAnim.targetStartY = preStartY;
                    maximizeAnim.targetEndX = preEndX; maximizeAnim.targetEndY = preEndY;
                    isMaximized = false;
                }
                maximizeAnim.restart();
            }

            // ---- Shortcuts ----
            Shortcut { sequence: "Escape"; onActivated: root.hideOverlay() }
            Shortcut {
                sequence: "Return";
                onActivated: {
                    if (root.hasSelection && !root.isOcrMode) {
                        root.executeCapture(root.isEditMode && !root.isVideoMode, root.isVideoMode)
                    }
                }
            }
            Shortcut { sequence: "Tab"; onActivated: { if (!root.isOcrMode) root.isVideoMode = !root.isVideoMode } }
            Shortcut { sequence: "Left"; onActivated: { if (!root.isOcrMode) root.isVideoMode = false } }
            Shortcut { sequence: "Right"; onActivated: { if (!root.isOcrMode) root.isVideoMode = true } }
            Shortcut { sequence: "F11"; onActivated: { if (!root.isOcrMode) root.toggleMaximize() } }

            // ---- Components ----
            component AnimWrap: Item {
                property bool isShown: false
                property real contentWidth: 0
                property real rightPadding: s(3)
                property real targetWidth: contentWidth + rightPadding
                width: isShown ? targetWidth : 0
                height: parent.height
                opacity: isShown ? 1.0 : 0.0
                clip: true
                Behavior on width { NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                Behavior on opacity { NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                default property alias content: internalWrapper.children
                Item {
                    id: internalWrapper
                    width: contentWidth
                    height: parent.height
                }
            }

            component QrFinderSquare: Rectangle {
                width: s(6); height: s(6)
                color: "transparent"
                border.width: Math.max(1, s(1.2))
                border.color: Appearance.colors.colOnLayer2
                Rectangle {
                    anchors.centerIn: parent
                    width: s(2); height: s(2)
                    color: Appearance.colors.colOnLayer2
                }
            }

            component ToolbarBtn: Item {
                id: tBtn
                property string iconTxt: ""
                property string label: ""
                property bool isDanger: false
                signal clicked()

                height: s(36)
                width: label !== "" ? (txt.implicitWidth + s(36)) : s(36)

                Rectangle {
                    anchors.fill: parent
                    radius: s(18)
                    color: !maBtn.containsMouse ? "transparent" :
                        (tBtn.isDanger ? Appearance.colors.colErrorContainer : Appearance.colors.colLayer2Hover)
                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }
                }

                RowLayout {
                    anchors.centerIn: parent; spacing: s(6)
                    MaterialSymbol {
                        visible: tBtn.iconTxt !== ""
                        text: tBtn.iconTxt
                        iconSize: s(18)
                        color: tBtn.isDanger ? Appearance.colors.colOnErrorContainer : Appearance.colors.colPrimary
                    }
                    StyledText {
                        id: txt
                        visible: tBtn.label !== ""
                        font.weight: Font.DemiBold
                        font.pixelSize: Appearance.font.pixelSize.smallie
                        text: tBtn.label
                        color: tBtn.isDanger ? Appearance.colors.colOnErrorContainer : Appearance.colors.colPrimary
                    }
                }
                MouseArea {
                    id: maBtn
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tBtn.clicked()
                }
            }

            component ToolbarDivider: Rectangle {
                width: s(2); height: s(16)
                anchors.verticalCenter: parent.verticalCenter
                color: Appearance.colors.colOutlineVariant
                opacity: 0.5
                radius: s(1)
            }

            component Handle: Rectangle {
                width: s(20); height: s(20); radius: s(10)
                color: root.handleColor; border.color: root.accentColor; border.width: s(4)
                visible: (root.hasSelection || root.isSelecting) && !root.isScanningQr && !root.showQrPopup && !root.isOcrRunning && !root.showOcrPopup; z: 10
            }

            component AudioControl: RowLayout {
                property string iconOn: ""
                property string iconOff: ""
                property real volumeValue: 1.0
                property bool mutedValue: false
                property bool hasDropdown: false

                signal volumeUpdate(real newVol)
                signal muteUpdate(bool newMute)
                signal dropdownClicked()

                spacing: s(4)

                Rectangle {
                    width: s(30); height: s(30); radius: s(15)
                    color: maIcon.containsMouse ? Appearance.colors.colLayer2Hover : "transparent"
                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        iconSize: s(16)
                        text: parent.parent.mutedValue ? parent.parent.iconOff : parent.parent.iconOn
                        color: parent.parent.mutedValue ? root.dangerColor : root.accentColor
                    }
                    MouseArea {
                        id: maIcon; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: parent.parent.muteUpdate(!parent.parent.mutedValue)
                    }
                }

                Slider {
                    Layout.preferredWidth: s(60)
                    from: 0.0; to: 1.0; value: parent.volumeValue
                    onValueChanged: parent.volumeUpdate(value)

                    background: Rectangle {
                        x: parent.leftPadding; y: parent.topPadding + parent.availableHeight / 2 - height / 2
                        implicitWidth: s(60); implicitHeight: s(4)
                        width: parent.availableWidth; height: implicitHeight
                        radius: s(2)
                        color: Appearance.colors.colSurfaceContainerHighest
                        Rectangle {
                            width: parent.parent.visualPosition * parent.width; height: parent.height
                            color: parent.parent.parent.mutedValue ? Appearance.colors.colOnSurfaceVariant : Appearance.colors.colPrimary
                            radius: s(2)
                        }
                    }
                    handle: Rectangle {
                        x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width)
                        y: parent.topPadding + parent.availableHeight / 2 - height / 2
                        implicitWidth: s(12); implicitHeight: s(12); radius: s(6)
                        color: parent.parent.mutedValue ? Appearance.colors.colOnSurfaceVariant : Appearance.colors.colPrimary
                    }
                }

                Rectangle {
                    visible: parent.hasDropdown
                    width: s(20); height: s(30); color: "transparent"
                    MaterialSymbol {
                        anchors.centerIn: parent
                        iconSize: s(16)
                        text: toolbar.fitsOutsideBottom ? "expand_less" : "expand_more"
                        color: Appearance.colors.colOnLayer2
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: parent.parent.dropdownClicked() }
                }
            }

            // ---- Overlay UI ----
            Item {
                anchors.fill: parent
                z: 1
                Rectangle {
                    anchors.fill: parent
                    color: root.dimColor
                    opacity: (!root.isSelecting && !root.hasSelection) ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                    StyledText {
                        anchors.centerIn: parent
                        text: root.isOcrMode ? "Select region to extract text" : (root.isVideoMode ? "Select region to record" : "Select region to capture")
                        font.weight: Font.DemiBold
                        font.pixelSize: Appearance.font.pixelSize.huge
                        color: Appearance.colors.colOnSurface
                    }
                }
                Item {
                    anchors.fill: parent
                    opacity: (root.isSelecting || root.hasSelection) ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                    Rectangle { x: 0; y: 0; width: parent.width; height: root.selY; color: root.dimColor }
                    Rectangle { x: 0; y: root.selY + root.selH; width: parent.width; height: parent.height - (root.selY + root.selH); color: root.dimColor }
                    Rectangle { x: 0; y: root.selY; width: root.selX; height: root.selH; color: root.dimColor }
                    Rectangle { x: root.selX + root.selW; y: root.selY; width: parent.width - (root.selX + root.selW); height: root.selH; color: root.dimColor }
                }
            }

            Rectangle {
                visible: root.isSelecting || root.hasSelection
                x: root.selX; y: root.selY; width: root.selW; height: root.selH
                color: root.isOcrMode ? Qt.alpha(Appearance.colors.colPrimary, 0.15) : (root.isVideoMode ? Qt.alpha(Appearance.colors.colError, 0.05) : root.selectionTint)
                border.color: root.isOcrMode ? Appearance.colors.colPrimary : (root.isVideoMode ? Appearance.colors.colError : root.accentColor)
                border.width: s(4)
                z: 5
            }

            // ---- QR highlight ----
            Repeater {
                model: qrModel
                delegate: Rectangle {
                    visible: opacity > 0
                    opacity: (root.showQrPopup && model.qSuccess && model.qW > 0) ? 1.0 : 0.0
                    property real pad: (root.showQrPopup && model.qSuccess) ? s(5) : 0
                    x: model.qW > 0 ? (model.qX - pad) : model.qX
                    y: model.qH > 0 ? (model.qY - pad) : model.qY
                    width: model.qW > 0 ? (model.qW + (pad * 2)) : 0
                    height: model.qH > 0 ? (model.qH + (pad * 2)) : 0
                    color: Qt.alpha(root.successColor, 0.25)
                    border.color: root.successColor
                    border.width: s(3)
                    radius: s(8)
                    z: 34
                    Behavior on opacity { NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                    Behavior on pad { NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                }
            }

            // ---- QR popup (with link detection) ----
            Repeater {
                model: qrModel
                delegate: Item {
                    id: qrPopupItem
                    visible: opacity > 0
                    opacity: (root.showQrPopup && !root.isSelecting) ? 1.0 : 0.0

                    x: model.qSuccess ? model.qTargetX : (root.selX + root.selW/2 - width/2)
                    y: model.qSuccess ? model.qTargetY : (root.selY + root.selH/2 - height/2)

                    // Detect if scanned text is a link
                    property bool isLink: {
                        var t = model.qText || "";
                        return /^https?:\/\//i.test(t) || /^ftp:\/\//i.test(t) || /^file:\/\//i.test(t);
                    }

                    width: qrPopupLayout.implicitWidth + s(32)
                    height: s(52)

                    property bool isHovered: qrHoverArea.containsMouse
                    scale: isHovered ? 1.0 : model.qBaseScale
                    z: isHovered ? 100 : (40 - index)
                    transformOrigin: Item.Center

                    Behavior on opacity { NumberAnimation { duration: Appearance.animation.elementMoveEnter.duration; easing.type: Appearance.animation.elementMoveEnter.type; easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve } }
                    Behavior on scale { NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }

                    MouseArea {
                        id: qrHoverArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }

                    StyledRectangularShadow { target: qrCard }

                    Rectangle {
                        id: qrCard
                        anchors.fill: parent
                        radius: Appearance.rounding.verylarge
                        color: Appearance.colors.colSurfaceContainerHigh
                        border.color: model.qSuccess ? root.successColor : root.dangerColor
                        border.width: s(2)

                        RowLayout {
                            id: qrPopupLayout
                            anchors.fill: parent
                            spacing: s(8)

                            StyledText {
                                text: model.qText
                                color: model.qSuccess ? Appearance.colors.colOnSurface : root.dangerColor
                                font.pixelSize: Appearance.font.pixelSize.smallie
                                font.weight: Font.DemiBold
                                Layout.maximumWidth: s(400)
                                Layout.leftMargin: s(8)
                                elide: Text.ElideRight
                                wrapMode: Text.NoWrap
                            }

                            Rectangle {
                                width: s(2)
                                Layout.fillHeight: true
                                Layout.topMargin: s(10)
                                Layout.bottomMargin: s(10)
                                color: Appearance.colors.colOutlineVariant
                                opacity: 0.5
                                radius: s(1)
                            }

                            // Copy button
                            ToolbarBtn {
                                visible: model.qSuccess
                                iconTxt: "content_copy"
                                onClicked: {
                                    Quickshell.execDetached(["bash", "-c", `echo -n '${model.qText.replace(/'/g, "'\\''")}' | wl-copy`]);
                                    root.hideOverlay();
                                }
                            }

                            // Open link button – only for URLs
                            ToolbarBtn {
                                visible: model.qSuccess && qrPopupItem.isLink
                                iconTxt: "link"
                                onClicked: {
                                    Quickshell.execDetached(["xdg-open", model.qText]);
                                    root.hideOverlay();
                                }
                            }

                            // Close scan popup only
                            ToolbarBtn {
                                iconTxt: "close"
                                isDanger: true
                                onClicked: root.showQrPopup = false
                            }
                        }
                    }
                }
            }

            // ---- OCR highlight (failure only) ----
            Repeater {
                model: ocrModel
                delegate: Rectangle {
                    visible: opacity > 0
                    opacity: (root.showOcrPopup && !model.ocrSuccess) ? 1.0 : 0.0
                    x: root.selX; y: root.selY
                    width: root.selW; height: root.selH
                    color: Qt.alpha(root.dangerColor, 0.15)
                    border.color: root.dangerColor
                    border.width: s(3)
                    radius: s(8)
                    z: 33
                    Behavior on opacity { NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                }
            }

            // ---- OCR Popup (failure) ----
            Repeater {
                model: ocrModel
                delegate: Item {
                    id: ocrPopupItem
                    visible: opacity > 0
                    opacity: (root.showOcrPopup && !root.isSelecting && !model.ocrSuccess) ? 1.0 : 0.0

                    x: model.ocrTargetX
                    y: model.ocrTargetY + (model.fitsTop ? (1.0 - opacity) * s(15) : -(1.0 - opacity) * s(15))

                    width: ocrPopupLayout.implicitWidth + s(32)
                    height: s(52)

                    property bool isHovered: maHover.containsMouse
                    scale: isHovered ? 1.0 : model.ocrBaseScale
                    z: isHovered ? 100 : (40 - index)
                    transformOrigin: Item.Center

                    Behavior on opacity { NumberAnimation { duration: Appearance.animation.elementMoveEnter.duration; easing.type: Appearance.animation.elementMoveEnter.type; easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve } }
                    Behavior on scale { NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }

                    MouseArea { id: maHover; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }

                    StyledRectangularShadow { target: ocrCard }

                    Rectangle {
                        id: ocrCard
                        anchors.fill: parent
                        radius: Appearance.rounding.verylarge
                        color: Appearance.colors.colSurfaceContainerHigh
                        border.color: root.dangerColor
                        border.width: s(2)

                        RowLayout {
                            id: ocrPopupLayout
                            anchors.fill: parent
                            spacing: s(8)

                            StyledText {
                                text: model.ocrText
                                color: root.dangerColor
                                font.pixelSize: Appearance.font.pixelSize.smallie
                                font.weight: Font.DemiBold
                                Layout.maximumWidth: s(400)
                                Layout.leftMargin: s(8)
                                elide: Text.ElideRight
                                wrapMode: Text.NoWrap
                            }

                            Rectangle {
                                width: s(2)
                                Layout.fillHeight: true
                                Layout.topMargin: s(10)
                                Layout.bottomMargin: s(10)
                                color: Appearance.colors.colOutlineVariant
                                opacity: 0.5
                                radius: s(1)
                            }
                            ToolbarBtn { iconTxt: "close"; isDanger: true; onClicked: root.showOcrPopup = false }
                        }
                    }
                }
            }

            // ---- Handles ----
            Handle { x: root.selX - width / 2; y: root.selY - height / 2 }
            Handle { x: root.selX + root.selW - width / 2; y: root.selY - height / 2 }
            Handle { x: root.selX - width / 2; y: root.selY + root.selH - height / 2 }
            Handle { x: root.selX + root.selW - width / 2; y: root.selY + root.selH - height / 2 }

            // ---- MouseArea (with snap and toolbar dead‑zone) ----
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                z: 20

                function getInteractionMode(mx, my, mods) {
                    if (!root.hasSelection) return 1;
                    if (mods & Qt.ShiftModifier) return 2;
                    let margin = s(20)
                    let onLeftLine = Math.abs(mx - root.selX) <= margin;
                    let onRightLine = Math.abs(mx - (root.selX + root.selW)) <= margin
                    let onTopLine = Math.abs(my - root.selY) <= margin;
                    let onBottomLine = Math.abs(my - (root.selY + root.selH)) <= margin
                    let withinX = mx >= (root.selX - margin) && mx <= (root.selX + root.selW + margin);
                    let withinY = my >= (root.selY - margin) && my <= (root.selY + root.selH + margin);

                    if (onTopLine && onLeftLine) return 3;
                    if (onTopLine && onRightLine) return 5;
                    if (onBottomLine && onLeftLine) return 8;
                    if (onBottomLine && onRightLine) return 10;
                    if (onTopLine && withinX) return 4;
                    if (onBottomLine && withinX) return 9;
                    if (onLeftLine && withinY) return 6;
                    if (onRightLine && withinY) return 7;
                    return 1;
                }

                onPositionChanged: (mouse) => {
                    let mode = root.isSelecting ? root.interactionMode : getInteractionMode(mouse.x, mouse.y, mouse.modifiers)
                    switch(mode) {
                        case 2: cursorShape = Qt.ClosedHandCursor; break;
                        case 3: case 10: cursorShape = Qt.SizeFDiagCursor; break;
                        case 5: case 8: cursorShape = Qt.SizeBDiagCursor; break;
                        case 4: case 9: cursorShape = Qt.SizeVerCursor; break;
                        case 6: case 7: cursorShape = Qt.SizeHorCursor; break;
                        default: cursorShape = Qt.CrossCursor; break;
                    }

                    if (!root.isSelecting) {
                        if (Config.options.display.snapToWindows && !root.isOcrMode
                            && !root.snapToWindowDisabled) {
                            let margin = s(5);
                            let insideToolbar = toolbar.visible &&
                                mouse.x >= toolbar.x - margin && mouse.x <= toolbar.x + toolbar.width + margin &&
                                mouse.y >= toolbar.y - margin && mouse.y <= toolbar.y + toolbar.height + margin;

                            let inApproach = false;
                            if (root.hasSelection && toolbar.visible) {
                                if (mouse.x >= toolbar.x - margin && mouse.x <= toolbar.x + toolbar.width + margin) {
                                    if (toolbar.y >= root.selY + root.selH) {
                                        inApproach = mouse.y > root.selY + root.selH && mouse.y < toolbar.y;
                                    } else if (toolbar.y + toolbar.height <= root.selY) {
                                        inApproach = mouse.y < root.selY && mouse.y > toolbar.y + toolbar.height;
                                    }
                                }
                            }

                            if (!insideToolbar && !inApproach) {
                                let hovered = root.findHoveredWindow(mouse.x, mouse.y);
                                if (hovered) {
                                    root.startX = hovered.x;
                                    root.startY = hovered.y;
                                    root.endX = hovered.x + hovered.w;
                                    root.endY = hovered.y + hovered.h;
                                    root.hasSelection = true;
                                    root.isMaximized = false;
                                }
                            }
                        }
                        return;
                    }
                    // ---- Drag handling ----
                    let dx = mouse.x - root.anchorX; let dy = mouse.y - root.anchorY
                    let clamp = (val, min, max) => Math.max(min, Math.min(max, val))

                    if (root.interactionMode === 1) {
                        root.endX = clamp(mouse.x, 0, root.width); root.endY = clamp(mouse.y, 0, root.height)
                    } else if (root.interactionMode === 2) {
                        let targetX = clamp(root.initX + dx, 0, root.width - root.initW); let targetY = clamp(root.initY + dy, 0, root.height - root.initH)
                        root.startX = targetX; root.startY = targetY; root.endX = targetX + root.initW; root.endY = targetY + root.initH;
                    } else {
                        let nx = root.initX, ny = root.initY, nw = root.initW, nh = root.initH
                        if ([3, 6, 8].includes(root.interactionMode)) { nx = clamp(root.initX + dx, 0, root.initX + root.initW - 10); nw = root.initW + (root.initX - nx) }
                        if ([5, 7, 10].includes(root.interactionMode)) { nw = clamp(root.initW + dx, 10, root.width - root.initX) }
                        if ([3, 4, 5].includes(root.interactionMode)) { ny = clamp(root.initY + dy, 0, root.initY + root.initH - 10); nh = root.initH + (root.initY - ny) }
                        if ([8, 9, 10].includes(root.interactionMode)) { nh = clamp(root.initH + dy, 10, root.height - root.initY) }
                        root.startX = nx; root.startY = ny; root.endX = nx + nw; root.endY = ny + nh;
                    }
                }

                onPressed: (mouse) => {
                    if (mouse.button === Qt.RightButton) { root.hideOverlay(); return; }

                    root.isScanningQr = false;
                    root.showQrPopup = false;
                    qrWaitTimer.stop();
                    root.showOcrPopup = false;

                    maximizeAnim.stop()
                    root.interactionMode = getInteractionMode(mouse.x, mouse.y, mouse.modifiers)
                    root.isSelecting = true
                    if (root.interactionMode !== 1) root.isMaximized = false;
                    root.anchorX = mouse.x; root.anchorY = mouse.y
                    root.initX = root.selX; root.initY = root.selY; root.initW = root.selW; root.initH = root.selH;

                    if (root.interactionMode === 1) {
                        let clamp = (val, min, max) => Math.max(min, Math.min(max, val))
                        let clampedX = clamp(mouse.x, 0, root.width); let clampedY = clamp(mouse.y, 0, root.height)
                        root.startX = clampedX; root.startY = clampedY; root.endX = clampedX; root.endY = clampedY;
                        root.hasSelection = false; root.isMaximized = false
                    }
                }

                onReleased: {
                    if (root.isSelecting) {
                        root.isSelecting = false
                        if (root.selW > 10 && root.selH > 10) {
                            root.hasSelection = true
                            if (root.isOcrMode) {
                                root.performOcrAndClose()
                            }
                            root.snapToWindowDisabled = true
                        } else { root.hasSelection = false }
                    }
                }
            }

            // ---- Toolbar ----
            Item {
                id: toolbar
                z: 30
                property real totalHeight: s(120)
                property bool fitsOutsideBottom: (root.selY + root.selH + totalHeight + s(15)) <= root.height

                visible: root.hasSelection && !root.isSelecting && !root.isScanningQr && !root.showQrPopup && !root.isOcrRunning && !root.showOcrPopup && !root.isOcrMode

                width: Math.max(toolbarRow.width + s(64), s(340))
                height: totalHeight

                x: Math.max(s(10), Math.min(parent.width - width - s(10), root.selX + (root.selW / 2) - (width / 2)))
                y: fitsOutsideBottom ? (root.selY + root.selH + s(15)) :
                   ((root.selY - height - s(15)) >= 0 ? (root.selY - height - s(15)) : (root.height - height - s(15)))

                StyledRectangularShadow { target: toolbarCard }

                Rectangle {
                    id: toolbarCard
                    anchors.fill: parent
                    radius: Appearance.rounding.verylarge
                    // Follows the shell-wide transparency setting (Shell style)
                    color: ColorUtils.applyAlpha(Appearance.colors.colSurfaceContainerHigh, 1 - Appearance.backgroundTransparency)
                    border.color: Appearance.colors.colLayer0Border
                    border.width: s(1)
                }

                // Mic dropdown
                Rectangle {
                    id: micDropdown
                    visible: false
                    width: s(280)
                    height: micModel.count === 0 ? s(40) : Math.min(s(180), micModel.count * s(36))
                    x: -s(140)
                    y: toolbar.fitsOutsideBottom ? (toolbar.height + s(8)) : (-height - s(8))
                    color: Appearance.colors.colSurfaceContainerHigh
                    border.color: Appearance.colors.colLayer0Border
                    border.width: s(1)
                    radius: Appearance.rounding.small
                    z: 50

                    StyledText {
                        visible: micModel.count === 0
                        anchors.centerIn: parent
                        text: "No Microphones (Install pulseaudio)"
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer1
                    }

                    ListView {
                        visible: micModel.count > 0
                        anchors.fill: parent; anchors.margins: s(4)
                        model: micModel
                        clip: true
                        delegate: Rectangle {
                            width: ListView.view.width; height: s(32); radius: s(6)
                            color: maList.containsMouse ? Appearance.colors.colLayer2Hover : "transparent"
                            RowLayout {
                                anchors.fill: parent; anchors.margins: s(6)
                                StyledText {
                                    text: model.devDesc
                                    color: root.micDevice === model.devName ? root.accentColor : Appearance.colors.colOnLayer2
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                            MouseArea {
                                id: maList; anchors.fill: parent; hoverEnabled: true;
                                onClicked: { root.micDevice = model.devName; root.saveAudioPrefs(); micDropdown.visible = false }
                            }
                        }
                    }
                }

                Row {
                    id: toolbarRow
                    anchors.top: parent.top
                    anchors.topMargin: s(12)
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: root.s(36)
                    spacing: 0

                    // Mode toggle
                    Item {
                        width: s(110) + s(3); height: parent.height
                        Rectangle {
                            width: s(110); height: s(36); radius: s(18)
                            color: Appearance.colors.colSurfaceContainerHighest
                            Rectangle {
                                id: activeHighlight
                                y: s(2)
                                height: parent.height - s(4)
                                radius: s(16)
                                color: root.accentColor
                                z: 0
                                property bool curVideoMode: root.isVideoMode
                                onCurVideoModeChanged: {
                                    if (curVideoMode) {
                                        rightAnim.duration = 200; leftAnim.duration = 350;
                                    } else {
                                        leftAnim.duration = 200; rightAnim.duration = 350;
                                    }
                                }
                                property real targetLeft: curVideoMode ? (parent.width / 2) : s(2)
                                property real targetRight: targetLeft + (parent.width / 2) - s(2)
                                property real actualLeft: targetLeft
                                property real actualRight: targetRight
                                Behavior on actualLeft { NumberAnimation { id: leftAnim; duration: 250; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                                Behavior on actualRight { NumberAnimation { id: rightAnim; duration: 250; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                                x: actualLeft
                                width: actualRight - actualLeft
                            }
                            Row {
                                anchors.fill: parent
                                z: 1
                                Item {
                                    width: parent.width / 2; height: parent.height
                                    MaterialSymbol { anchors.centerIn: parent; text: "photo_camera"; iconSize: s(16); color: !root.isVideoMode ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSurfaceVariant }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.isVideoMode = false }
                                }
                                Item {
                                    width: parent.width / 2; height: parent.height
                                    MaterialSymbol { anchors.centerIn: parent; text: "videocam"; iconSize: s(16); color: root.isVideoMode ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSurfaceVariant }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.isVideoMode = true }
                                }
                            }
                        }
                    }

                    AnimWrap {
                        isShown: root.isVideoMode; contentWidth: s(2)
                        ToolbarDivider {}
                    }

                    // Desktop audio
                    AnimWrap {
                        isShown: root.isVideoMode; contentWidth: s(94)
                        AudioControl {
                            id: deskAudio; width: parent.width; height: parent.height
                            iconOn: "volume_up"; iconOff: "volume_off"
                            volumeValue: root.deskVol; mutedValue: root.deskMute
                            onVolumeUpdate: (v) => { root.deskVol = v; root.saveAudioPrefs() }
                            onMuteUpdate: (m) => { root.deskMute = m; root.saveAudioPrefs() }
                        }
                    }

                    // Mic audio
                    AnimWrap {
                        isShown: root.isVideoMode; contentWidth: s(118)
                        AudioControl {
                            id: micAudio; width: parent.width; height: parent.height
                            iconOn: "mic"; iconOff: "mic_off"; hasDropdown: true
                            volumeValue: root.micVol; mutedValue: root.micMute
                            onVolumeUpdate: (v) => { root.micVol = v; root.saveAudioPrefs() }
                            onMuteUpdate: (m) => { root.micMute = m; root.saveAudioPrefs() }
                            onDropdownClicked: { micDropdown.visible = !micDropdown.visible; micDropdown.x = mapToItem(toolbar, 0, 0).x - s(120) }
                        }
                    }

                    // Video-mode maximize/fullscreen button
                    AnimWrap {
                        isShown: root.isVideoMode; contentWidth: s(2) + s(3) + s(36)
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            height: parent.height
                            spacing: s(3)
                            ToolbarDivider {}
                            ToolbarBtn {
                                anchors.verticalCenter: parent.verticalCenter
                                iconTxt: root.isMaximized ? "fullscreen_exit" : "fullscreen"
                                onClicked: root.toggleMaximize()
                            }
                        }
                    }

                    AnimWrap {
                        isShown: !root.isVideoMode; contentWidth: s(2)
                        ToolbarDivider {}
                    }

                    // Edit button
                    AnimWrap {
                        isShown: !root.isVideoMode; contentWidth: s(36)
                        ToolbarBtn { iconTxt: "edit"; onClicked: root.executeCapture(true, false) }
                    }

                    // QR button
                    AnimWrap {
                        isShown: !root.isVideoMode; contentWidth: s(36)
                        Rectangle {
                            id: qrBtn
                            height: s(36); width: s(36); radius: s(18)
                            color: maQr.containsMouse ? Appearance.colors.colLayer2Hover : "transparent"
                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.animation.elementMoveFast.duration
                                    easing.type: Appearance.animation.elementMoveFast.type
                                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                }
                            }

                            Item {
                                anchors.centerIn: parent
                                width: s(16); height: s(16)
                                QrFinderSquare { anchors.top: parent.top; anchors.left: parent.left }
                                QrFinderSquare { anchors.top: parent.top; anchors.right: parent.right }
                                QrFinderSquare { anchors.bottom: parent.bottom; anchors.left: parent.left }
                                Rectangle { width: s(1.6); height: s(1.6); color: root.accentColor; anchors.right: parent.right; anchors.bottom: parent.bottom }
                                Rectangle { width: s(1.6); height: s(1.6); color: root.accentColor; anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.bottomMargin: s(4) }
                                Rectangle { width: s(1.6); height: s(1.6); color: root.accentColor; anchors.right: parent.right; anchors.rightMargin: s(4); anchors.bottom: parent.bottom }
                            }

                            MouseArea {
                                id: maQr
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.performQrScan()
                            }
                        }
                    }

                    // OCR button
                    AnimWrap {
                        isShown: !root.isVideoMode; contentWidth: s(36)
                        Rectangle {
                            id: ocrBtn
                            height: s(36); width: s(36); radius: s(18)
                            color: maOcr.containsMouse ? Appearance.colors.colLayer2Hover : "transparent"
                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.animation.elementMoveFast.duration
                                    easing.type: Appearance.animation.elementMoveFast.type
                                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                }
                            }

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "document_scanner"
                                iconSize: s(22)
                                color: root.accentColor
                            }

                            MouseArea {
                                id: maOcr
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.performOcr()
                            }
                        }
                    }

                    AnimWrap {
                        isShown: !root.isVideoMode; contentWidth: s(2)
                        ToolbarDivider {}
                    }

                    // Maximize button (screenshot mode)
                    AnimWrap {
                        isShown: !root.isVideoMode; contentWidth: s(36)
                        ToolbarBtn { iconTxt: root.isMaximized ? "fullscreen_exit" : "fullscreen"; onClicked: root.toggleMaximize() }
                    }

// Close button (hides overlay, stays loaded)
                    AnimWrap {
                        isShown: true; contentWidth: s(2) + s(3) + s(36)
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            height: parent.height
                            spacing: s(3)
                            ToolbarDivider {}
                            ToolbarBtn {
                                anchors.verticalCenter: parent.verticalCenter
                                iconTxt: "close"; isDanger: true; onClicked: root.hideOverlay()
                            }
                        }
                    }
                }

                // Capture button
                Item {
                    id: captureSection
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: s(12)
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    height: s(56)
                    z: 10

                    Rectangle {
                        id: leftLineBase
                        height: s(4)
                        radius: s(2)
                        color: Appearance.colors.colOutlineVariant
                        opacity: 0.5
                        anchors.left: parent.left
                        anchors.leftMargin: s(24)
                        anchors.right: actionBtnContainer.left
                        anchors.rightMargin: s(16)
                        anchors.verticalCenter: parent.verticalCenter
                        clip: true

                        Rectangle {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: actionArea.containsMouse ? parent.width : 0
                            radius: s(2)
                            Behavior on width { NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve } }
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: root.isVideoMode ? root.dangerColor : root.accentColor }
                                GradientStop { position: 1.0; color: "transparent" }
                            }
                        }
                    }

                    Item {
                        id: actionBtnContainer
                        width: s(56)
                        height: width
                        anchors.centerIn: parent
                        z: 20

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: "transparent"
                            border.color: root.isVideoMode ? Qt.alpha(root.dangerColor, 0.4) : Qt.alpha(Appearance.colors.colPrimary, 0.35)
                            border.width: s(2)
                            Behavior on border.color { ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                        }

                        Rectangle {
                            width: actionArea.pressed ? s(32) : (actionArea.containsMouse ? s(40) : s(36))
                            height: width
                            radius: width / 2
                            anchors.centerIn: parent
                            color: root.isVideoMode ? root.dangerColor : root.accentColor
                            Behavior on color { ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                            Behavior on width { NumberAnimation { duration: Appearance.animation.clickBounce.duration; easing.type: Appearance.animation.clickBounce.type; easing.bezierCurve: Appearance.animation.clickBounce.bezierCurve } }
                        }

                        MouseArea {
                            id: actionArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.executeCapture(false, root.isVideoMode)
                        }
                    }

                    Rectangle {
                        id: rightLineBase
                        height: s(4)
                        radius: s(2)
                        color: Appearance.colors.colOutlineVariant
                        opacity: 0.5
                        anchors.right: parent.right
                        anchors.rightMargin: s(24)
                        anchors.left: actionBtnContainer.right
                        anchors.leftMargin: s(16)
                        anchors.verticalCenter: parent.verticalCenter
                        clip: true

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: actionArea.containsMouse ? parent.width : 0
                            radius: s(2)
                            Behavior on width { NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve } }
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 1.0; color: root.isVideoMode ? root.dangerColor : root.accentColor }
                            }
                        }
                    }
                }
            }

            // ---- QR process ----
            Process {
                id: qrReaderProcess
                property string accumulated: ""
                command: ["cat", scopeRoot.getRunDir("screenshot") + "/qr_result"]
                stdout: SplitParser { splitMarker: ""; onRead: data => qrReaderProcess.accumulated += data }
                onExited: (exitCode) => {
                    let res = qrReaderProcess.accumulated.trim()
                    qrReaderProcess.accumulated = ""
                    root.isScanningQr = false
                    qrModel.clear()

                    if (exitCode !== 0 || res === "") {
                        qrModel.append({
                            qX: root.selX + (root.selW / 2), qY: root.selY + (root.selH / 2), qW: 0, qH: 0,
                            qText: "Scan timed out or failed.", qSuccess: false,
                            qTargetX: root.selX + (root.selW / 2) - s(100), qTargetY: root.selY + (root.selH / 2),
                            qBaseScale: 1.0
                        })
                        root.showQrPopup = true
                        return
                    }

                    let lines = res.split('\n');
                    let qrs = [];

                    for (let i = 0; i < lines.length; i++) {
                        let line = lines[i].trim();
                        if (line === "") continue;
                        let delimiterIdx = line.indexOf('|||');
                        if (delimiterIdx === -1) continue;

                        let coordStr = line.substring(0, delimiterIdx);
                        let actualText = line.substring(delimiterIdx + 3).replace(/\\n/g, '\n').replace(/\\\\/g, '\\');
                        let coords = coordStr.split(',');

                        if (coords.length === 4 && !isNaN(parseInt(coords[0]))) {
                            let x = parseInt(coords[0]); let y = parseInt(coords[1]); let w = parseInt(coords[2]); let h = parseInt(coords[3]);
                            let successState = !(actualText === "NOT_FOUND" || actualText.startsWith("ERROR:"));
                            let cleanText = successState ? actualText.replace(/^QR-Code:/, "") : (actualText === "NOT_FOUND" ? "No QR code found." : actualText);

                            let estTextWidth = Math.min(s(400), cleanText.length * s(8.5));
                            let pw = estTextWidth + (successState ? s(140) : s(40));
                            let ph = s(52);
                            let absX = root.selX + x; let absY = root.selY + y;
                            let cx = absX + (w / 2);
                            let fitsTop = (absY - ph - s(15)) >= root.selY;
                            let idealX = cx - (pw / 2);
                            let targetX = Math.max(s(10), Math.min(root.width - pw - s(10), idealX));
                            let targetY = fitsTop ? (absY - ph - s(15)) : (absY + h + s(15));

                            qrs.push({ qX: absX, qY: absY, qW: w, qH: h, qText: cleanText, qSuccess: successState, pw: pw, ph: ph, targetX: targetX, targetY: targetY, cx: targetX + (pw / 2), cy: targetY + (ph / 2), scale: 1.0 });
                        }
                    }

                    // Collision detection
                    for (let pass = 0; pass < 5; pass++) {
                        for (let i = 0; i < qrs.length; i++) {
                            for (let j = i + 1; j < qrs.length; j++) {
                                let A = qrs[i]; let B = qrs[j];
                                let dx = Math.abs(A.cx - B.cx); let dy = Math.abs(A.cy - B.cy);
                                let req_x = (A.pw * A.scale + B.pw * B.scale) / 2 + s(10);
                                let req_y = (A.ph * A.scale + B.ph * B.scale) / 2 + s(10);
                                if (dx < req_x && dy < req_y) {
                                    let factorX = dx > 0 ? (dx - s(10)) * 2 / (A.pw + B.pw) : 0;
                                    let factorY = dy > 0 ? (dy - s(10)) * 2 / (A.ph + B.ph) : 0;
                                    let maxFactor = Math.max(factorX, factorY);
                                    maxFactor = Math.max(0.35, maxFactor);
                                    A.scale = Math.min(A.scale, maxFactor); B.scale = Math.min(B.scale, maxFactor);
                                }
                            }
                        }
                    }

                    if (qrs.length === 0) {
                        qrModel.append({
                            qX: root.selX + (root.selW / 2), qY: root.selY + (root.selH / 2), qW: 0, qH: 0,
                            qText: "No QR code found.", qSuccess: false,
                            qTargetX: root.selX + (root.selW / 2) - s(100), qTargetY: root.selY + (root.selH / 2),
                            qBaseScale: 1.0
                        });
                    } else {
                        for (let i = 0; i < qrs.length; i++) {
                            qrModel.append({ qX: qrs[i].qX, qY: qrs[i].qY, qW: qrs[i].qW, qH: qrs[i].qH, qText: qrs[i].qText, qSuccess: qrs[i].qSuccess, qTargetX: qrs[i].targetX, qTargetY: qrs[i].targetY, qBaseScale: qrs[i].scale });
                        }
                    }

                    root.showQrPopup = true
                    Quickshell.execDetached(["bash", "-c", "rm -f " + scopeRoot.getRunDir("screenshot") + "/qr_result"])
                }
            }

            Timer {
                id: qrWaitTimer
                interval: 1200
                repeat: false
                onTriggered: qrReaderProcess.running = true
            }

            function performQrScan() {
                Quickshell.execDetached(["bash", "-c", "rm -f " + scopeRoot.getRunDir("screenshot") + "/qr_result"])
                root.isScanningQr = true; root.showQrPopup = false; qrModel.clear()
                let cmd = `bash /usr/share/sleex/scripts/grimblast.sh --geometry "${root.geometryString}" --scan-qr`
                Quickshell.execDetached(["bash", "-c", cmd])
                qrWaitTimer.start()
            }

            // ---- OCR implementation ----
            Process {
                id: ocrProcess
                property string accumulated: ""
                command: ["bash", "-c",
                    "TMP=/tmp/ocr_$$.png; " +
                    "grim -g \"" + root.geometryString + "\" \"$TMP\" && " +
                    "(command -v convert >/dev/null 2>&1 && convert \"$TMP\" -resize 200% \"$TMP\" 2>/dev/null || true) && " +
                    "tesseract \"$TMP\" stdout 2>/dev/null && " +
                    "rm -f \"$TMP\""
                ]
                stdout: SplitParser { splitMarker: ""; onRead: data => ocrProcess.accumulated += data }
                onExited: (exitCode) => {
                    let text = ocrProcess.accumulated.trim()
                    ocrProcess.accumulated = ""
                    root.isOcrRunning = false

                    let success = (exitCode === 0 && text !== "")

                    if (success) {
                        Quickshell.execDetached(["bash", "-c", `echo -n '${text.replace(/'/g, "'\\''")}' | wl-copy`])
                        root.hideOverlay()
                        return
                    }

                    // Failure: show popup
                    let displayText = "OCR failed or no text found."

                    let estTextWidth = Math.min(s(400), displayText.length * s(8.5))
                    let pw = estTextWidth + s(40)
                    let ph = s(52)
                    let cx = root.selX + (root.selW / 2)
                    let cy = root.selY + (root.selH / 2)
                    let fitsTop = (cy - ph - s(15)) >= 0
                    let targetX = Math.max(s(10), Math.min(root.width - pw - s(10), cx - (pw / 2)))
                    let targetY = fitsTop ? (cy - ph - s(15)) : (cy + root.selH/2 + s(15))

                    ocrModel.clear()
                    ocrModel.append({
                        ocrText: displayText,
                        ocrSuccess: false,
                        ocrTargetX: targetX,
                        ocrTargetY: targetY,
                        ocrBaseScale: 1.0,
                        fitsTop: fitsTop
                    })
                    root.showOcrPopup = true
                }
            }

            function performOcr() {
                if (root.selW < 10 || root.selH < 10) return
                root.isOcrRunning = true
                root.showOcrPopup = false
                ocrModel.clear()
                ocrProcess.accumulated = ""
                ocrProcess.running = false
                ocrProcess.running = true
            }

            function performOcrAndClose() {
                if (root.selW < 10 || root.selH < 10) { root.hideOverlay(); return }
                root.performOcr()
            }

            // ---- Helper to compute recording FPS ----
            function getRecordingFps() {
                if (Config.options.display.autoFps) {
                    var monitor = Hyprland.focusedMonitor;
                    if (monitor) {
                        for (var i = 0; i < Quickshell.screens.length; i++) {
                            if (Quickshell.screens[i].name === monitor.name) {
                                var rate = Quickshell.screens[i].refreshRate;
                                if (rate && rate > 0) {
                                    return Math.round(rate);
                                }
                                break;
                            }
                        }
                    }
                    return 60;
                } else {
                    return Config.options.display.screenRecordingFPS;
                }
            }

            // ---- Capture timer ----
            // Gives the compositor ~2 frames to process the unmap before grim
            // reads the frame; grimblast.sh adds its own guard sleep.
            Timer {
                id: captureTimer
                property string pendingCmd: ""
                property bool pendingKeepFreeze: false
                interval: 32
                repeat: false
                onTriggered: {
                    Quickshell.execDetached(["bash", "-c", pendingCmd])
                    root.hideOverlay(pendingKeepFreeze)
                }
            }

            function executeCapture(openEditor, isRecord) {
                let script = isRecord ? "record-script.sh" : "grimblast.sh"
                let cmd = `bash /usr/share/sleex/scripts/${script} --geometry "${root.geometryString}"`
                if (isRecord) {
                    cmd += " --record"
                    cmd += ` --fps ${root.getRecordingFps()}`
                    cmd += ` --desk-vol ${root.deskVol} --desk-mute ${root.deskMute}`
                    cmd += ` --mic-vol ${root.micVol} --mic-mute ${root.micMute}`
                    if (root.micDevice !== "") cmd += ` --mic-dev "${root.micDevice}"`
                    let isFullscreenSelection = root.selX === 0 && root.selY === 0 &&
                        Math.abs(root.selW - root.width) < 2 && Math.abs(root.selH - root.height) < 2
                    if (isFullscreenSelection) cmd += " --fullscreen"
                }
                if (openEditor) cmd += " --edit"
                root.visible = false
                captureTimer.pendingCmd = cmd
                // Screenshots keep the frozen frame until grim grabs it;
                // recordings unfreeze immediately.
                captureTimer.pendingKeepFreeze = !isRecord
                captureTimer.start()
            }

            function finishStartup() {
                micModel.clear();
                for (let entry of scopeRoot.savedMicList) {
                    micModel.append(entry);
                }
                windowListReader.running = true;
            }

            Component.onCompleted: {
                root.finishStartup();
            }
        }
    }

    IpcHandler {
        target: "screenshot"
        function onOpen() {
            if (scopeRoot.isOverlayOpen) { scopeRoot.closeOverlay(); return }
            scopeRoot.showOverlay(false, false)
        }
        function onOpenEdit() {
            if (scopeRoot.isOverlayOpen) { scopeRoot.closeOverlay(); return }
            scopeRoot.showOverlay(true, false)
        }
        function onOpenOcr() {
            if (scopeRoot.isOverlayOpen) { scopeRoot.closeOverlay(); return }
            scopeRoot.showOverlay(false, true)
        }
        function onClose() {
            scopeRoot.closeOverlay()
        }
    }
}
