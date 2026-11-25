import qs
import qs.services
import qs.modules.common
import SleexUiKit.Widgets
import SleexUiKit.Functions
import SleexUiKit.Appearance
import Sleex.Fhtc
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Wayland

Item {
    id: root
    required property var panelWindow
    readonly property string screenName: panelWindow.screen.name
    readonly property var monitor: FhtcMonitors.monitors[screenName] ?? null
    readonly property int workspacesShown: Config.options.overview.numOfRows * Config.options.overview.numOfCols
    readonly property int activeWorkspaceIndex: monitor?.["active-workspace-idx"] ?? 0
    readonly property int workspaceGroup: Math.floor(activeWorkspaceIndex / workspacesShown)
    property bool monitorIsFocused: (FhtcMonitors.activeMonitorName === screenName)
    property real scale: Config.options.overview.scale
    property color activeBorderColor: Appearance.colors.colSecondary

    property real workspaceImplicitWidth: panelWindow.screen.width * root.scale
    property real workspaceImplicitHeight: panelWindow.screen.height * root.scale

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

        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout { // Workspaces
            id: workspaceColumnLayout

            z: root.workspaceZ
            anchors.centerIn: parent
            spacing: workspaceSpacing
            Repeater {
                model: Config.options.overview.numOfRows
                delegate: RowLayout {
                    id: row
                    required property int index
                    property int rowIndex: index
                    spacing: workspaceSpacing

                    Repeater { // Workspace repeater
                        model: Config.options.overview.numOfCols
                        Rectangle { // Workspace
                            id: workspace
                            required property int index
                            property int colIndex: index
                            readonly property int wsIndex: root.workspaceGroup * root.workspacesShown + row.rowIndex * Config.options.overview.numOfCols + colIndex
                            property int workspaceValue: wsIndex + 1
                            readonly property int workspaceId: root.monitor?.workspaces?.[wsIndex] ?? -1
                            property color defaultWorkspaceColor: Appearance.colors.colLayer1
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
                                        if (workspace.workspaceId >= 0) {
                                            FhtcIpc.dispatch("focus-workspace", { "workspace-id": workspace.workspaceId })
                                        } else {
                                            FhtcIpc.dispatch("focus-workspace-by-index", { "workspace-idx": workspace.wsIndex })
                                        }
                                    }
                                }
                            }

                            DropArea {
                                anchors.fill: parent
                                onEntered: {
                                    root.draggingTargetWorkspace = workspace.workspaceId
                                    if (root.draggingFromWorkspace == root.draggingTargetWorkspace) return;
                                    hoveredWhileDragging = true
                                }
                                onExited: {
                                    hoveredWhileDragging = false
                                    if (root.draggingTargetWorkspace == workspace.workspaceId) root.draggingTargetWorkspace = -1
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
                        const monWs = root.monitor?.workspaces ?? []
                        const start = root.workspaceGroup * root.workspacesShown
                        const visibleWsIds = monWs.slice(start, start + root.workspacesShown)
                        return Object.values(FhtcWorkspaces.windows ?? {}).filter(win => visibleWsIds.includes(win["workspace-id"]))
                    }
                }
                delegate: OverviewWindow {
                    id: window
                    required property var modelData
                    windowData: modelData
                    scale: root.scale
                    availableWorkspaceWidth: root.workspaceImplicitWidth
                    availableWorkspaceHeight: root.workspaceImplicitHeight

                    readonly property int wsIndexInMonitor: {
                        const monWs = root.monitor?.workspaces ?? []
                        const idx = monWs.indexOf(windowData?.["workspace-id"])
                        return idx >= 0 ? idx : 0
                    }

                    property bool atInitPosition: (initX == x && initY == y)
                    restrictToWorkspace: Drag.active || atInitPosition

                    property int workspaceColIndex: wsIndexInMonitor % Config.options.overview.numOfCols
                    property int workspaceRowIndex: Math.floor((wsIndexInMonitor % root.workspacesShown) / Config.options.overview.numOfCols)
                    xOffset: (root.workspaceImplicitWidth + workspaceSpacing) * workspaceColIndex
                    yOffset: (root.workspaceImplicitHeight + workspaceSpacing) * workspaceRowIndex

                    Timer {
                        id: updateWindowPosition
                        interval: Config.options.hacks.arbitraryRaceConditionDelay
                        repeat: false
                        running: false
                        onTriggered: {
                            window.x = Math.round(Math.max((windowData?.location?.[0] ?? 0) * root.scale, 0) + xOffset)
                            window.y = Math.round(Math.max((windowData?.location?.[1] ?? 0) * root.scale, 0) + yOffset)
                        }
                    }

                    z: atInitPosition ? root.windowZ : root.windowDraggingZ
                    Drag.hotSpot.x: targetWindowWidth / 2
                    Drag.hotSpot.y: targetWindowHeight / 2
                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: hovered = true
                        onExited: hovered = false
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        drag.target: parent
                        onPressed: {
                            root.draggingFromWorkspace = windowData?.["workspace-id"] ?? -1
                            window.pressed = true
                            window.Drag.active = true
                            window.Drag.source = window
                        }
                        onReleased: {
                            const targetWorkspace = root.draggingTargetWorkspace
                            window.pressed = false
                            window.Drag.active = false
                            root.draggingFromWorkspace = -1
                            if (targetWorkspace !== -1 && targetWorkspace !== windowData?.["workspace-id"]) {
                                FhtcIpc.dispatch("send-window-to-workspace", {
                                    "window-id": windowData.id,
                                    "workspace-id": targetWorkspace
                                })
                                updateWindowPosition.restart()
                            } else {
                                window.x = window.initX
                                window.y = window.initY
                            }
                        }
                        onClicked: (event) => {
                            if (!windowData) return;

                            if (event.button === Qt.LeftButton) {
                                GlobalStates.overviewOpen = false
                                FhtcIpc.dispatch("focus-window", { "window-id": windowData.id })
                                event.accepted = true
                            } else if (event.button === Qt.MiddleButton) {
                                FhtcIpc.dispatch("close-window", { "window-id": windowData.id, "kill": false })
                                event.accepted = true
                            }
                        }

                        StyledToolTip {
                            extraVisibleCondition: false
                            alternativeVisibleCondition: dragArea.containsMouse && !window.Drag.active
                            text: `${windowData?.title ?? ""}\n[${windowData?.["app-id"] ?? ""}]\n`
                        }
                    }
                }
            }

            Rectangle { // Focused workspace indicator
                id: focusedWorkspaceIndicator
                property int activeWorkspaceInGroup: root.activeWorkspaceIndex - (root.workspaceGroup * root.workspacesShown)
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
                    animation: NumberAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Appearance.animation.elementMoveFast.type
                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                    }
                }
                Behavior on y {
                    animation: NumberAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Appearance.animation.elementMoveFast.type
                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                    }
                }
            }
        }
    }
}
