import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects
import Sleex.Fhtc

Item {
    required property var bar
    property bool borderless: Config.options.bar.borderless
    readonly property var activeWindow: FhtcWorkspaces.focusedWindow
    readonly property string screenName: bar.screen?.name ?? ""
    
    // Get workspaces for this screen only, sorted by ID
    readonly property var screenWorkspaces: {
        return Object.values(FhtcWorkspaces.workspaces)
            .filter(ws => ws.output === screenName)
            .sort((a, b) => a.id - b.id);
    }
    
    // Active workspace index within this screen (0-based)
    readonly property int activeWorkspaceIndex: {
        if (!FhtcWorkspaces.activeWorkspace) return -1;
        if (FhtcWorkspaces.activeWorkspace.output !== screenName) return -1;
        // Find the index of the active workspace in our sorted screen workspaces
        const idx = screenWorkspaces.findIndex(ws => ws.id === FhtcWorkspaces.activeWorkspace.id);
        // Return -1 if the workspace is beyond the shown limit
        if (idx >= Config.options.bar.workspaces.shown) return -1;
        return idx;
    }
    
    property list<bool> workspaceOccupied: []
    property int widgetPadding: 0
    property int horizontalPadding: 5
    property int workspaceButtonWidth: 30
    property real workspaceIconSize: workspaceButtonWidth * 0.6
    property real workspaceIconSizeShrinked: workspaceButtonWidth * 0.55
    property real workspaceIconOpacityShrinked: 1
    property real workspaceIconMarginShrinked: -4

    // Function to update workspaceOccupied
    function updateWorkspaceOccupied() {
        workspaceOccupied = Array.from({ length: Config.options.bar.workspaces.shown }, (_, i) => {
            // Get the workspace at this index for this screen
            const ws = screenWorkspaces[i];
            if (!ws) return false;
            // Check if the workspace has any windows
            return ws.windows && ws.windows.length > 0;
        })
    }

    // Initialize workspaceOccupied when the component is created
    Component.onCompleted: updateWorkspaceOccupied()

    // Listen for changes in Fhtc.workspaces and windows
    Connections {
        target: FhtcWorkspaces
        function onWorkspacesChanged() {
            updateWorkspaceOccupied();
        }
        function onWindowsChanged() {
            updateWorkspaceOccupied();
        }
        function onActiveWorkspaceChanged() {
            updateWorkspaceOccupied();
        }
    }

    implicitWidth: rowLayout.implicitWidth + horizontalPadding * 2
    implicitHeight: 40


    // Scroll to switch workspaces
    WheelHandler {
        onWheel: (event) => {
            if (event.angleDelta.y < 0) {
                FhtcIpc.dispatch("focus-next-workspace", {});
            } else if (event.angleDelta.y > 0) {
                FhtcIpc.dispatch("focus-previous-workspace", {});
            }
        }
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    }

    Item {
        anchors.fill: parent
        anchors.leftMargin: horizontalPadding
        anchors.rightMargin: horizontalPadding

        // Workspaces - background
        RowLayout {
            id: rowLayout
            z: 1

            spacing: 0
            anchors.fill: parent
            implicitHeight: 40

            Repeater {
                model: Config.options.bar.workspaces.shown

                Rectangle {
                    z: 1
                    implicitWidth: workspaceButtonWidth
                    implicitHeight: workspaceButtonWidth
                    radius: Appearance.rounding.full
                    property var leftOccupied: (workspaceOccupied[index-1])
                    property var rightOccupied: (workspaceOccupied[index+1])
                    property var radiusLeft: leftOccupied ? 0 : Appearance.rounding.full
                    property var radiusRight: rightOccupied ? 0 : Appearance.rounding.full

                    topLeftRadius: radiusLeft
                    bottomLeftRadius: radiusLeft
                    topRightRadius: radiusRight
                    bottomRightRadius: radiusRight
                    
                    color: ColorUtils.transparentize(Appearance.m3colors.m3secondaryContainer, 0.4)
                    opacity: (workspaceOccupied[index]) ? 1 : 0

                    Behavior on opacity {
                        animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                    }
                    Behavior on radiusLeft {
                        animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                    }

                    Behavior on radiusRight {
                        animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                    }

                }

            }

        }

        // Active workspace
        Rectangle {
            z: 2
            visible: activeWorkspaceIndex >= 0
            // Make active ws indicator, which has a brighter color, smaller to look like it is of the same size as ws occupied highlight
            property real activeWorkspaceMargin: 2
            implicitHeight: workspaceButtonWidth - activeWorkspaceMargin * 2
            radius: Appearance.rounding.full
            color: Appearance.colors.colPrimary
            anchors.verticalCenter: parent.verticalCenter

            property real idx1: activeWorkspaceIndex >= 0 ? activeWorkspaceIndex : 0
            property real idx2: activeWorkspaceIndex >= 0 ? activeWorkspaceIndex : 0
            x: Math.min(idx1, idx2) * workspaceButtonWidth + activeWorkspaceMargin
            implicitWidth: Math.abs(idx1 - idx2) * workspaceButtonWidth + workspaceButtonWidth - activeWorkspaceMargin * 2

            Behavior on activeWorkspaceMargin {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }
            Behavior on idx1 { // Leading anim
                NumberAnimation {
                    duration: 100
                    easing.type: Easing.OutSine
                }
            }
            Behavior on idx2 { // Following anim
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutSine
                }
            }
        }

        // Workspaces - numbers
        RowLayout {
            id: rowLayoutNumbers
            z: 3

            spacing: 0
            anchors.fill: parent
            implicitHeight: 40

            Repeater {
                model: Config.options.bar.workspaces.shown

                Button {
                    id: button
                    property var workspace: screenWorkspaces[index] ?? null
                    property int workspaceId: workspace?.id ?? -1
                    Layout.fillHeight: true
                    onPressed: {
                        if (button.workspaceId >= 0) {
                            FhtcIpc.dispatch("focus-workspace-by-index", { "workspace_idx": button.workspaceId });
                        }
                    }
                    width: workspaceButtonWidth
                    
                    background: Item {
                        id: workspaceButtonBackground
                        implicitWidth: workspaceButtonWidth
                        implicitHeight: workspaceButtonWidth
                        
                        // Get the biggest window from the workspace's window list
                        property var biggestWindow: {
                            if (!button.workspace || !button.workspace.windows || button.workspace.windows.length === 0) return null;
                            const windowIds = button.workspace.windows;
                            const windowsInThisWorkspace = windowIds.map(id => FhtcWorkspaces.windows[id]).filter(w => w != null);
                            return windowsInThisWorkspace.reduce((maxWin, win) => {
                                const maxArea = (maxWin?.size?.[0] ?? 0) * (maxWin?.size?.[1] ?? 0)
                                const winArea = (win?.size?.[0] ?? 0) * (win?.size?.[1] ?? 0)
                                return winArea > maxArea ? win : maxWin
                            }, null)
                        }
                        property var mainAppIconSource: Quickshell.iconPath(AppSearch.guessIcon(biggestWindow?.["app-id"]), "image-missing")

                        StyledText { // Workspace number text
                            opacity: GlobalStates.workspaceShowNumbers
                                || ((Config.options?.bar.workspaces.alwaysShowNumbers && (!Config.options?.bar.workspaces.showAppIcons || !workspaceButtonBackground.biggestWindow || GlobalStates.workspaceShowNumbers))
                                || (GlobalStates.workspaceShowNumbers && !Config.options?.bar.workspaces.showAppIcons)
                                )  ? 1 : 0
                            z: 3

                            anchors.centerIn: parent
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: Appearance.font.pixelSize.small - ((text.length - 1) * (text !== "10") * 2)
                            text: `${index + 1}`
                            elide: Text.ElideRight
                            color: (activeWorkspaceIndex == index) ? 
                                Appearance.m3colors.m3onPrimary : 
                                (workspaceOccupied[index] ? Appearance.m3colors.m3onSecondaryContainer : 
                                    Appearance.colors.colOnLayer1Inactive)

                            Behavior on opacity {
                                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                            }
                        }
                        Rectangle { // Dot instead of ws number
                            id: wsDot
                            opacity: (Config.options?.bar.workspaces.alwaysShowNumbers
                                || GlobalStates.workspaceShowNumbers
                                || (Config.options?.bar.workspaces.showAppIcons && workspaceButtonBackground.biggestWindow)
                                ) ? 0 : 1
                            visible: opacity > 0
                            anchors.centerIn: parent
                            width: workspaceButtonWidth * 0.18
                            height: width
                            radius: width / 2
                            color: (activeWorkspaceIndex == index) ?
                                Appearance.m3colors.m3onPrimary :
                                (workspaceOccupied[index] ? Appearance.m3colors.m3onSecondaryContainer :
                                    Appearance.colors.colOnLayer1Inactive)

                            Behavior on opacity {
                                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                            }
                        }
                        Item { // Main app icon
                            anchors.centerIn: parent
                            width: workspaceButtonWidth
                            height: workspaceButtonWidth
                            opacity: !Config.options?.bar.workspaces.showAppIcons ? 0 :
                                (workspaceButtonBackground.biggestWindow && !GlobalStates.workspaceShowNumbers && Config.options?.bar.workspaces.showAppIcons) ? 
                                1 : workspaceButtonBackground.biggestWindow ? workspaceIconOpacityShrinked : 0
                            visible: opacity > 0
                            IconImage {
                                id: mainAppIcon
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                anchors.bottomMargin: (!GlobalStates.workspaceShowNumbers && Config.options?.bar.workspaces.showAppIcons) ? 
                                    (workspaceButtonWidth - workspaceIconSize) / 2 : workspaceIconMarginShrinked
                                anchors.rightMargin: (!GlobalStates.workspaceShowNumbers && Config.options?.bar.workspaces.showAppIcons) ? 
                                    (workspaceButtonWidth - workspaceIconSize) / 2 : workspaceIconMarginShrinked

                                source: workspaceButtonBackground.mainAppIconSource
                                implicitSize: (!GlobalStates.workspaceShowNumbers && Config.options?.bar.workspaces.showAppIcons) ? workspaceIconSize : workspaceIconSizeShrinked

                                Behavior on opacity {
                                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                                }
                                Behavior on anchors.bottomMargin {
                                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                                }
                                Behavior on anchors.rightMargin {
                                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                                }
                                Behavior on implicitSize {
                                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                                }

                            }
                        }
                    }
                    
                }

            }

        }

    }

}
