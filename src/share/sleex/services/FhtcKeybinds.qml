pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
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
        id: getDefaultKeybinds
        running: true
        command: ["python", root.keybindParserPath, "--path", root.defaultKeybindConfigPath,]
        
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.defaultKeybinds = JSON.parse(data)
                } catch (e) {
                    console.error("[CheatsheetKeybinds] Error parsing keybinds:", e)
                }
            }
        }
    }

    Process {
        id: getUserKeybinds
        running: true
        command: [root.keybindParserPath, "--path", root.userKeybindConfigPath]
        
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.userKeybinds = JSON.parse(data)
                } catch (e) {
                    console.error("[CheatsheetKeybinds] Error parsing keybinds:", e)
                }
            }
        }
    }
}

