import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland
import Sleex.Fhtc

Item {
    id: root
    required property var panelWindow
    readonly property var monitor: FhtcMonitors.activeMonitor
    // readonly property var toplevels: ToplevelManager.toplevels
    readonly property int workspacesShown: Config.options.overview.numOfRows * Config.options.overview.numOfCols
    readonly property int workspaceGroup: Math.floor(((monitor["active-workspace-idx"] ?? 0)) / workspacesShown)
    property bool monitorIsFocused: (FhtcMonitors.activeMonitorName === screen.name)
    readonly property var focusedScreen: Quickshell.screens.find(s => s.name === FhtcMonitors.activeMonitorName)
    property real scale: Config.options.overview.scale
    property color activeBorderColor: Appearance.colors.colSecondary

    property real workspaceImplicitWidth: (focusedScreen?.width ?? 0) * root.scale
    property real workspaceImplicitHeight: ((focusedScreen?.height ?? 0) - Appearance.sizes.barHeight) * root.scale

    property real workspaceNumberMargin: 80
    property real workspaceNumberSize: Math.min(workspaceImplicitHeight, workspaceImplicitWidth) * (panelWindow.screen.devicePixelRatio ?? 1)

    property int workspaceZ: 0
    property int windowZ: 1
    property int windowDraggingZ: 99999
    property real workspaceSpacing: 5

    property int draggingFromWorkspace: -1
    property int draggingTargetWorkspace: -1

    implicitWidth: overviewBackground.implicitWidth + Appearance.sizes.elevationMargin * 2
    implicitHeight: overviewBackground.implicitHeight + Appearance.sizes.elevationMargin * 2

    property Component windowComponent: OverviewWindow {}
    property list<OverviewWindow> windowWidgets: []

    StyledRectangularShadow {
        target: overviewBackground
    }
    Rectangle { // Background
        id: overviewBackground
        property real padding: 10
        anchors.fill: parent
        anchors.margins: Appearance.sizes.elevationMargin

        implicitWidth: workspaceColumnLayout.implicitWidth + padding * 2
        implicitHeight: workspaceColumnLayout.implicitHeight + padding * 2
        radius: Appearance.rounding.screenRounding * root.scale + padding
        color: Appearance.colors.colLayer0

        ColumnLayout { // Workspaces
            id: workspaceColumnLayout

            z: root.workspaceZ
            anchors.centerIn: parent
            spacing: workspaceSpacing
            Repeater {
                model: Config.options.overview.numOfRows
                delegate: RowLayout {
                    id: row
                    property int rowIndex: index
                    spacing: workspaceSpacing

                    Repeater { // Workspace repeater
                        model: Config.options.overview.numOfCols
                        Rectangle { // Workspace
                            id: workspace
                            property int colIndex: index
                            property int workspaceValue: root.workspaceGroup * workspacesShown + rowIndex * Config.options.overview.numOfCols + colIndex
                            property color defaultWorkspaceColor: Appearance.colors.colLayer1 // TODO: reconsider this color for a cleaner look
                            property color hoveredWorkspaceColor: ColorUtils.mix(defaultWorkspaceColor, Appearance.colors.colLayer1Hover, 0.1)
                            property color hoveredBorderColor: Appearance.colors.colLayer2Hover
                            property bool hoveredWhileDragging: false

                            implicitWidth: root.workspaceImplicitWidth
                            implicitHeight: root.workspaceImplicitHeight
                            color: hoveredWhileDragging ? hoveredWorkspaceColor : defaultWorkspaceColor
                            radius: Appearance.rounding.screenRounding * root.scale
                            border.width: 2
                            border.color: hoveredWhileDragging ? hoveredBorderColor : "transparent"

                            StyledText {
                                anchors.centerIn: parent
                                text: workspaceValue
                                font.pixelSize: root.workspaceNumberSize * root.scale
                                font.weight: Font.DemiBold
                                color: ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.8)
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            MouseArea {
                                id: workspaceArea
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                onClicked: {
                                    if (root.draggingTargetWorkspace === -1) {
                                        GlobalStates.overviewOpen = false
                                        FhtcIpc.dispatch("focus-workspace-by-index", { "workspace_idx": workspaceValue })
                                    }
                                }
                            }

                            DropArea {
                                anchors.fill: parent
                                onEntered: {
                                    root.draggingTargetWorkspace = workspaceValue
                                    if (root.draggingFromWorkspace == root.draggingTargetWorkspace) return;
                                    hoveredWhileDragging = true
                                }
                                onExited: {
                                    hoveredWhileDragging = false
                                    if (root.draggingTargetWorkspace == workspaceValue) root.draggingTargetWorkspace = -1
                                }
                            }

                        }
                    }
                }
            }
        }

        Item { // Windows & focused workspace indicator
            id: windowSpace
            anchors.centerIn: parent
            implicitWidth: workspaceColumnLayout.implicitWidth
            implicitHeight: workspaceColumnLayout.implicitHeight

            Repeater { // Window repeater
                model: ScriptModel {
                    values: {
                        return Object.values(FhtcWorkspaces.windows).filter((win) => {
                            const wsId = win?.["workspace-id"] ?? -1
                            return wsId >= root.workspaceGroup * root.workspacesShown &&
                                wsId <  (root.workspaceGroup + 1) * root.workspacesShown
                        })
                    }
                }
                delegate: OverviewWindow {
                    id: window
                    required property var modelData
                    windowData: modelData
                    // toplevel: not yet available with fhtc compositor
                    monitorData: root.focusedScreen
                    scale: root.scale
                    availableWorkspaceWidth: root.workspaceImplicitWidth
                    availableWorkspaceHeight: root.workspaceImplicitHeight

                    property bool atInitPosition: (initX == x && initY == y)

                    property int workspaceColIndex: (modelData?.["workspace-id"] ?? 0) % Config.options.overview.numOfCols
                    property int workspaceRowIndex: Math.floor((modelData?.["workspace-id"] ?? 0) % root.workspacesShown / Config.options.overview.numOfCols)
                    xOffset: (root.workspaceImplicitWidth + workspaceSpacing) * workspaceColIndex - ((root.focusedScreen?.x ?? 0) * root.scale)
                    yOffset: (root.workspaceImplicitHeight + workspaceSpacing) * workspaceRowIndex - ((root.focusedScreen?.y ?? 0) * root.scale)

                    Timer {
                        id: updateWindowPosition
                        interval: Config.options.hacks.arbitraryRaceConditionDelay
                        repeat: false
                        running: false
                        onTriggered: {
                            window.x = Math.round(Math.max(modelData?.location[0] * root.scale, 0) + xOffset)
                            window.y = Math.round(Math.max((modelData?.location[1] - Appearance.sizes.barHeight) * root.scale, 0) + yOffset)
                        }
                    }

                    Component.onCompleted: updateWindowPosition.restart()

                    z: atInitPosition ? root.windowZ : root.windowDraggingZ
                    Drag.hotSpot.x: targetWindowWidth / 2
                    Drag.hotSpot.y: targetWindowHeight / 2
                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: hovered = true // For hover color change
                        onExited: hovered = false // For hover color change
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        drag.target: parent
                        onPressed: {
                            root.draggingFromWorkspace = modelData?.["workspace-id"]
                            window.pressed = true
                            window.Drag.active = true
                            window.Drag.source = window
                        }
                        onReleased: {
                            const targetWorkspace = root.draggingTargetWorkspace
                            window.pressed = false
                            window.Drag.active = false
                            root.draggingFromWorkspace = -1
                            if (targetWorkspace !== -1 && targetWorkspace !== modelData?.["workspace-id"]) {
                                FhtcIpc.dispatch("send-window-to-workspace", { "window-id": modelData?.id, "workspace-id": targetWorkspace })
                                updateWindowPosition.restart()
                            } else {
                                window.x = window.initX
                                window.y = window.initY
                            }
                        }
                        onClicked: (event) => {
                            if (!modelData) return;
                            if (event.button === Qt.LeftButton) {
                                GlobalStates.overviewOpen = false
                                FhtcIpc.dispatch("focus-window", { "window-id": modelData.id })
                                event.accepted = true
                            } else if (event.button === Qt.MiddleButton) {
                                FhtcIpc.dispatch("close-window", { "window-id": modelData.id })
                                event.accepted = true
                            }
                        }

                        StyledToolTip {
                            extraVisibleCondition: false
                            alternativeVisibleCondition: dragArea.containsMouse && !window.Drag.active
                            text: `${modelData.title}\n[${modelData["app-id"]}]\n`
                        }
                    }
                }
            }

            Rectangle { // Focused workspace indicator
                id: focusedWorkspaceIndicator
                property int activeWorkspaceInGroup: (monitor["active-workspace-idx"] ?? 0) - (root.workspaceGroup * root.workspacesShown)
                property int activeWorkspaceRowIndex: Math.floor(activeWorkspaceInGroup / Config.options.overview.numOfCols)
                property int activeWorkspaceColIndex: activeWorkspaceInGroup % Config.options.overview.numOfCols
                x: (root.workspaceImplicitWidth + workspaceSpacing) * activeWorkspaceColIndex
                y: (root.workspaceImplicitHeight + workspaceSpacing) * activeWorkspaceRowIndex
                z: root.windowZ
                width: root.workspaceImplicitWidth
                height: root.workspaceImplicitHeight
                color: "transparent"
                radius: Appearance.rounding.screenRounding * root.scale
                border.width: 2
                border.color: root.activeBorderColor
                Behavior on x {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                Behavior on y {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
            }
        }
    }
}
