import qs
import qs.modules.common
import qs.services
import SleexUiKit.Widgets
import SleexUiKit.Functions
import SleexUiKit.Appearance
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root
    property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
    property bool hasSystemd: false

    Process {
        id: systemdCheck
        running: true
        command: ["test", "-d", "/run/systemd/system"]
        onExited: (exitCode) => root.hasSystemd = (exitCode === 0)
    }

    Loader {
        id: sessionLoader
        active: false

        sourceComponent: PanelWindow { // Session menu
            id: sessionRoot
            visible: sessionLoader.active
            property string subtitle

            function hide() {
                sessionLoader.active = false
            }

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:session"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: ColorUtils.transparentize(Appearance.m3colors.m3background, 0.3)

            anchors {
                top: true
                left: true
                right: true
            }

            implicitWidth: root.focusedScreen?.width ?? 0
            implicitHeight: root.focusedScreen?.height ?? 0

            MouseArea {
                id: sessionMouseArea
                anchors.fill: parent
                onClicked: {
                    sessionRoot.hide()
                }
            }

            ColumnLayout { // Content column
                anchors.centerIn: parent
                spacing: 15

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        sessionRoot.hide();
                    }
                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 0
                    StyledText { // Title
                        Layout.alignment: Qt.AlignHCenter
                        horizontalAlignment: Text.AlignHCenter
                        font.family: Appearance.font.family.title
                        font.pixelSize: Appearance.font.pixelSize.title
                        font.weight: Font.DemiBold
                        text: qsTr("Session")
                    }

                    StyledText { // Small instruction
                        Layout.alignment: Qt.AlignHCenter
                        horizontalAlignment: Text.AlignHCenter
                        font.family: Appearance.font.family.title
                        font.pixelSize: Appearance.font.pixelSize.normal
                        text: qsTr("Arrow keys to navigate, Enter to select\nEsc or click anywhere to cancel")
                    }
                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 15

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 15

                        SessionActionButton {
                            id: sessionLock
                            focus: sessionRoot.visible
                            buttonIcon: "lock"
                            buttonText: qsTr("Lock")
                            onClicked:  GlobalStates.screenLocked = true;
                            onFocusChanged: { if (focus) sessionRoot.subtitle = buttonText }
                            KeyNavigation.right: sessionSleep
                            KeyNavigation.down: sessionHibernate
                        }
                        SessionActionButton {
                            id: sessionSleep
                            buttonIcon: "dark_mode"
                            buttonText: qsTr("Sleep")
                            onClicked:  { PowerActions.suspend(); sessionRoot.hide() }
                            onFocusChanged: { if (focus) sessionRoot.subtitle = buttonText }
                            KeyNavigation.left: sessionLock
                            KeyNavigation.right: sessionLogout
                            KeyNavigation.down: sessionShutdown
                        }
                        SessionActionButton {
                            id: sessionLogout
                            buttonIcon: "logout"
                            buttonText: qsTr("Logout")
                            onClicked: { Quickshell.execDetached(["pkill", "Hyprland"]); sessionRoot.hide() }
                            onFocusChanged: { if (focus) sessionRoot.subtitle = buttonText }
                            KeyNavigation.left: sessionSleep
                            KeyNavigation.right: sessionTaskManager
                            KeyNavigation.down: sessionReboot
                        }
                        SessionActionButton {
                            id: sessionTaskManager
                            buttonIcon: "browse_activity"
                            buttonText: qsTr("Task Manager")
                            onClicked:  { Quickshell.execDetached(["bash", "-c", `${Config.options.apps.taskManager}`]); sessionRoot.hide() }
                            onFocusChanged: { if (focus) sessionRoot.subtitle = buttonText }
                            KeyNavigation.left: sessionLogout
                            KeyNavigation.down: root.hasSystemd ? sessionFirmwareReboot : null
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 15

                        SessionActionButton {
                            id: sessionHibernate
                            buttonIcon: "downloading"
                            buttonText: qsTr("Hibernate")
                            onClicked: PowerActions.hibernate();
                            onFocusChanged: { if (focus) sessionRoot.subtitle = buttonText }
                            KeyNavigation.up: sessionLock
                            KeyNavigation.right: sessionShutdown
                        }
                        SessionActionButton {
                            id: sessionShutdown
                            buttonIcon: "power_settings_new"
                            buttonText: qsTr("Shutdown")
                            onClicked: PowerActions.poweroff()
                            onFocusChanged: { if (focus) sessionRoot.subtitle = buttonText }
                            KeyNavigation.left: sessionHibernate
                            KeyNavigation.right: sessionReboot
                            KeyNavigation.up: sessionSleep
                        }
                        SessionActionButton {
                            id: sessionReboot
                            buttonIcon: "restart_alt"
                            buttonText: qsTr("Reboot")
                            onClicked: PowerActions.reboot();
                            onFocusChanged: { if (focus) sessionRoot.subtitle = buttonText }
                            KeyNavigation.left: sessionShutdown
                            KeyNavigation.right: root.hasSystemd ? sessionFirmwareReboot : null
                            KeyNavigation.up: sessionLogout
                        }
                        SessionActionButton {
                            id: sessionFirmwareReboot
                            visible: root.hasSystemd
                            buttonIcon: "settings_applications"
                            buttonText: qsTr("Reboot to firmware settings")
                            onClicked: Quickshell.execDetached(["systemctl", "reboot", "--firmware-setup"]);
                            onFocusChanged: { if (focus) sessionRoot.subtitle = buttonText }
                            KeyNavigation.up: sessionTaskManager
                            KeyNavigation.left: sessionReboot
                        }
                    }
                }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    radius: Appearance.rounding.normal
                    implicitHeight: sessionSubtitle.implicitHeight + 10 * 2
                    implicitWidth: sessionSubtitle.implicitWidth + 15 * 2
                    color: Appearance.colors.colTooltip
                    clip: true

                    Behavior on implicitWidth {
                        animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                    }

                    StyledText {
                        id: sessionSubtitle
                        anchors.centerIn: parent
                        color: Appearance.colors.colOnTooltip
                        text: sessionRoot.subtitle
                    }
                }
            }

        }
    }

    Loader {
        id: powerConfirmLoader
        active: false
        property string pendingAction: "poweroff"
        property int secondsLeft: 60

        function cancel() {
            countdownTimer.stop()
            powerConfirmLoader.active = false
        }

        function confirm() {
            countdownTimer.stop()
            powerConfirmLoader.active = false
            PowerActions.run(powerConfirmLoader.pendingAction)
        }

        onActiveChanged: if (active) secondsLeft = 60

        // One shared timer, not one per screen - otherwise each PanelWindow
        // instance from the Variants below would run its own independent
        // countdown, drifting apart and each firing confirm() on its own.
        Timer {
            id: countdownTimer
            interval: 1000
            repeat: true
            running: powerConfirmLoader.active
            onTriggered: {
                powerConfirmLoader.secondsLeft -= 1
                if (powerConfirmLoader.secondsLeft <= 0) powerConfirmLoader.confirm()
            }
        }

        // Mirrors Polkit.qml: shown on every screen via Variants, actual
        // dialog content lives in its own file (PowerConfirmContent.qml).
        sourceComponent: Variants {
            model: Quickshell.screens
            delegate: PanelWindow {
                id: powerConfirmRoot
                required property var modelData
                screen: modelData
                visible: powerConfirmLoader.active

                anchors { top: true; left: true; right: true; bottom: true }
                color: "transparent"
                WlrLayershell.namespace: "quickshell:power-confirm"
                // Exclusive doesn't make sense once this shows on every
                // screen at once via Variants (only one surface can truly
                // hold an exclusive grab) - matches Polkit.qml's own choice
                // here for the same reason.
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
                WlrLayershell.layer: WlrLayer.Overlay
                exclusionMode: ExclusionMode.Ignore

                PowerConfirmContent {
                    anchors.fill: parent
                    pendingAction: powerConfirmLoader.pendingAction
                    secondsLeft: powerConfirmLoader.secondsLeft
                    onCancelRequested: powerConfirmLoader.cancel()
                    onConfirmRequested: powerConfirmLoader.confirm()
                }
            }
        }
    }

    IpcHandler {
        target: "session"

        function toggle(): void {
            sessionLoader.active = !sessionLoader.active;
        }

        function close(): void {
            sessionLoader.active = false;
        }

        function open(): void {
            sessionLoader.active = true;
        }
    }

    GlobalShortcut {
        name: "sessionToggle"
        description: qsTr("Toggles session screen on press")

        onPressed: {
            sessionLoader.active = !sessionLoader.active;
        }
    }

    GlobalShortcut {
        name: "sessionOpen"
        description: qsTr("Opens session screen on press")

        onPressed: {
            sessionLoader.active = true;
        }
    }

    IpcHandler {
        target: "powerConfirm"

        function open(action: string): void {
            powerConfirmLoader.pendingAction = action === "reboot" ? "reboot" : "poweroff";
            powerConfirmLoader.active = true;
        }

        function close(): void {
            powerConfirmLoader.active = false;
        }
    }

    GlobalShortcut {
        name: "powerButtonPressed"
        description: qsTr("Prompts a shutdown confirmation when the power button is pressed")

        onPressed: {
            powerConfirmLoader.pendingAction = "poweroff";
            powerConfirmLoader.active = true;
        }
    }

}
