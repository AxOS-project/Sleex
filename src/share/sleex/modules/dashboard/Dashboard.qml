import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import "./quickToggles/"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import Quickshell.Io
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Bluetooth

import Sleex.Services

Scope {
    property int dashboardWidth: Appearance.sizes.dashboardWidth
    property int dashboardPadding: 15

    PanelWindow {
        id: dashboardRoot
        visible: GlobalStates.dashboardOpen

        function hide() {
            GlobalStates.dashboardOpen = false
        }

        exclusiveZone: 0
        implicitWidth: 1500
        implicitHeight: 900
        WlrLayershell.namespace: "quickshell:dashboard"
        // Hyprland 0.49: Focus is always exclusive and setting this breaks mouse focus grab
        // WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        color: "transparent"

        HyprlandFocusGrab {
            id: grab
            windows: [ dashboardRoot ]
            active: GlobalStates.dashboardOpen
            onCleared: () => {
                if (!active) dashboardRoot.hide()
            }
        }


        Loader {
            id: dashboardContentLoader
            active: GlobalStates.dashboardOpen
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
            width: dashboardWidth - Appearance.sizes.hyprlandGapsOut - Appearance.sizes.elevationMargin
            height: parent.height - Appearance.sizes.hyprlandGapsOut * 2

            focus: GlobalStates.dashboardOpen
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    dashboardRoot.hide();
                }
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

                            Item {
                                Layout.fillWidth: true
                            }

                            ButtonGroup {
                                QuickToggleButton {
                                    toggled: false
                                    buttonIcon: "restart_alt"
                                    onClicked: {
                                        Hyprland.dispatch("reload")
                                        Quickshell.reload(true)
                                    }
                                    StyledToolTip {
                                        content: qsTr("Reload Hyprland & Quickshell")
                                    }
                                }
                                QuickToggleButton {
                                    toggled: false
                                    buttonIcon: "settings"
                                    onClicked: {
                                        Quickshell.execDetached(["qs", "-p", "/usr/share/sleex/settings.qml"])
                                        GlobalStates.dashboardOpen = false
                                    }
                                    StyledToolTip {
                                        content: qsTr("Settings")
                                    }
                                }
                                QuickToggleButton {
                                    toggled: false
                                    buttonIcon: "power_settings_new"
                                    onClicked: {
                                        Hyprland.dispatch("global quickshell:sessionOpen")
                                    }
                                    StyledToolTip {
                                        content: qsTr("Session")
                                    }
                                }
                            }
                            ButtonGroup {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 5
                                padding: 5
                                color: Appearance.colors.colLayer1

                                NetworkToggle {}
                                Loader {
                                    active: Bluetooth.adapters != undefined
                                    sourceComponent: BluetoothToggle {}
                                }
                                NightLight {}
                                IdleInhibitor {}
                            }

                        }


                        // Center widget group
                        DashboardTabs {
                            id: dashboardTabs
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.preferredHeight: 600
                            Layout.preferredWidth: dashboardWidth - dashboardPadding * 2

                            onCurrentTabChanged: {
                                if (currentTab === "greetings") {
                                    Notifications.timeoutAll();
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

        function toggle(): void {
            GlobalStates.dashboardOpen = !GlobalStates.dashboardOpen;
            if(GlobalStates.dashboardOpen) Notifications.timeoutAll();
        }

        function close(): void {
            GlobalStates.dashboardOpen = false;
        }

        function open(): void {
            GlobalStates.dashboardOpen = true;
            Notifications.timeoutAll();
        }
    }

    GlobalShortcut {
        name: "dashboardToggle"
        description: qsTr("Toggles dashboard on press")

        onPressed: {
            GlobalStates.dashboardOpen = !GlobalStates.dashboardOpen;
            if(GlobalStates.dashboardOpen) Notifications.timeoutAll();
        }
    }
    GlobalShortcut {
        name: "dashboardOpen"
        description: qsTr("Opens dashboard on press")

        onPressed: {
            GlobalStates.dashboardOpen = true;
            Notifications.timeoutAll();
        }
    }
    GlobalShortcut {
        name: "dashboardClose"
        description: qsTr("Closes dashboard on press")

        onPressed: {
            GlobalStates.dashboardOpen = false;
        }
    }

}
