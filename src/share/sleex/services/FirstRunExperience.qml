pragma Singleton

import qs.modules.common.functions
import qs.modules.common
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root
    property string firstRunFilePath: `${Directories.state}/sleex/user/first_run.txt`
    property string firstRunFileContent: "This file is just here to confirm you've been greeted :>"
    property string defaultWallpaperPath: FileUtils.trimFileProtocol(`/usr/share/sleex/wallpapers/SleexOne.png`)
    property string welcomeNotifTitle: "Welcome to Sleex!"
    property string welcomeNotifBody: "First run? 👀 For a list of keybinds, hit Super + F1"

    function load() {
        firstRunFileView.reload()
    }

    function handleFirstRun() {
        Quickshell.execDetached(["bash", "-c", `${Directories.wallpaperSwitchScriptPath} ${root.defaultWallpaperPath} --mode dark`])
        Quickshell.execDetached(['bash', '-c', `sleep 0.5; notify-send '${root.welcomeNotifTitle}' '${root.welcomeNotifBody}' -a 'Sleex' &`])
        //Quickshell.reload(true)
    }


    FileView {
        id: firstRunFileView
        path: Qt.resolvedUrl(firstRunFilePath)
        onLoadFailed: (error) => {
            if (error == FileViewError.FileNotFound) {
                root.handleFirstRun()
                firstRunFileView.setText(root.firstRunFileContent)
            }
        }
    }
}
