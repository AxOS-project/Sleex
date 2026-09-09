pragma Singleton

import SleexUiKit.Functions
import qs.modules.common
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root
    property string firstRunFilePath: `${Directories.state}/sleex/user/first_run.txt`
    property string firstRunFileContent: "This file is just here to confirm you've been greeted :>"
    property string defaultWallpaperPath: FileUtils.trimFileProtocol(`/usr/share/backgrounds/sleex/twentySix.jpg`) 
    property string welcomeNotifTitle: "Welcome to Sleex!"

    function load() {
        firstRunFileView.reload()
    }

    function handleFirstRun() {
        Quickshell.execDetached(["bash", "-c", `hypnos install && hypnos enable && hypnos start`])
        Quickshell.execDetached(["bash", "-c", `${Directories.wallpaperSwitchScriptPath} ${root.defaultWallpaperPath} --mode dark`])
        Quickshell.execDetached(['/bin/sleex-welcome-screen'])
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
