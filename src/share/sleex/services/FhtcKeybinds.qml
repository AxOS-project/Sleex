pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import SleexUiKit.Functions
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property string keybindParserPath: FileUtils.trimFileProtocol(`${Directories.scriptsPath}/fht/get_keybinds.py`)
    property string defaultKeybindConfigPath: "/etc/sleex/compositor/keybinds.toml"
    property string appKeybindConfigPath: FileUtils.trimFileProtocol(`${Directories.config}/fht/apps.toml`)
    property string userKeybindConfigPath: FileUtils.trimFileProtocol(`${Directories.config}/fht/custom/keybinds.toml`)

    property var keybinds: []
    property var keybindCategories: []

    property var defaultKeybinds: ({ categories: [], keybinds: [] })
    property var appKeybinds: ({ categories: [], keybinds: [] })
    property var userKeybinds: ({ categories: [], keybinds: [] })

    function refresh() {
        getDefaultKeybinds.running = true
        getAppKeybinds.running = true
        getUserKeybinds.running = true
    }

    function mergeKeybinds() {
        const allCategories = []
        const allBinds = []

        const sources = [root.defaultKeybinds, root.appKeybinds, root.userKeybinds]
        for (let s = 0; s < sources.length; ++s) {
            const src = sources[s]
            if (!src)
                continue

            const cats = src.categories ?? []
            for (let i = 0; i < cats.length; ++i) {
                if (cats[i] && !allCategories.includes(cats[i]))
                    allCategories.push(cats[i])
            }

            const binds = src.keybinds ?? []
            for (let i = 0; i < binds.length; ++i) {
                const kb = binds[i]
                if (!kb || !kb.description)
                    continue
                const colonIdx = kb.description.indexOf(":")
                if (colonIdx > 0) {
                    const group = kb.description.substring(0, colonIdx)
                    if (!allCategories.includes(group))
                        allCategories.push(group)
                }
                allBinds.push(kb)
            }
        }

        root.keybindCategories = allCategories
        root.keybinds = allBinds
    }

    Process {
        id: getDefaultKeybinds
        running: true
        command: ["python3", root.keybindParserPath, "--path", root.defaultKeybindConfigPath]

        stdout: SplitParser {
            onRead: data => {
                try {
                    root.defaultKeybinds = JSON.parse(data)
                    root.mergeKeybinds()
                } catch (e) {
                    console.error("[FhtcKeybinds] Error parsing default keybinds:", e)
                }
            }
        }
    }

    Process {
        id: getAppKeybinds
        running: true
        command: ["python3", root.keybindParserPath, "--path", root.appKeybindConfigPath]

        stdout: SplitParser {
            onRead: data => {
                try {
                    root.appKeybinds = JSON.parse(data)
                    root.mergeKeybinds()
                } catch (e) {
                    console.error("[FhtcKeybinds] Error parsing app keybinds:", e)
                }
            }
        }
    }

    Process {
        id: getUserKeybinds
        running: true
        command: ["python3", root.keybindParserPath, "--path", root.userKeybindConfigPath]

        stdout: SplitParser {
            onRead: data => {
                try {
                    root.userKeybinds = JSON.parse(data)
                    root.mergeKeybinds()
                } catch (e) {
                    console.error("[FhtcKeybinds] Error parsing user keybinds:", e)
                }
            }
        }
    }
}
