pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import SleexUiKit.Functions
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

/**
 * A service that provides access to keybinds.
 * Uses the `get_keybinds.py` script to parse comments in config files in a certain format and convert to JSON.
 */
Singleton {
    id: root
    property string keybindParserPath: FileUtils.trimFileProtocol(`/usr/share/sleex/scripts/fht/get_keybinds.py`)
    property string defaultKeybindConfigPath: FileUtils.trimFileProtocol(`/etc/sleex/compositor/keybinds.toml`)
    property string userKeybindConfigPath: FileUtils.trimFileProtocol(`${Directories.config}/fht/custom/keybinds.toml`)
    property var defaultKeybinds: {"children": []}
    property var userKeybinds: {"children": []}
    property var keybinds: ({
        children: [
            ...(defaultKeybinds.children ?? []),
            ...(userKeybinds.children ?? []),
        ]
    })

    Process {
        id: getKeybinds
        running: true
        command: ["hyprctl", "binds", "-j"]
        
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.keybinds = JSON.parse(text)
                    var groups = []
                    for (var i = 0; i < root.keybinds.length; i++) {
                        var bind = root.keybinds[i].description
                        var group = bind.substring(0, bind.indexOf(":"))
                        if (!groups.includes(group) && group.length > 0) {
                            groups.push(group)
                        }
                    }
                    root.keybindCategories = groups
                } catch (e) {
                    console.error("[CheatsheetKeybinds] Error parsing keybinds:", e)
                }
            }
        }
    }
}
