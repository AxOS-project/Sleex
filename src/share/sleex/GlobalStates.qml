
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Sleex.Fhtc
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root

    property bool sidebarLeftOpen: false
    property bool dashboardOpen: false
    property bool overviewOpen: false
    property bool workspaceShowNumbers: false
    property bool superReleaseMightTrigger: true
    property bool wppselectorOpen: false
    property bool screenLocked: false
    property bool desktopWidgetKeyboardFocus: false
    property bool tutorialMode: false

    property real screenZoom: 1
    onScreenZoomChanged: {
        // TODO: Screen zoom is not currently exposed by fht-compositor IPC
    }
    Behavior on screenZoom {
        animation: NumberAnimation {
    duration: Appearance.animation.elementMoveFast.duration
    easing.type: Appearance.animation.elementMoveFast.type
    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
}
    }

    // When user is not reluctant while pressing super, they probably don't need to see workspace numbers
    onSuperReleaseMightTriggerChanged: {
        workspaceShowNumbersTimer.stop()
    }

    Timer {
        id: workspaceShowNumbersTimer
        interval: Config.options.bar.workspaces.showNumberDelay
        // interval: 0
        repeat: false
        onTriggered: {
            workspaceShowNumbers = true
        }
    }

    GlobalShortcut {
        name: "workspaceNumber"
        description: qsTr("Hold to show workspace numbers, release to show icons")

        onPressed: {
            workspaceShowNumbersTimer.start()
        }
        onReleased: {
            workspaceShowNumbersTimer.stop()
            workspaceShowNumbers = false
        }
    }

    IpcHandler {
		target: "zoom"

		function zoomIn() {
            screenZoom = Math.min(screenZoom + 0.4, 3.0)
        }

        function zoomOut() {
            screenZoom = Math.max(screenZoom - 0.4, 1)
        }
	}


    IpcHandler {
        target: "lock"

        function lock() {
            root.screenLocked = true;
        }
    }
    GlobalShortcut {
        name: "lockScreen"
        description: qsTr("Lock screen (obviously)")

        onPressed: {
            root.screenLocked = true;
        }
    }

    IpcHandler {
        target: "background"

        function forceWallpaperReload(newPath: string): void {
            Config.options.background.wallpaperPath = newPath
        }
    }

    signal centerPopupToggleRequested(string screenName)
    signal centerPopupOpenRequested(string screenName)
    signal centerPopupCloseRequested(string screenName)

    IpcHandler {
        target: "centerPopup"

        function toggle(): void {
            root.centerPopupToggleRequested(FhtcMonitors.activeMonitorName ?? "");
        }

        function open(): void {
            root.centerPopupOpenRequested(FhtcMonitors.activeMonitorName ?? "");
        }

        function close(): void {
            root.centerPopupCloseRequested(FhtcMonitors.activeMonitorName ?? "");
        }
    }

    GlobalShortcut {
        name: "centerPopupToggle"
        description: qsTr("Toggle center bar popup on focused screen")

        onPressed: {
            root.centerPopupToggleRequested(FhtcMonitors.activeMonitorName ?? "");
        }
    }
}
