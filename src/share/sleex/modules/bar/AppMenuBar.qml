import qs.modules.common
import SleexUiKit.Widgets
import SleexUiKit.Appearance
import SleexUiKit.Functions
import Sleex.Services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell

Item {
    id: root
    required property var bar
    readonly property Toplevel activeWindow: ToplevelManager.activeToplevel
    readonly property string currentAppId: activeWindow?.activated ? (activeWindow?.appId ?? "") : ""
    readonly property DesktopEntry desktopEntry: currentAppId !== "" ? DesktopEntries.heuristicLookup(currentAppId) : null

    property int openMenuIndex: -1

    implicitWidth: menuRow.implicitWidth
    implicitHeight: parent ? parent.height : Appearance.sizes.barHeight

    onCurrentAppIdChanged: openMenuIndex = -1

    /**
     * A list of fallback menus to display when no native D-Bus menu is available.
     * Only includes real, existing actions connected to DesktopEntry, Wayland Toplevel, or Hyprland.
     */
    readonly property var fallbackMenus: {
        if (!root.activeWindow?.activated) {
            return [];
        }

        const entry = root.desktopEntry;
        const appActions = entry?.actions ?? [];
        let fileItems = [];

        if (appActions.length > 0) {
            for (let i = 0; i < appActions.length; i++) {
                const act = appActions[i];
                if (!act || !act.name) continue;
                fileItems.push({
                    name: act.name,
                    iconName: act.icon || "",
                    shortcut: "",
                    desktopAction: act
                });
            }
            if (fileItems.length > 0) {
                fileItems.push({ isSeparator: true, name: "" });
            }
        } else if (entry) {
            fileItems.push({
                name: qsTr("New Window"),
                iconName: entry.icon || "",
                shortcut: "",
                desktopEntry: entry
            });
            fileItems.push({ isSeparator: true, name: "" });
        }

        fileItems.push({ name: qsTr("Quit"), shortcut: "Super+Q", action: "close" });

        return [
            {
                name: qsTr("File"),
                items: fileItems
            },
            {
                name: qsTr("Window"),
                items: [
                    { name: qsTr("Fullscreen"),      shortcut: "Super+F",    action: "fullscreen" },
                    { name: qsTr("Toggle Floating"), shortcut: "Super+Alt+Space",       action: "togglefloating" },
                    { isSeparator: true, name: "" },
                    { name: qsTr("Close Window"),    shortcut: "Super+Q", action: "close" },
                ]
            },
        ];
    }

    readonly property var menus: AppMenu.hasNativeMenu ? AppMenu.menus : root.fallbackMenus

    function executeMenuItem(item) {
        if (item.enabled === false) return;

        root.openMenuIndex = -1;

        if (item.itemId !== undefined && AppMenu.hasNativeMenu) {
            AppMenu.trigger(item.itemId);
            return;
        }

        if (item.desktopAction) {
            item.desktopAction.execute();
            return;
        }

        if (item.desktopEntry) {
            item.desktopEntry.execute();
            return;
        }

        // Direct Wayland Toplevel & Hyprland window actions
        if (item.action) {
            switch (item.action) {
            case "fullscreen":
                if (root.activeWindow) root.activeWindow.fullscreen = !root.activeWindow.fullscreen;
                return;
            case "togglefloating":
                Hyprland.dispatch("hl.dsp.window.float()");
                return;
            case "close":
                if (root.activeWindow) root.activeWindow.close();
                return;
            }
        }
    }

    HyprlandFocusGrab {
        id: menuFocusGrab
        active: root.openMenuIndex !== -1 && dropdownLoader.active
        windows: dropdownLoader.active ? [dropdownLoader.item, root.QsWindow?.window] : []
        onCleared: {
            root.openMenuIndex = -1;
        }
    }

    LazyLoader {
        id: dropdownLoader
        active: root.openMenuIndex !== -1 && root.openMenuIndex < root.menus.length

        component: PanelWindow {
            id: dropdownWindow
            color: "transparent"

            anchors {
                top: !Config.options.bar.bottom
                bottom: Config.options.bar.bottom
                left: true
            }

            readonly property var topMenuObject: (root.openMenuIndex >= 0 && root.openMenuIndex < root.menus.length)
                ? root.menus[root.openMenuIndex]
                : null
            readonly property Item activeButton: root.openMenuIndex >= 0 ? menuRepeater.itemAt(root.openMenuIndex) : null

            property var submenuStack: []
            readonly property var currentItems: {
                const stack = dropdownWindow.submenuStack;
                if (stack && stack.length > 0) {
                    return stack[stack.length - 1].items || [];
                }
                const topObj = dropdownWindow.topMenuObject;
                return (topObj && topObj.items) ? topObj.items : [];
            }

            Connections {
                target: root
                function onOpenMenuIndexChanged() {
                    if (dropdownWindow.submenuStack.length > 0) {
                        dropdownWindow.submenuStack = [];
                    }
                }
            }

            implicitWidth: dropdownBg.implicitWidth + Appearance.sizes.elevationMargin * 2
            implicitHeight: dropdownBg.implicitHeight + Appearance.sizes.elevationMargin * 2

            mask: Region {
                item: dropdownBg
            }

            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0

            margins {
                left: {
                    if (!activeButton) return 0;
                    const mapped = root.QsWindow?.mapFromItem(activeButton, 0, 0);
                    return mapped ? mapped.x : 0;
                }
                top: !Config.options.bar.bottom ? Appearance.sizes.barHeight : 0
                bottom: Config.options.bar.bottom ? Appearance.sizes.barHeight : 0
            }

            WlrLayershell.namespace: "quickshell:appmenu"
            WlrLayershell.layer: WlrLayer.Overlay

            StyledRectangularShadow {
                target: dropdownBg
            }

            Rectangle {
                id: dropdownBg
                readonly property real padding: 6
                anchors {
                    left: parent.left
                    top: !Config.options.bar.bottom ? parent.top : undefined
                    bottom: Config.options.bar.bottom ? parent.bottom : undefined
                    margins: Appearance.sizes.elevationMargin
                }
                implicitWidth: dropdownColumn.implicitWidth + padding * 2
                implicitHeight: dropdownColumn.implicitHeight + padding * 2
                radius: Appearance.rounding.small
                color: ColorUtils.applyAlpha(Appearance.colors.colSurfaceContainer, 1 - Appearance.backgroundTransparency)
                border.width: 1
                border.color: Appearance.colors.colLayer0Border

                opacity: 0
                Component.onCompleted: opacity = 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Appearance.animation.elementMoveFast.type
                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                    }
                }

                ColumnLayout {
                    id: dropdownColumn
                    anchors {
                        fill: parent
                        margins: dropdownBg.padding
                    }
                    spacing: 2

                    Rectangle {
                        visible: dropdownWindow.submenuStack.length > 0
                        Layout.fillWidth: true
                        implicitWidth: backRow.implicitWidth + 24
                        implicitHeight: 32
                        radius: Math.max(Appearance.rounding.small - 2, 2)
                        color: backArea.containsMouse ? Appearance.colors.colLayer1Hover : "transparent"

                        RowLayout {
                            id: backRow
                            anchors {
                                left: parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                leftMargin: 8
                                rightMargin: 12
                            }
                            spacing: 6

                            MaterialSymbol {
                                text: "chevron_left"
                                iconSize: 18
                                color: Appearance.colors.colSubtext
                            }

                            StyledText {
                                text: dropdownWindow.submenuStack.length > 0
                                    ? dropdownWindow.submenuStack[dropdownWindow.submenuStack.length - 1].title
                                    : qsTr("Back")
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                                color: Appearance.colors.colSubtext
                                Layout.fillWidth: true
                            }
                        }

                        MouseArea {
                            id: backArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                let nextStack = dropdownWindow.submenuStack.slice(0, -1);
                                dropdownWindow.submenuStack = nextStack;
                            }
                        }
                    }

                    Rectangle {
                        visible: dropdownWindow.submenuStack.length > 0
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Appearance.colors.colOutlineVariant
                    }

                    Repeater {
                        model: dropdownWindow.currentItems

                        delegate: Loader {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true

                            readonly property bool isSep: (modelData.isSeparator === true) || (modelData.name === "")
                            sourceComponent: isSep ? separatorDelegate : menuItemDelegate

                            Component {
                                id: separatorDelegate
                                Rectangle {
                                    implicitHeight: 1
                                    color: Appearance.colors.colOutlineVariant
                                }
                            }

                            Component {
                                id: menuItemDelegate

                                Rectangle {
                                    readonly property bool itemEnabled: modelData.enabled !== false
                                    readonly property bool hasSubmenu: (modelData.items && modelData.items.length > 0) || modelData.hasChildren === true
                                    readonly property string toggleType: modelData.toggleType || ""
                                    readonly property int toggleState: modelData.toggleState ?? 0

                                    implicitWidth: itemRow.implicitWidth + 32
                                    implicitHeight: 32
                                    radius: Math.max(Appearance.rounding.small - 2, 2)
                                    color: itemArea.containsMouse && itemEnabled
                                        ? Appearance.colors.colLayer1Hover
                                        : "transparent"
                                    opacity: itemEnabled ? 1.0 : 0.45

                                    Behavior on color {
                                        animation: ColorAnimation {
                                            duration: Appearance.animation.elementMoveFast.duration
                                            easing.type: Appearance.animation.elementMoveFast.type
                                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                        }
                                    }

                                    RowLayout {
                                        id: itemRow
                                        anchors {
                                            left: parent.left
                                            right: parent.right
                                            verticalCenter: parent.verticalCenter
                                            leftMargin: 10
                                            rightMargin: 10
                                        }
                                        spacing: 10

                                        Item {
                                            visible: toggleType !== ""
                                            implicitWidth: 16
                                            implicitHeight: 16

                                            MaterialSymbol {
                                                anchors.centerIn: parent
                                                visible: toggleState === 1
                                                text: toggleType === "radio" ? "radio_button_checked" : "check"
                                                iconSize: 16
                                                color: Appearance.colors.colOnLayer1
                                            }
                                        }

                                        // Optional item icon
                                        Loader {
                                            active: (modelData.iconName || "") !== ""
                                            visible: active
                                            Layout.preferredWidth: 16
                                            Layout.preferredHeight: 16
                                            sourceComponent: IconImage {
                                                asynchronous: true
                                                source: Quickshell.iconPath(modelData.iconName, true)
                                                implicitSize: 16
                                                mipmap: true
                                            }
                                        }

                                        StyledText {
                                            text: modelData.name || ""
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            color: Appearance.colors.colOnLayer1
                                            Layout.fillWidth: true
                                        }

                                        StyledText {
                                            text: modelData.shortcut || ""
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            color: Appearance.colors.colSubtext
                                            visible: text !== "" && !hasSubmenu
                                        }

                                        MaterialSymbol {
                                            visible: hasSubmenu
                                            text: "chevron_right"
                                            iconSize: 18
                                            color: Appearance.colors.colSubtext
                                        }
                                    }

                                    MouseArea {
                                        id: itemArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: itemEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: {
                                            if (!itemEnabled) return;
                                            if (hasSubmenu) {
                                                if (modelData.itemId !== undefined && AppMenu.hasNativeMenu) {
                                                    AppMenu.prepareMenu(modelData.itemId);
                                                }
                                                let nextStack = dropdownWindow.submenuStack.slice();
                                                nextStack.push({
                                                    title: modelData.name,
                                                    items: modelData.items || []
                                                });
                                                dropdownWindow.submenuStack = nextStack;
                                            } else {
                                                root.executeMenuItem(modelData);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    RowLayout {
        id: menuRow
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        spacing: 2

        Repeater {
            id: menuRepeater
            model: root.menus

            Item {
                id: menuButton
                required property var modelData
                required property int index

                Layout.fillHeight: true
                implicitWidth: menuLabel.implicitWidth + 16
                implicitHeight: root.implicitHeight

                property bool isOpen: root.openMenuIndex === index

                Rectangle {
                    id: menuButtonBg
                    anchors.fill: parent
                    anchors.topMargin: 6
                    anchors.bottomMargin: 6
                    radius: Appearance.rounding.small
                    color: menuButtonArea.containsMouse || menuButton.isOpen
                        ? Appearance.colors.colLayer1Hover
                        : "transparent"

                    Behavior on color {
                        animation: ColorAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }
                }

                StyledText {
                    id: menuLabel
                    anchors.centerIn: parent
                    text: menuButton.modelData.name || ""
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer0
                }

                MouseArea {
                    id: menuButtonArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        if (root.openMenuIndex === menuButton.index) {
                            root.openMenuIndex = -1;
                        } else {
                            if (menuButton.modelData.itemId !== undefined && AppMenu.hasNativeMenu) {
                                AppMenu.prepareMenu(menuButton.modelData.itemId);
                            }
                            root.openMenuIndex = menuButton.index;
                        }
                    }

                    // If a menu is already open, hovering another button switches to it
                    onContainsMouseChanged: {
                        if (containsMouse && root.openMenuIndex !== -1 && root.openMenuIndex !== menuButton.index) {
                            if (menuButton.modelData.itemId !== undefined && AppMenu.hasNativeMenu) {
                                AppMenu.prepareMenu(menuButton.modelData.itemId);
                            }
                            root.openMenuIndex = menuButton.index;
                        }
                    }
                }
            }
        }
    }
}
