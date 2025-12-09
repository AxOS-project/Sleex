pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // The socket we connect to. This is the bridge between us and fht-compositor
    readonly property string socketPath: Quickshell.env("FHTC_SOCKET_PATH")

    // How things work here is that we store workspace and window data into separate maps,
    // and actual data structures (like Monitors, or even Workspaces) store IDs. The stored
    // maps are ID->Window/Workspace maps
    //
    // FIXME: Add typing to these.
    property var workspaces: ({})
    property var windows: ({})
    property var space: ({})

    // Focused window is the one that is currently receiving keyboard input. There can be multiple
    // active windows at once, but only one at max focused window can exist at a time.
    property int focusedWindowId: -1
    property var focusedWindow: null
    // The active workspace is the workspace that currently has the pointer on it. This usually means
    // the displayed workspace on the focused monitor.
    property int activeWorkspaceId: -1
    property var activeWorkspace: null

    Socket {
        id: subscribeSocket
        path: root.socketPath
        connected: true

        onConnectionStateChanged: {
            if (connected)
                // When we connect, start turn this socket immediatly into a subcribe
                // socket. Allowing us to actually use it.
                subscribeSocket.write('"subscribe"\n');
        }

        parser: SplitParser {
            onRead: line => {
                try {
                    root.handleEvent(JSON.parse(line));
                } catch (err) {
                    console.warn("FhtCompositor: failed to parse event: ", line, err);
                }
            }
        }
    }

    // The main event handler. The passed in `event` parameter is a fht-compositor-ipc::Event
    // https://github.com/nferhat/fht-compositor/blob/ff3d9f3b6549b38e99755d022f5343fda3d6a971/fht-compositor-ipc/src/lib.rs#L131
    function handleEvent(event) {
        switch (event.event) {
        case "windows":
            // Update the window list. The passed in data is a HashMap<usize, Window>
            root.windows = event.data;
            root.windowsChanged();
            break;
        case "focused-window-changed":
            var newId = event.data.id;
            if (newId == null) {
                root.focusedWindowId = -1;
                root.focusedWindow = null;
            } else {
                // FIXME: Maybe this event could be sent before a WindowChanged event, in this
                // case this could lead to invalid state.
                root.focusedWindowId = newId;
                root.focusedWindow = root.windows[newId];
            }

            root.focusedWindowChanged();
            root.focusedWindowIdChanged();

            break;
        case "window-closed":
            // NOTE: the compositor will sent us a focused-window-changed event, so we don't
            // have to update the focusedWindow here.
            var id = event.data.id;
            delete root.windows[id];

            root.windowsChanged();

            break;
        case "window-changed":
            // This event could either be an existing window changing, or a new window opening
            const win = event.data;
            root.windows[win.id] = win;

            root.windowsChanged();

            break;
        case "workspaces":
            // Update the workspace list. The passed in data is a HashMap<usize, Workspace>
            root.workspaces = event.data;
            root.workspacesChanged();
            break;
        case "active-workspace-changed":
            var newId = event.data.id;
            if (newId == null) {
                root.activeWorkspaceId = -1;
                root.activeWorkspace = null;
            } else {
                // FIXME: Maybe this event could be sent before a WorkspaceChanged event, in this
                // case this could lead to invalid state.
                root.activeWorkspaceId = newId;
                root.activeWorkspace = root.workspaces[newId];
            }

            root.activeWorkspaceChanged();
            root.activeWorkspaceIdChanged();

            break;
        case "workspace-changed":
            const ws = event.data;
            root.workspaces[ws.id] = ws;
            root.workspacesChanged();

            break;
        case "workspace-removed":
            var id = event.data.id;
            delete root.workspaces[id];

            root.workspacesChanged();

            break;
        case "space":
            root.space = event.data;
            root.spaceChanged();
            break;
        default:
            // console.warn("Unhandled fht-compositor event: ", event.event);
            break;
        }
    }

    function dispatch(command, args) {
        var cmd = {
            command: command,
            args: args
        };

        subscribeSocket.write(JSON.stringify(cmd) + "\n");
    }
}
