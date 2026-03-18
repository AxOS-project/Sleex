import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
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

    function openDashboard(): void {
        GlobalStates.dashboardOpen = true
        Notifications.timeoutAll()
    }
    function closeDashboard(): void { GlobalStates.dashboardOpen = false }
    function toggleDashboard(): void {
        if (GlobalStates.dashboardOpen) closeDashboard()
        else openDashboard()
    }

    PanelWindow {
        id: dashboardRoot
        visible: true
        function hide(): void { dashboardScope.closeDashboard() }

        exclusiveZone: 0
        implicitWidth: Screen.width
        implicitHeight: Screen.height
        WlrLayershell.namespace: "quickshell:dashboard"
        WlrLayershell.layer: WlrLayer.Overlay
        color: "transparent"
        mask: GlobalStates.dashboardOpen ? null : emptyRegion

        Region { id: emptyRegion }

        HyprlandFocusGrab {
            id: grab
            windows: [ dashboardRoot ]
            active: GlobalStates.dashboardOpen
            onCleared: () => { if (!active) dashboardRoot.hide() }
        }

        Item {
            id: scaleWrapper
            anchors.centerIn: parent
            width: 1500
            height: 900
            scale: dashboardScale

            property bool isAnimating: false
            property bool slideAnimEnabled: false
            property string animDir: ""
            property int animDuration: Config.options.dashboard.animationDuration

            // Divide by dashboardScale because the Translate operates in
            // scaleWrapper's local (pre-scale) coordinate space. Without this,
            // the actual screen movement is target * dashboardScale, which
            // under-shoots at scale < 1 and over-shoots at scale > 1.
            readonly property int targetX: animDir === "left"  ? -dashboardRoot.width  / dashboardScale
                                         : animDir === "right" ?  dashboardRoot.width  / dashboardScale : 0
            readonly property int targetY: animDir === "up"    ? -dashboardRoot.height / dashboardScale
                                         : animDir === "down"  ?  dashboardRoot.height / dashboardScale : 0

            Component.onCompleted: {
                animDir = Config.options.dashboard.animationDirection
                Qt.callLater(() => { slideAnimEnabled = true })
            }

            // Keep loader visible for the full duration of the close animation.
            Connections {
                target: GlobalStates
                function onDashboardOpenChanged() {
                    scaleWrapper.isAnimating = true
                    closeHoldTimer.restart()
                }
            }
            Timer {
                id: closeHoldTimer
                interval: Config.options.dashboard.animationDuration + 50
                onTriggered: scaleWrapper.isAnimating = false
            }

            Connections {
                target: Config.options.dashboard
                function onAnimationDirectionChanged() {
                    scaleWrapper.slideAnimEnabled = false
                    scaleWrapper.animDir = Config.options.dashboard.animationDirection
                    Qt.callLater(() => { scaleWrapper.slideAnimEnabled = true })
                }
            }

            Loader {
                id: dashboardContentLoader
                active: true
                // Load content on a background thread — zero main-thread
                // blocking at startup, content is ready before first open.
                asynchronous: true
                visible: GlobalStates.dashboardOpen || scaleWrapper.isAnimating

                // Keep the layer always primed so the GPU texture is ready
                // the instant an animation begins — no first-frame stall.
                layer.enabled: true
                layer.smooth: true
                
                // disabling it removes a per-frame GPU filtering pass.

                transform: Translate {
                    x: GlobalStates.dashboardOpen ? 0 : scaleWrapper.targetX
                    y: GlobalStates.dashboardOpen ? 0 : scaleWrapper.targetY
                    Behavior on x {
                        enabled: scaleWrapper.slideAnimEnabled
                        NumberAnimation {
                            duration: scaleWrapper.animDuration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: [0.4, 0.0, 0.2, 1.0, 1.0, 1.0]
                        }
                    }
                    Behavior on y {
                        enabled: scaleWrapper.slideAnimEnabled
                        NumberAnimation {
                            duration: scaleWrapper.animDuration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: [0.4, 0.0, 0.2, 1.0, 1.0, 1.0]
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
                focus: GlobalStates.dashboardOpen
                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) dashboardRoot.hide()
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
                                    text: StringUtils.format(qsTr("Uptime: {0}"), DateTime.uptime)
                                }

                                Item { Layout.fillWidth: true }

                                ButtonGroup {
                                    QuickToggleButton {
                                        toggled: false
                                        buttonIcon: "restart_alt"
                                        onClicked: {
                                            Hyprland.dispatch("reload")
                                            Quickshell.reload(true)
                                        }
                                        StyledToolTip { text: qsTr("Reload Hyprland & Quickshell") }
                                    }
                                    QuickToggleButton {
                                        toggled: false
                                        buttonIcon: "settings"
                                        onClicked: {
                                            Quickshell.execDetached(["qs", "-p", "/usr/share/sleex/settings.qml"])
                                            dashboardScope.closeDashboard()
                                        }
                                        StyledToolTip { text: qsTr("Settings") }
                                    }
                                    QuickToggleButton {
                                        toggled: false
                                        buttonIcon: "power_settings_new"
                                        onClicked: Hyprland.dispatch("global quickshell:sessionOpen")
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
                                onCurrentTabChanged: {
                                    if (currentTab === "greetings")
                                        Notifications.timeoutAll()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "dashboard"
        function toggle(): void { dashboardScope.toggleDashboard() }
        function close(): void  { dashboardScope.closeDashboard()  }
        function open(): void   { dashboardScope.openDashboard()   }
    }

    GlobalShortcut {
        name: "dashboardToggle"
        description: qsTr("Toggles dashboard on press")
        onPressed: dashboardScope.toggleDashboard()
    }
    GlobalShortcut {
        name: "dashboardOpen"
        description: qsTr("Opens dashboard on press")
        onPressed: dashboardScope.openDashboard()
    }
    GlobalShortcut {
        name: "dashboardClose"
        description: qsTr("Closes dashboard on press")
        onPressed: dashboardScope.closeDashboard()
    }
}
