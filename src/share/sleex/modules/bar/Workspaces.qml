import qs
import qs.services
import qs.modules.common
import SleexUiKit.Widgets
import SleexUiKit.Functions
import SleexUiKit.Appearance
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects
import Sleex.Fhtc

Item {
    id: root
    required property var bar
    property bool borderless: Config.options.bar.borderless
    readonly property string screenName: bar.screen.name
    readonly property var monitor: FhtcMonitors.monitors[screenName] ?? null
    readonly property var activeWindow: FhtcWorkspaces.focusedWindow
    readonly property bool hasActiveWindow: activeWindow !== null && activeWindow !== undefined && Object.keys(activeWindow).length > 0

    readonly property var screenWorkspaces: {
        const monWsIds = monitor?.workspaces
        const all = FhtcWorkspaces.workspaces
        if (!all)
            return []
        if (monWsIds && monWsIds.length > 0) {
            return monWsIds.map(id => all[String(id)]).filter(ws => ws !== undefined)
        }
        return Object.values(all)
            .filter(ws => ws.output === root.screenName)
            .sort((a, b) => a.id - b.id)
    }

    readonly property int activeWorkspaceIndex: monitor?.["active-workspace-idx"] ?? 0
    readonly property int workspaceGroup: Math.floor(activeWorkspaceIndex / Config.options.bar.workspaces.shown)
    property list<bool> workspaceOccupied: []
    property int widgetPadding: 0
    property int horizontalPadding: 5
    property int workspaceButtonWidth: 30
    property real workspaceIconSize: workspaceButtonWidth * 0.6
    property real workspaceIconSizeShrinked: workspaceButtonWidth * 0.55
    property real workspaceIconOpacityShrinked: 1
    property real workspaceIconMarginShrinked: -4
    property int workspaceIndexInGroup: activeWorkspaceIndex % Config.options.bar.workspaces.shown

    property bool useMaterialIcons: Config.options.bar.workspaces.useMaterialIcons

    function biggestWindowForWorkspace(workspaceId) {
        if (workspaceId === undefined || workspaceId < 0)
            return null
        const wins = Object.values(FhtcWorkspaces.windows ?? {}).filter(w => w["workspace-id"] === workspaceId)
        if (wins.length === 0)
            return null
        return wins.reduce((best, win) => {
            const bestArea = (best.size?.[0] ?? 0) * (best.size?.[1] ?? 0)
            const winArea = (win.size?.[0] ?? 0) * (win.size?.[1] ?? 0)
            return winArea > bestArea ? win : best
        }, wins[0])
    }

    function updateWorkspaceOccupied() {
        const shown = Config.options.bar.workspaces.shown
        const base = workspaceGroup * shown
        workspaceOccupied = Array.from({ length: shown }, (_, i) => {
            const ws = screenWorkspaces[base + i]
            return ws ? ((ws.windows?.length ?? 0) > 0) : false
        })
    }

    Component.onCompleted: updateWorkspaceOccupied()
    onScreenWorkspacesChanged: updateWorkspaceOccupied()
    onWorkspaceGroupChanged: updateWorkspaceOccupied()

    Connections {
        target: FhtcWorkspaces
        function onWorkspacesChanged() { root.updateWorkspaceOccupied() }
        function onWindowsChanged() { root.updateWorkspaceOccupied() }
    }

    implicitWidth: rowLayout.implicitWidth + horizontalPadding * 2
    implicitHeight: 40

    // Scroll to switch workspaces
    WheelHandler {
        onWheel: (event) => {
            if (event.angleDelta.y < 0)
                FhtcIpc.dispatch("focus-next-workspace")
            else if (event.angleDelta.y > 0)
                FhtcIpc.dispatch("focus-previous-workspace")
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
                    property var leftOccupied: (workspaceOccupied[index - 1] && !(!root.hasActiveWindow && root.workspaceIndexInGroup === index - 1))
                    property var rightOccupied: (workspaceOccupied[index + 1] && !(!root.hasActiveWindow && root.workspaceIndexInGroup === index + 1))
                    property var radiusLeft: leftOccupied ? 0 : Appearance.rounding.full
                    property var radiusRight: rightOccupied ? 0 : Appearance.rounding.full

                    topLeftRadius: radiusLeft
                    bottomLeftRadius: radiusLeft
                    topRightRadius: radiusRight
                    bottomRightRadius: radiusRight

                    color: ColorUtils.transparentize(Appearance.colors.colSecondaryContainer, 0.4)
                    opacity: (workspaceOccupied[index] && !(!root.hasActiveWindow && root.workspaceIndexInGroup === index)) ? 1 : 0

                    Behavior on opacity {
                        animation: NumberAnimation {
                            duration: Appearance.animation.elementMove.duration
                            easing.type: Appearance.animation.elementMove.type
                            easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                        }
                    }
                    Behavior on radiusLeft {
                        animation: NumberAnimation {
                            duration: Appearance.animation.elementMove.duration
                            easing.type: Appearance.animation.elementMove.type
                            easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                        }
                    }
                    Behavior on radiusRight {
                        animation: NumberAnimation {
                            duration: Appearance.animation.elementMove.duration
                            easing.type: Appearance.animation.elementMove.type
                            easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                        }
                    }
                }
            }
        }

        // Active workspace
        Rectangle {
            z: 2
            property real activeWorkspaceMargin: 2
            implicitHeight: workspaceButtonWidth - activeWorkspaceMargin * 2
            radius: Appearance.rounding.full
            color: Appearance.colors.colPrimary
            anchors.verticalCenter: parent.verticalCenter

            property real idx1: workspaceIndexInGroup
            property real idx2: workspaceIndexInGroup
            x: Math.min(idx1, idx2) * workspaceButtonWidth + activeWorkspaceMargin
            implicitWidth: Math.abs(idx1 - idx2) * workspaceButtonWidth + workspaceButtonWidth - activeWorkspaceMargin * 2

            Behavior on activeWorkspaceMargin {
                animation: NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }
            Behavior on idx1 {
                NumberAnimation {
                    duration: 100
                    easing.type: Easing.OutSine
                }
            }
            Behavior on idx2 {
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
                    readonly property int wsIndexOnMonitor: workspaceGroup * Config.options.bar.workspaces.shown + index
                    property int workspaceValue: wsIndexOnMonitor + 1
                    readonly property int workspaceId: root.screenWorkspaces[wsIndexOnMonitor]?.id ?? -1
                    readonly property bool isActiveWorkspace: root.activeWorkspaceIndex === wsIndexOnMonitor

                    Layout.fillHeight: true
                    onPressed: {
                        if (button.workspaceId >= 0) {
                            FhtcIpc.dispatch("focus-workspace", { "workspace-id": button.workspaceId })
                        }
                    }
                    width: workspaceButtonWidth

                    background: Item {
                        id: workspaceButtonBackground
                        implicitWidth: workspaceButtonWidth
                        implicitHeight: workspaceButtonWidth
                        property var biggestWindow: {
                            const _ = FhtcWorkspaces.windows
                            return root.biggestWindowForWorkspace(button.workspaceId)
                        }
                        readonly property bool hasBiggestWindow: biggestWindow !== null
                        readonly property string biggestWindowClass: biggestWindow?.["app-id"] ?? ""
                        property var mainAppIconSource: (hasBiggestWindow && !root.useMaterialIcons && Config.options?.bar.workspaces.showAppIcons)
                            ? Quickshell.iconPath(AppSearch.guessIcon(biggestWindowClass), "image-missing")
                            : ""

                        property string materialIconName: {
                            if (!hasBiggestWindow || !root.useMaterialIcons || !Config.options?.bar.workspaces.showAppIcons) return ""
                            const winClass = biggestWindowClass.toLowerCase()
                            return AppSearch.materialIconMap[winClass] || "circle"
                        }

                        StyledText {
                            opacity: GlobalStates.workspaceShowNumbers
                                || ((Config.options?.bar.workspaces.alwaysShowNumbers && (!Config.options?.bar.workspaces.showAppIcons || !workspaceButtonBackground.hasBiggestWindow || GlobalStates.workspaceShowNumbers))
                                || (GlobalStates.workspaceShowNumbers && !Config.options?.bar.workspaces.showAppIcons)
                                ) ? 1 : 0
                            z: 3

                            anchors.centerIn: parent
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: Appearance.font.pixelSize.small - ((text.length - 1) * (text !== "10") * 2)
                            text: `${button.workspaceValue}`
                            elide: Text.ElideRight
                            color: button.isActiveWorkspace
                                ? Appearance.m3colors.m3onPrimary
                                : (workspaceOccupied[index]
                                    ? Appearance.m3colors.m3onSecondaryContainer
                                    : Appearance.colors.colOnLayer1Inactive)

                            Behavior on opacity {
                                animation: NumberAnimation {
                                    duration: Appearance.animation.elementMoveFast.duration
                                    easing.type: Appearance.animation.elementMoveFast.type
                                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                }
                            }
                        }

                        Rectangle {
                            id: wsDot
                            opacity: (Config.options?.bar.workspaces.alwaysShowNumbers
                                || GlobalStates.workspaceShowNumbers
                                || (Config.options?.bar.workspaces.showAppIcons && workspaceButtonBackground.hasBiggestWindow)
                                ) ? 0 : 1
                            visible: opacity > 0
                            anchors.centerIn: parent
                            width: workspaceButtonWidth * 0.18
                            height: width
                            radius: width / 2
                            color: button.isActiveWorkspace
                                ? Appearance.m3colors.m3onPrimary
                                : (workspaceOccupied[index]
                                    ? Appearance.m3colors.m3onSecondaryContainer
                                    : Appearance.colors.colOnLayer1Inactive)

                            Behavior on opacity {
                                animation: NumberAnimation {
                                    duration: Appearance.animation.elementMoveFast.duration
                                    easing.type: Appearance.animation.elementMoveFast.type
                                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                }
                            }
                        }

                        Item {
                            anchors.centerIn: parent
                            width: workspaceButtonWidth
                            height: workspaceButtonWidth
                            opacity: !Config.options?.bar.workspaces.showAppIcons ? 0 :
                                (workspaceButtonBackground.hasBiggestWindow && !GlobalStates.workspaceShowNumbers && Config.options?.bar.workspaces.showAppIcons) ?
                                1 : workspaceButtonBackground.hasBiggestWindow ? workspaceIconOpacityShrinked : 0
                            visible: opacity > 0

                            IconImage {
                                id: mainAppIcon
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                anchors.bottomMargin: (!GlobalStates.workspaceShowNumbers && Config.options?.bar.workspaces.showAppIcons) ?
                                    (workspaceButtonWidth - workspaceIconSize) / 2 : workspaceIconMarginShrinked
                                anchors.rightMargin: (!GlobalStates.workspaceShowNumbers && Config.options?.bar.workspaces.showAppIcons) ?
                                    (workspaceButtonWidth - workspaceIconSize) / 2 : workspaceIconMarginShrinked

                                visible: !root.useMaterialIcons

                                source: workspaceButtonBackground.mainAppIconSource
                                implicitSize: (!GlobalStates.workspaceShowNumbers && Config.options?.bar.workspaces.showAppIcons) ? workspaceIconSize : workspaceIconSizeShrinked

                                Behavior on opacity {
                                    animation: NumberAnimation {
                                        duration: Appearance.animation.elementMoveFast.duration
                                        easing.type: Appearance.animation.elementMoveFast.type
                                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                    }
                                }
                                Behavior on anchors.bottomMargin {
                                    animation: NumberAnimation {
                                        duration: Appearance.animation.elementMoveFast.duration
                                        easing.type: Appearance.animation.elementMoveFast.type
                                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                    }
                                }
                                Behavior on anchors.rightMargin {
                                    animation: NumberAnimation {
                                        duration: Appearance.animation.elementMoveFast.duration
                                        easing.type: Appearance.animation.elementMoveFast.type
                                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                    }
                                }
                                Behavior on implicitSize {
                                    animation: NumberAnimation {
                                        duration: Appearance.animation.elementMoveFast.duration
                                        easing.type: Appearance.animation.elementMoveFast.type
                                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                    }
                                }
                            }

                            MaterialSymbol {
                                visible: root.useMaterialIcons
                                text: workspaceButtonBackground.materialIconName
                                iconSize: (!GlobalStates.workspaceShowNumbers) ? workspaceIconSize : workspaceIconSizeShrinked
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                anchors.bottomMargin: (!GlobalStates.workspaceShowNumbers) ?
                                    (workspaceButtonWidth - workspaceIconSize) / 2 - 2 : workspaceIconMarginShrinked
                                anchors.rightMargin: (!GlobalStates.workspaceShowNumbers) ?
                                    (workspaceButtonWidth - workspaceIconSize) / 2 : workspaceIconMarginShrinked
                                color: button.isActiveWorkspace
                                    ? Appearance.m3colors.m3onPrimary
                                    : Appearance.m3colors.m3onSecondaryContainer

                                Behavior on opacity {
                                    animation: NumberAnimation {
                                        duration: Appearance.animation.elementMoveFast.duration
                                        easing.type: Appearance.animation.elementMoveFast.type
                                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                    }
                                }
                                Behavior on anchors.bottomMargin {
                                    animation: NumberAnimation {
                                        duration: Appearance.animation.elementMoveFast.duration
                                        easing.type: Appearance.animation.elementMoveFast.type
                                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                    }
                                }
                                Behavior on anchors.rightMargin {
                                    animation: NumberAnimation {
                                        duration: Appearance.animation.elementMoveFast.duration
                                        easing.type: Appearance.animation.elementMoveFast.type
                                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                    }
                                }
                                Behavior on iconSize {
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
            }
        }
    }
}
