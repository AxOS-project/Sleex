import qs
import qs.services
import qs.modules.common
import SleexUiKit.Widgets
import SleexUiKit.Functions
import SleexUiKit.Appearance
import Sleex.Utils
import Sleex.Fhtc
import qs.modules.dashboard.quickToggles
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Io
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Bluetooth

Scope {
    id: dashboardScope

    property int dashboardWidth: Appearance.sizes.dashboardWidth
    property int dashboardPadding: 15
    property real dashboardScale: Config.options.dashboard.dashboardScale

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: dashboardRoot
            required property var modelData
            property bool monitorIsFocused: (FhtcMonitors.activeMonitorName === screen.name)
            screen: modelData
            visible: GlobalStates.dashboardOpen && monitorIsFocused

            exclusiveZone: 0
            implicitWidth: Screen.width
            implicitHeight: Screen.height
            WlrLayershell.namespace: "quickshell:dashboard"
            WlrLayershell.layer: GlobalStates.tutorialMode ? WlrLayer.Top : WlrLayer.Overlay
            WlrLayershell.keyboardFocus: GlobalStates.dashboardOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            color: "transparent"
            mask: GlobalStates.dashboardOpen ? null : emptyRegion

            Region { id: emptyRegion }

            MouseArea {
                anchors.fill: parent
                visible: GlobalStates.dashboardOpen && !GlobalStates.tutorialMode
                onPressed: ipc.close()
            }

            Item {
                id: scaleWrapper
                anchors.centerIn: parent
                width: 1500
                height: 900
                scale: dashboardScale

                property bool contentActive: false
                property bool isAnimating: false
                property bool slideAnimEnabled: false
                property bool showAtCenter: false

                property string animDir: Config.options.dashboard.animationDirection
                property int animDuration: Config.options.dashboard.animationDuration

                readonly property int offX: animDir === "left"  ? -dashboardRoot.width  / dashboardScale
                                            : animDir === "right" ? dashboardRoot.width  / dashboardScale : 0
                readonly property int offY: animDir === "up"    ? -dashboardRoot.height / dashboardScale
                                            : animDir === "down"  ? dashboardRoot.height / dashboardScale : 0

                function openFocusedDashboard() {
                    closeHoldTimer.restart()
                    scaleWrapper.isAnimating = true
                    scaleWrapper.contentActive = true
                    if (dashboardContentLoader.status === Loader.Ready) {
                        scaleWrapper.slideAnimEnabled = true
                        scaleWrapper.showAtCenter = true
                    }
                }

                function resetSlideState(unloadContent) {
                    scaleWrapper.slideAnimEnabled = false
                    scaleWrapper.showAtCenter = false
                    if (unloadContent) {
                        scaleWrapper.contentActive = false
                    }
                }

                Component.onCompleted: {
                    if (GlobalStates.dashboardOpen && dashboardRoot.monitorIsFocused) {
                        openFocusedDashboard()
                    }
                }

                Connections {
                    target: GlobalStates
                    function onDashboardOpenChanged() {
                        if (GlobalStates.dashboardOpen) {
                            if (dashboardRoot.monitorIsFocused) {
                                scaleWrapper.openFocusedDashboard()
                            }
                        } else if (scaleWrapper.contentActive || scaleWrapper.isAnimating || scaleWrapper.showAtCenter) {
                            scaleWrapper.isAnimating = false
                            closeHoldTimer.stop()
                            scaleWrapper.resetSlideState(false)
                        }
                    }
                }
                Connections {
                    target: dashboardRoot
                    function onMonitorIsFocusedChanged() {
                        if (dashboardRoot.monitorIsFocused) {
                            if (GlobalStates.dashboardOpen) {
                                scaleWrapper.openFocusedDashboard()
                            }
                        } else {
                            if (!scaleWrapper.isAnimating) {
                                scaleWrapper.resetSlideState(true)
                            }
                        }
                    }
                }
                Timer {
                    id: closeHoldTimer
                    interval: Config.options.dashboard.animationDuration + 50
                    onTriggered: {
                        scaleWrapper.isAnimating = false
                        if (!dashboardRoot.monitorIsFocused) {
                            scaleWrapper.resetSlideState(true)
                        }
                    }
                }

                Connections {
                    target: Config.options.dashboard
                    function onAnimationDirectionChanged() {
                        scaleWrapper.slideAnimEnabled = false
                        scaleWrapper.animDir = Config.options.dashboard.animationDirection
                        if (GlobalStates.dashboardOpen && dashboardRoot.monitorIsFocused) {
                            Qt.callLater(() => { scaleWrapper.slideAnimEnabled = true })
                        }
                    }
                }

                Loader {
                    id: dashboardContentLoader
                    active: scaleWrapper.contentActive && (dashboardRoot.monitorIsFocused || scaleWrapper.isAnimating)
                    asynchronous: true
                    visible: (GlobalStates.dashboardOpen && dashboardRoot.monitorIsFocused) || scaleWrapper.isAnimating


                    onLoaded: {
                        if (!GlobalStates.dashboardOpen || !dashboardRoot.monitorIsFocused) return
                        scaleWrapper.slideAnimEnabled = false
                        scaleWrapper.showAtCenter = false
                        closeHoldTimer.restart()
                        Qt.callLater(() => {
                            if (!GlobalStates.dashboardOpen || !dashboardRoot.monitorIsFocused) return
                            scaleWrapper.slideAnimEnabled = true
                            scaleWrapper.showAtCenter = true
                        })
                    }

                    transform: Translate {
                        x: scaleWrapper.showAtCenter ? 0 : scaleWrapper.offX
                        y: scaleWrapper.showAtCenter ? 0 : scaleWrapper.offY
                        Behavior on x {
                            enabled: scaleWrapper.slideAnimEnabled && (dashboardRoot.monitorIsFocused || scaleWrapper.isAnimating)
                            NumberAnimation {
                                duration: scaleWrapper.animDuration
                                easing.type: Appearance.animation.elementMove.type
                                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                            }
                        }
                        Behavior on y {
                            enabled: scaleWrapper.slideAnimEnabled && (dashboardRoot.monitorIsFocused || scaleWrapper.isAnimating)
                            NumberAnimation {
                                duration: scaleWrapper.animDuration
                                easing.type: Appearance.animation.elementMove.type
                                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                            }
                        }
                    }

                    anchors {
                        top: parent.top
                        bottom: parent.bottom
                        right: parent.right
                        left: parent.left
                        topMargin: Appearance.sizes.hyprlandGapsOut
                        rightMargin: Appearance.sizes.hyprlandGapsOut
                        bottomMargin: Appearance.sizes.hyprlandGapsOut
                        leftMargin: Appearance.sizes.elevationMargin
                    }
                    focus: GlobalStates.dashboardOpen && dashboardRoot.monitorIsFocused
                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape) ipc.close()
                    }

                    sourceComponent: Item {
                        implicitHeight: dashboardBackground.implicitHeight
                        implicitWidth: dashboardBackground.implicitWidth

                        StyledRectangularShadow {
                            target: dashboardBackground
                            visible: Config.options.appearance.transparency
                        }

                        Rectangle {
                            id: dashboardBackground
                            anchors.fill: parent
                            implicitHeight: parent.height - Appearance.sizes.hyprlandGapsOut * 2
                            implicitWidth: dashboardWidth - Appearance.sizes.hyprlandGapsOut * 2
                            color: Appearance.colors.colLayer0
                            radius: Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1

                            MouseArea {
                                anchors.fill: parent
                            }

                            ColumnLayout {
                                spacing: dashboardPadding
                                anchors.fill: parent
                                anchors.margins: dashboardPadding

                                RowLayout {
                                    Layout.fillHeight: false
                                    spacing: 10
                                    Layout.margins: 10
                                    Layout.topMargin: 5
                                    Layout.bottomMargin: 0

                                    Item {
                                        implicitWidth: distroIcon.width
                                        implicitHeight: distroIcon.height

                                        CustomIcon {
                                            id: distroIcon
                                            width: 30
                                            height: 30
                                            source: SystemInfo.distroIcon
                                        }

                                        MultiEffect {
                                            source: distroIcon
                                            anchors.fill: distroIcon
                                            colorization: 1.0
                                            colorizationColor: Appearance.colors.colOnLayer0
                                        }
                                    }

                                    StyledText {
                                        font.pixelSize: Appearance.font.pixelSize.normal
                                        color: Appearance.colors.colOnLayer0
                                        text: qsTr("Uptime: %1").arg(DateTime.uptime)
                                    }

                                    Item { Layout.fillWidth: true }

                                    ButtonGroup {
                                        QuickToggleButton {
                                            visible: dashboardTabs.currentTab === 0
                                            toggled: BentoModel.customizeOpen
                                            buttonIcon: "dashboard_customize"
                                            onClicked: BentoModel.customizeOpen = !BentoModel.customizeOpen
                                            StyledToolTip { text: qsTr("Customize Home Bento Layout") }
                                        }
                                        QuickToggleButton {
                                            toggled: false
                                            buttonIcon: "restart_alt"
                                            onClicked: {
                                                FhtcIpc.dispatch("reload-config")
                                                Quickshell.reload(true)
                                            }
                                            StyledToolTip { text: qsTr("Reload Compositor & Quickshell") }
                                        }
                                        QuickToggleButton {
                                            toggled: false
                                            buttonIcon: "settings"
                                            onClicked: {
                                                Quickshell.execDetached(["qs", "-p", "/usr/share/sleex/settings.qml"])
                                                ipc.close()
                                            }
                                            StyledToolTip { text: qsTr("Settings") }
                                        }
                                        QuickToggleButton {
                                            toggled: false
                                            buttonIcon: "power_settings_new"
                                            onClicked: Quickshell.execDetached(["qs", "-p", "/usr/share/sleex/", "ipc", "call", "session", "open"])
                                            StyledToolTip { text: qsTr("Session") }
                                        }
                                    }

                                    ButtonGroup {
                                        Layout.alignment: Qt.AlignHCenter
                                        spacing: 5
                                        padding: 5
                                        color: Appearance.colors.colLayer1

                                        NetworkToggle {}

                                        Loader {
                                            active: Bluetooth.adapters.values.length > 0
                                            asynchronous: true
                                            sourceComponent: BluetoothToggle {}
                                        }

                                        NightLight {}
                                        IdleInhibitor {}
                                    }
                                }

                                DashboardTabs {
                                    id: dashboardTabs
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.preferredHeight: 600
                                    Layout.preferredWidth: dashboardWidth - dashboardPadding * 2
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        id: ipc
        target: "dashboard"
        function toggle(): void {
            if (GlobalStates.dashboardOpen) close()
            else open()
        }
        function close(): void  { 
            GlobalStates.dashboardOpen = false 
            GlobalStates.tutorialMode = false
        }
        function open(): void   {
            GlobalStates.tutorialMode = false
            GlobalStates.dashboardOpen = true
            Notifications.timeoutAll()
        }
        function openTutorial(): void {
            GlobalStates.tutorialMode = true
            GlobalStates.dashboardOpen = true
            Notifications.timeoutAll()
        }
    }

    GlobalShortcut {
        name: "dashboardToggle"
        description: qsTr("Toggles dashboard on press")
        onPressed: ipc.toggle()
    }
    GlobalShortcut {
        name: "dashboardOpen"
        description: qsTr("Opens dashboard on press")
        onPressed: ipc.open()
    }
    GlobalShortcut {
        name: "dashboardClose"
        description: qsTr("Closes dashboard on press")
        onPressed: ipc.close()
    }
}
