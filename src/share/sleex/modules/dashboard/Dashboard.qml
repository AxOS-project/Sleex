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
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Bluetooth

Scope {
    property int dashboardWidth: Appearance.sizes.dashboardWidth
    property int dashboardPadding: 15
    property real dashboardScale: Config.options.dashboard.dasboardScale

    PanelWindow {
        id: dashboardRoot
        visible: GlobalStates.dashboardOpen
        exclusiveZone: 0
        implicitWidth: 1500
        implicitHeight: 900
        color: "transparent"
        WlrLayershell.namespace: "quickshell:dashboard"

        function hide(): void {
            GlobalStates.dashboardOpen = false
        }

        HyprlandFocusGrab {
            id: grab
            windows: [dashboardRoot]
            active: GlobalStates.dashboardOpen
            onCleared: if (!active) dashboardRoot.hide()
        }

        Loader {
            id: dashboardContentLoader
            active: GlobalStates.dashboardOpen
            anchors.fill: parent
            anchors.margins: Appearance.sizes.hyprlandGapsOut
            focus: GlobalStates.dashboardOpen

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape)
                    dashboardRoot.hide()
            }

            sourceComponent: Item {
                anchors.centerIn: parent
                transformOrigin: Item.Center
                scale: dashboardScale

                StyledRectangularShadow {
                    target: dashboardBackground
                    visible: Config.options.appearance.transparency
                }

                Rectangle {
                    id: dashboardBackground
                    anchors.fill: parent
                    color: Appearance.colors.colLayer0
                    radius: Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: dashboardPadding
                        spacing: dashboardPadding

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Layout.topMargin: 5

                            Item {
                                implicitWidth: distroIcon.width
                                implicitHeight: distroIcon.height
                                CustomIcon {
                                    id: distroIcon
                                    width: 30
                                    height: 30
                                    source: SystemInfo.distroIcon
                                }
                                ColorOverlay {
                                    anchors.fill: distroIcon
                                    source: distroIcon
                                    color: Appearance.colors.colOnLayer0
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
                                    buttonIcon: "restart_alt"
                                    onClicked: {
                                        Hyprland.dispatch("reload")
                                        Quickshell.reload(true)
                                    }
                                    StyledToolTip { text: qsTr("Reload Hyprland & Quickshell") }
                                }

                                QuickToggleButton {
                                    buttonIcon: "settings"
                                    onClicked: {
                                        Quickshell.execDetached(["qs", "-p", "/usr/share/sleex/settings.qml"])
                                        dashboardRoot.hide()
                                    }
                                    StyledToolTip { text: qsTr("Settings") }
                                }

                                QuickToggleButton {
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
                            onCurrentTabChanged: if (currentTab === "greetings") Notifications.timeoutAll()
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "dashboard"

        function toggle(): void {
            GlobalStates.dashboardOpen = !GlobalStates.dashboardOpen
            if (GlobalStates.dashboardOpen) Notifications.timeoutAll()
        }

        function close(): void {
            GlobalStates.dashboardOpen = false
        }

        function open(): void {
            GlobalStates.dashboardOpen = true
            Notifications.timeoutAll()
        }
    }

    GlobalShortcut {
        name: "dashboardToggle"
        description: qsTr("Toggles dashboard on press")
        onPressed: {
            GlobalStates.dashboardOpen = !GlobalStates.dashboardOpen
            if (GlobalStates.dashboardOpen) Notifications.timeoutAll()
        }
    }

    GlobalShortcut {
        name: "dashboardOpen"
        description: qsTr("Opens dashboard on press")
        onPressed: {
            GlobalStates.dashboardOpen = true
            Notifications.timeoutAll()
        }
    }

    GlobalShortcut {
        name: "dashboardClose"
        description: qsTr("Closes dashboard on press")
        onPressed: GlobalStates.dashboardOpen = false
    }
}
