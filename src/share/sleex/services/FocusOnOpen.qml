pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.modules.common

/**
 * Focuses a window as soon as it opens. With follow_mouse the focus would otherwise
 * stay on whatever is under the cursor until the mouse moves.
 */
Singleton {
    id: root

    readonly property bool enabled: Config.options.interactions.focusOnOpen

    function init() {} // Referencing the singleton is enough to load it

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (!root.enabled || event.name !== "openwindow" || GlobalStates.screenLocked)
                return;

            // openwindow data: address,workspaceName,class,title
            const [address, workspace, windowClass] = event.data.split(",");
            // Skip windows without a class (menus, tooltips) and windows opened on a workspace that is not in front
            if (!windowClass || workspace !== Hyprland.focusedWorkspace?.name)
                return;

            Hyprland.dispatch(`hl.dsp.focus({ window = "address:0x${address}" })`);
        }
    }
}
