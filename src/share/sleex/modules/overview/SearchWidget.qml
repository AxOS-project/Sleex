import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root
    readonly property string xdgConfigHome: Directories.config
    property string searchingText: ""
    property bool showResults: searchingText != ""
    property real searchBarHeight: searchBar.height + Appearance.sizes.elevationMargin * 2
    implicitWidth: searchWidgetContent.implicitWidth + Appearance.sizes.elevationMargin * 2
    implicitHeight: searchWidgetContent.implicitHeight + Appearance.sizes.elevationMargin * 2

    property string mathResult: ""
    property bool clipboardWorkSafetyActive: false
    property int clipboardRefreshCounter: 0

    property var searchActions: [
        {
            action: "accentcolor",
            execute: args => {
                Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--noswitch", "--color", ...(args != '' ? [`${args}`] : [])]);
            }
        },
        {
            action: "dark",
            execute: () => {
                if (!Config.options.appearance.palette.useStaticColors) Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--mode", "dark", "--noswitch"]);
                else Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--mode", "dark", "--noswitch", "--color", `${Config.options.appearance.palette.accentColorHex}`]);
            }
        },
        {
            action: "light",
            execute: () => {
                if (!Config.options.appearance.palette.useStaticColors) Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--mode", "light", "--noswitch"]);
                else Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--mode", "light", "--noswitch", "--color", `${Config.options.appearance.palette.accentColorHex}`]);
            }
        },
        {
            action: "superpaste",
            execute: args => {
                if (!/^(\d+)/.test(args.trim())) {
                    Quickshell.execDetached([
                        "notify-send",
                        "Superpaste",
                        "Usage: <tt>%1superpaste NUM_OF_ENTRIES[i]</tt>\nSupply <tt>i</tt> when you want images\nExamples:\n<tt>%1superpaste 4i</tt> for the last 4 images\n<tt>%1superpaste 7</tt> for the last 7 entries".arg(Config.options.search.prefix.action),
                        "-a", "Shell"
                    ]);
                    return;
                }
                const syntaxMatch = /^(?:(\d+)(i)?)/.exec(args.trim());
                const count = syntaxMatch[1] ? parseInt(syntaxMatch[1]) : 1;
                const isImage = !!syntaxMatch[2];
                Cliphist.superpaste(count, isImage);
            }
        },
        {
            action: "todo",
            execute: args => {
                Todo.addTask(args);
            }
        },
        {
            action: "wallpaper",
            execute: () => {
                GlobalStates.wallpaperSelectorOpen = true;
            }
        },
        {
            action: "wipeclipboard",
            execute: () => {
                Cliphist.wipe();
            }
        },
    ]

    function focusFirstItem() {
        appResults.currentIndex = 0;
    }

    function disableExpandAnimation() {
        searchWidthBehavior.enabled = false;
    }

    function cancelSearch() {
        searchInput.selectAll();
        root.searchingText = "";
        searchWidthBehavior.enabled = true;
    }

    function setSearchingText(text) {
        searchInput.text = text;
        root.searchingText = text;
    }

    function refreshClipboardModel() {
        root.clipboardRefreshCounter++;
    }

    function containsUnsafeLink(entry) {
        if (entry == undefined) return false;
        const unsafeKeywords = Config.options.workSafety.triggerCondition.linkKeywords;
        return StringUtils.stringListContainsSubstring(entry.toLowerCase(), unsafeKeywords);
    }

    Timer {
        id: nonAppResultsTimer
        interval: Config.options.search.nonAppResultDelay
        onTriggered: {
            let expr = root.searchingText;
            if (expr.startsWith(Config.options.search.prefix.math)) {
                expr = expr.slice(Config.options.search.prefix.math.length);
            }
            mathProcess.calculateExpression(expr);
        }
    }

    Process {
        id: mathProcess
        property list<string> baseCommand: ["qalc", "-t"]
        function calculateExpression(expression) {
            mathProcess.running = false;
            mathProcess.command = baseCommand.concat(expression);
            mathProcess.running = true;
        }
        stdout: SplitParser {
            onRead: data => {
                root.mathResult = data;
                root.focusFirstItem();
            }
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape)
            return;

        if (event.key === Qt.Key_Backspace) {
            if (!searchInput.activeFocus) {
                searchInput.forceActiveFocus();
                if (event.modifiers & Qt.ControlModifier) {
                    let text = searchInput.text;
                    let pos = searchInput.cursorPosition;
                    if (pos > 0) {
                        let left = text.slice(0, pos);
                        let match = left.match(/(\s*\S+)\s*$/);
                        let deleteLen = match ? match[0].length : 1;
                        searchInput.text = text.slice(0, pos - deleteLen) + text.slice(pos);
                        searchInput.cursorPosition = pos - deleteLen;
                    }
                } else {
                    if (searchInput.cursorPosition > 0) {
                        searchInput.text = searchInput.text.slice(0, searchInput.cursorPosition - 1) + searchInput.text.slice(searchInput.cursorPosition);
                        searchInput.cursorPosition -= 1;
                    }
                }
                searchInput.cursorPosition = searchInput.text.length;
                event.accepted = true;
            }
            return;
        }

        if (event.text && event.text.length === 1 && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Return && event.key !== Qt.Key_Delete && event.text.charCodeAt(0) >= 0x20) {
            if (!searchInput.activeFocus) {
                searchInput.forceActiveFocus();
                searchInput.text = searchInput.text.slice(0, searchInput.cursorPosition) + event.text + searchInput.text.slice(searchInput.cursorPosition);
                searchInput.cursorPosition += 1;
                event.accepted = true;
                root.focusFirstItem();
            }
        }
    }

    StyledRectangularShadow {
        target: searchWidgetContent
    }

    Rectangle {
        id: searchWidgetContent
        anchors.centerIn: parent
        implicitWidth: columnLayout.implicitWidth
        implicitHeight: columnLayout.implicitHeight
        radius: Appearance.rounding.large
        color: Appearance.colors.colLayer0
        border.width: 1
        border.color: Appearance.colors.colLayer0Border

        ColumnLayout {
            id: columnLayout
            anchors.centerIn: parent
            spacing: 0

            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: searchWidgetContent.width
                    height: searchWidgetContent.height
                    radius: searchWidgetContent.radius
                }
            }

            RowLayout {
                id: searchBar
                spacing: 5
                MaterialSymbol {
                    id: searchIcon
                    Layout.leftMargin: 15
                    iconSize: Appearance.font.pixelSize.huge
                    color: Appearance.m3colors.m3onSurface
                    text: root.searchingText.startsWith(Config.options.search.prefix.clipboard) ? 'content_paste_search' : 'search'
                }
                TextField {
                    id: searchInput
                    focus: GlobalStates.overviewOpen
                    Layout.fillWidth: true
                    padding: 15
                    renderType: Text.NativeRendering
                    font {
                        family: Appearance?.font.family.main ?? "sans-serif"
                        pixelSize: Appearance?.font.pixelSize.small ?? 15
                        hintingPreference: Font.PreferFullHinting
                    }
                    color: activeFocus ? Appearance.m3colors.m3onSurface : Appearance.m3colors.m3onSurfaceVariant
                    selectedTextColor: Appearance.m3colors.m3onSecondaryContainer
                    selectionColor: Appearance.colors.colSecondaryContainer
                    placeholderText: "Search, calculate or run"
                    placeholderTextColor: Appearance.m3colors.m3outline
                    implicitWidth: root.searchingText == "" ? Appearance.sizes.searchWidthCollapsed : Appearance.sizes.searchWidth

                    Behavior on implicitWidth {
                        id: searchWidthBehavior
                        enabled: false
                        NumberAnimation {
                            duration: 300
                            easing.type: Appearance.animation.elementMove.type
                            easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                        }
                    }

                    onTextChanged: root.searchingText = text

                    onAccepted: {
                        if (appResults.count > 0) {
                            let firstItem = appResults.itemAtIndex(0);
                            if (firstItem && firstItem.clicked) {
                                firstItem.clicked();
                            }
                        }
                    }

                    background: null

                    cursorDelegate: Rectangle {
                        width: 1
                        color: searchInput.activeFocus ? Appearance.colors.colPrimary : "transparent"
                        radius: 1
                    }
                }

                RippleButton {
                    id: wipeClipboardButton
                    visible: root.searchingText.startsWith(Config.options.search.prefix.clipboard)
                    Layout.rightMargin: 8
                    implicitWidth: 45
                    implicitHeight: 30
                    buttonRadius: Appearance.rounding.full
                    colBackgroundHover: Appearance.colors.colSecondaryContainer
                    colRipple: Appearance.colors.colSecondaryContainerActive

                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "clear_all"
                        font.pixelSize: 25
                        color: Appearance.m3colors.m3onSurface
                    }

                    onClicked: {
                        Cliphist.wipe();
                        root.refreshClipboardModel();
                        Quickshell.execDetached(["bash", "-c", "sleep 2 && rm ~/.cache/cliphist/db"]);
                    }

                    StyledToolTip {
                        text: "Clear clipboard history"
                    }
                }
            }

            Rectangle {
                visible: root.showResults
                Layout.fillWidth: true
                height: 1
                color: Appearance.colors.colOutlineVariant
            }

            ListView {
                id: appResults
                visible: root.showResults
                Layout.fillWidth: true
                implicitHeight: Math.min(600, appResults.contentHeight + topMargin + bottomMargin)
                clip: true
                topMargin: 10
                bottomMargin: 10
                spacing: 2
                KeyNavigation.up: searchBar
                highlightMoveDuration: 100

                onFocusChanged: {
                    if (focus)
                        appResults.currentIndex = 1;
                }

                Connections {
                    target: root
                    function onSearchingTextChanged() {
                        if (appResults.count > 0)
                            appResults.currentIndex = 0;
                    }
                }

                model: ScriptModel {
                    id: model
                    objectProp: "key"
                    values: {
                        // Reading clipboardRefreshCounter here makes this binding depend on it,
                        // forcing re-evaluation after clipboard mutations (wipe, delete).
                        const _refresh = root.clipboardRefreshCounter;

                        if (root.searchingText == "")
                            return [];

                        if (root.searchingText.startsWith(Config.options.search.prefix.clipboard)) {
                            const searchString = StringUtils.cleanPrefix(root.searchingText, Config.options.search.prefix.clipboard);
                            return Cliphist.fuzzyQuery(searchString).map((entry, index, array) => {
                                const isImage = Cliphist.entryIsImage(entry);
                                const mightBlurImage = isImage && root.clipboardWorkSafetyActive;
                                let shouldBlurImage = mightBlurImage;
                                if (mightBlurImage) {
                                    shouldBlurImage = shouldBlurImage && (containsUnsafeLink(array[index - 1]) || containsUnsafeLink(array[index + 1]));
                                }
                                const type = `#${entry.match(/^\s*(\S+)/)?.[1] || ""}`;

                                const actions = [];
                                if (isImage) {
                                    actions.push({
                                        name: "Extract Text",
                                        materialIcon: "document_scanner",
                                        execute: () => {
                                            GlobalStates.overviewOpen = true;
                                            Quickshell.execDetached(["bash", "-c", 'printf "%s" "$1" | cliphist decode | tesseract stdin stdout | wl-copy', "ocr", entry]);
                                        }
                                    });
                                }
                                actions.push(
                                    {
                                        name: "Copy",
                                        materialIcon: "content_copy",
                                        execute: () => {
                                            Cliphist.copy(entry);
                                        }
                                    },
                                    {
                                        name: "Delete",
                                        materialIcon: "delete",
                                        execute: () => {
                                            Cliphist.deleteEntry(entry);
                                            root.refreshClipboardModel();
                                        }
                                    }
                                );

                                return {
                                    key: type,
                                    cliphistRawString: entry,
                                    name: isImage ? "" : StringUtils.cleanCliphistEntry(entry),
                                    clickActionName: "",
                                    type: type,
                                    execute: () => {
                                        Cliphist.copy(entry)
                                    },
                                    actions: actions,
                                    blurImage: shouldBlurImage,
                                    blurImageText: "Work safety"
                                };
                            }).filter(Boolean);
                        }
                        else if (root.searchingText.startsWith(Config.options.search.prefix.emojis)) {
                            const searchString = StringUtils.cleanPrefix(root.searchingText, Config.options.search.prefix.emojis);
                            return Emojis.fuzzyQuery(searchString).map(entry => {
                                const emoji = entry.match(/^\s*(\S+)/)?.[1] || ""
                                return {
                                    key: emoji,
                                    cliphistRawString: entry,
                                    bigText: emoji,
                                    name: entry.replace(/^\s*\S+\s+/, ""),
                                    clickActionName: "",
                                    type: "Emoji",
                                    execute: () => {
                                        Quickshell.clipboardText = entry.match(/^\s*(\S+)/)?.[1];
                                    }
                                };
                            }).filter(Boolean);
                        }

                        nonAppResultsTimer.restart();
                        const mathResultObject = {
                            key: `Math result: ${root.mathResult}`,
                            name: root.mathResult,
                            clickActionName: "Copy",
                            type: "Math result",
                            fontType: "monospace",
                            materialSymbol: 'calculate',
                            execute: () => {
                                Quickshell.clipboardText = root.mathResult;
                            }
                        };
                        const appResultObjects = AppSearch.fuzzyQuery(StringUtils.cleanPrefix(root.searchingText, Config.options.search.prefix.app)).map(entry => {
                            entry.clickActionName = "Launch";
                            entry.type = "App";
                            entry.key = entry.execute
                            return entry;
                        })
                        const commandResultObject = {
                            key: `cmd ${root.searchingText}`,
                            name: StringUtils.cleanPrefix(root.searchingText, Config.options.search.prefix.shellCommand).replace("file://", ""),
                            clickActionName: "Run",
                            type: "Run command",
                            fontType: "monospace",
                            materialSymbol: 'terminal',
                            execute: () => {
                                let cleanedCommand = root.searchingText.replace("file://", "");
                                cleanedCommand = StringUtils.cleanPrefix(cleanedCommand, Config.options.search.prefix.shellCommand);
                                if (cleanedCommand.startsWith(Config.options.search.prefix.shellCommand)) {
                                    cleanedCommand = cleanedCommand.slice(Config.options.search.prefix.shellCommand.length);
                                }
                                Quickshell.execDetached(["bash", "-c", searchingText.startsWith('sudo') ? `${Config.options.apps.terminal} fish -C '${cleanedCommand}'` : cleanedCommand]);
                            }
                        };
                        const webSearchResultObject = {
                            key: `website ${root.searchingText}`,
                            name: StringUtils.cleanPrefix(root.searchingText, Config.options.search.prefix.webSearch),
                            clickActionName: "Search",
                            type: "Search the web",
                            materialSymbol: 'travel_explore',
                            execute: () => {
                                let query = StringUtils.cleanPrefix(root.searchingText, Config.options.search.prefix.webSearch);
                                let url = Config.options.search.engineBaseUrl + query;
                                for (let site of Config.options.search.excludedSites) {
                                    url += ` -site:${site}`;
                                }
                                Qt.openUrlExternally(url);
                            }
                        }
                        const launcherActionObjects = root.searchActions.map(action => {
                            const actionString = `${Config.options.search.prefix.action}${action.action}`;
                            if (actionString.startsWith(root.searchingText) || root.searchingText.startsWith(actionString)) {
                                return {
                                    key: `Action ${actionString}`,
                                    name: root.searchingText.startsWith(actionString) ? root.searchingText : actionString,
                                    clickActionName: "Run",
                                    type: "Action",
                                    materialSymbol: 'settings_suggest',
                                    execute: () => {
                                        action.execute(root.searchingText.split(" ").slice(1).join(" "));
                                    }
                                };
                            }
                            return null;
                        }).filter(Boolean);

                        let result = [];
                        const startsWithNumber = /^\d/.test(root.searchingText);
                        const startsWithMathPrefix = root.searchingText.startsWith(Config.options.search.prefix.math);
                        const startsWithShellCommandPrefix = root.searchingText.startsWith(Config.options.search.prefix.shellCommand);
                        const startsWithWebSearchPrefix = root.searchingText.startsWith(Config.options.search.prefix.webSearch);
                        if (startsWithNumber || startsWithMathPrefix) {
                            result.push(mathResultObject);
                        } else if (startsWithShellCommandPrefix) {
                            result.push(commandResultObject);
                        } else if (startsWithWebSearchPrefix) {
                            result.push(webSearchResultObject);
                        }

                        result = result.concat(appResultObjects);
                        result = result.concat(launcherActionObjects);

                        if (Config.options.search.prefix.showDefaultActionsWithoutPrefix) {
                            if (!startsWithShellCommandPrefix) result.push(commandResultObject);
                            if (!startsWithNumber && !startsWithMathPrefix) result.push(mathResultObject);
                            if (!startsWithWebSearchPrefix) result.push(webSearchResultObject);
                        }

                        return result;
                    }
                }

                delegate: SearchItem {
                    required property var modelData
                    anchors.left: parent?.left
                    anchors.right: parent?.right
                    entry: modelData
                    query: StringUtils.cleanOnePrefix(root.searchingText, [
                        Config.options.search.prefix.action,
                        Config.options.search.prefix.app,
                        Config.options.search.prefix.clipboard,
                        Config.options.search.prefix.emojis,
                        Config.options.search.prefix.math,
                        Config.options.search.prefix.shellCommand,
                        Config.options.search.prefix.webSearch
                    ])
                }
            }
        }
    }
}
