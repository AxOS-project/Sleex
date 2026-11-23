import qs
import qs.services
import qs.modules.common
import SleexUiKit.Widgets
import SleexUiKit.Appearance
import Sleex.Fhtc
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: overviewScope
    property bool dontAutoCancelSearch: false
    Variants {
        id: overviewVariants
        model: Quickshell.screens
        PanelWindow {
            id: root
            required property var modelData
            property string searchingText: ""
            property string pendingSearchingText: ""
            property bool monitorIsFocused: (FhtcMonitors.activeMonitorName === root.screen.name)
            screen: modelData
            visible: GlobalStates.overviewOpen && monitorIsFocused

            WlrLayershell.namespace: "quickshell:overview"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: GlobalStates.overviewOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            color: "transparent"

            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }

            Connections {
                target: GlobalStates
                function onOverviewOpenChanged() {
                    if (!GlobalStates.overviewOpen) {
                        if (searchWidgetLoader.item) {
                            searchWidgetLoader.item.disableExpandAnimation()
                        }
                        root.pendingSearchingText = ""
                        root.searchingText = ""
                        overviewScope.dontAutoCancelSearch = false;
                    } else {
                        if (!overviewScope.dontAutoCancelSearch && searchWidgetLoader.item) {
                            searchWidgetLoader.item.cancelSearch()
                        }
                    }
                }
            }

            implicitWidth: columnLayout.implicitWidth
            implicitHeight: columnLayout.implicitHeight

            function setSearchingText(text) {
                if (searchWidgetLoader.item) {
                    searchWidgetLoader.item.setSearchingText(text);
                    searchWidgetLoader.item.focusFirstItem();
                } else {
                    root.pendingSearchingText = text;
                    root.searchingText = text;
                }
            }

            MouseArea {
                anchors.fill: parent
                visible: GlobalStates.overviewOpen
                onPressed: GlobalStates.overviewOpen = false
            }

            ColumnLayout {
                id: columnLayout
                visible: GlobalStates.overviewOpen
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: !Config.options.bar.bottom ? parent.top : undefined
                    bottom: Config.options.bar.bottom ? parent.bottom : undefined
                }

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        GlobalStates.overviewOpen = false;
                    } else if (event.key === Qt.Key_Left) {
                        if (!root.searchingText) FhtcIpc.dispatch("focus-previous-workspace");
                    } else if (event.key === Qt.Key_Right) {
                        if (!root.searchingText) FhtcIpc.dispatch("focus-next-workspace");
                    }
                }

                Item {
                    height: 1 // Prevent Wayland protocol error
                    width: 1 // Prevent Wayland protocol error
                }

                Loader {
                    id: searchWidgetLoader
                    Layout.alignment: Qt.AlignHCenter
                    active: GlobalStates.overviewOpen && root.monitorIsFocused
                    visible: active
                    focus: active

                    onLoaded: {
                        if (root.pendingSearchingText !== "") {
                            item.setSearchingText(root.pendingSearchingText)
                            item.focusFirstItem()
                            root.pendingSearchingText = ""
                        } else if (!overviewScope.dontAutoCancelSearch) {
                            item.cancelSearch()
                        }
                    }

                    onActiveChanged: {
                        if (!active) {
                            root.searchingText = ""
                            root.pendingSearchingText = ""
                        }
                    }

                    sourceComponent: SearchWidget {
                        onSearchingTextChanged: {
                            root.searchingText = searchingText
                        }
                    }
                }

                Loader {
                    asynchronous: true
                    id: overviewLoader
                    active: GlobalStates.overviewOpen && root.monitorIsFocused && (root.searchingText == "")
                    visible: active
                    sourceComponent: OverviewWidget {
                        panelWindow: root
                    }
                }
            }

        }
    }

    IpcHandler {
        target: "overview"

        function toggle() {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen
        }
        function close() {
            GlobalStates.overviewOpen = false
        }
        function open() {
            GlobalStates.overviewOpen = true
        }
        function toggleReleaseInterrupt() {
            GlobalStates.superReleaseMightTrigger = false
        }
    }

    GlobalShortcut {
        name: "overviewToggle"
        description: qsTr("Toggles overview on press")

        onPressed: {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen
        }
    }
    GlobalShortcut {
        name: "overviewClose"
        description: qsTr("Closes overview")

        onPressed: {
            GlobalStates.overviewOpen = false
        }
    }
    GlobalShortcut {
        name: "overviewToggleRelease"
        description: qsTr("Toggles overview on release")

        onPressed: {
            GlobalStates.superReleaseMightTrigger = true
        }

        onReleased: {
            if (!GlobalStates.superReleaseMightTrigger) {
                GlobalStates.superReleaseMightTrigger = true
                return
            }
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen
        }
    }
    GlobalShortcut {
        name: "overviewToggleReleaseInterrupt"
        description: qsTr("Interrupts possibility of overview being toggled on release. ") +
            qsTr("This is necessary because GlobalShortcut.onReleased in quickshell triggers whether or not you press something else while holding the key. ") +
            qsTr("To make sure this works consistently, use binditn = MODKEYS, catchall in an automatically triggered submap that includes everything.")

        onPressed: {
            GlobalStates.superReleaseMightTrigger = false
        }
    }
    GlobalShortcut {
        name: "overviewClipboardToggle"
        description: qsTr("Toggle clipboard query on overview widget")

        onPressed: {
            if (GlobalStates.overviewOpen && overviewScope.dontAutoCancelSearch) {
                GlobalStates.overviewOpen = false;
                return;
            }
            for (let i = 0; i < overviewVariants.instances.length; i++) {
                let panelWindow = overviewVariants.instances[i];
                if (panelWindow.modelData.name === FhtcMonitors.activeMonitorName) {
                    overviewScope.dontAutoCancelSearch = true;
                    panelWindow.setSearchingText(
                        Config.options.search.prefix.clipboard
                    );
                    GlobalStates.overviewOpen = true;
                    return
                }
            }
        }
    }

    GlobalShortcut {
        name: "overviewEmojiToggle"
        description: qsTr("Toggle emoji query on overview widget")

        onPressed: {
            if (GlobalStates.overviewOpen && overviewScope.dontAutoCancelSearch) {
                GlobalStates.overviewOpen = false;
                return;
            }
            for (let i = 0; i < overviewVariants.instances.length; i++) {
                let panelWindow = overviewVariants.instances[i];
                if (panelWindow.modelData.name === FhtcMonitors.activeMonitorName) {
                    overviewScope.dontAutoCancelSearch = true;
                    panelWindow.setSearchingText(
                        Config.options.search.prefix.emojis
                    );
                    GlobalStates.overviewOpen = true;
                    return
                }
            }
        }
    }

}
