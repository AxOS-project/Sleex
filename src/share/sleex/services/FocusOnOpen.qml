pragma Singleton

import QtQuick
import Quickshell
import Sleex.Fhtc
import qs
import qs.modules.common

/**
 * Focuses a window as soon as it opens on the currently active workspace.
 */
Singleton {
    id: root

    readonly property bool enabled: Config.options.interactions.focusOnOpen

    function init() {} // Referencing the singleton is enough to load it

    Connections {
        target: FhtcWorkspaces

        function onWindowOpened(win) {
            if (!root.enabled || GlobalStates.screenLocked)
                return;

            const appId = win["app-id"] ?? "";
            const workspaceId = win["workspace-id"];
            if (!appId || workspaceId !== FhtcWorkspaces.activeWorkspaceId)
                return;

            FhtcIpc.dispatch("focus-window", { "window-id": win.id });
        }
    }
}
