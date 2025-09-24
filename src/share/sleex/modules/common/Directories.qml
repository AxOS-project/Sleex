pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common.functions
import Qt.labs.platform
import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    // XDG Dirs, with "file://"
    readonly property string config: StandardPaths.standardLocations(StandardPaths.GenericConfigLocation)[0]
    readonly property string state: StandardPaths.standardLocations(StandardPaths.GenericStateLocation)[0]
    readonly property string cache: StandardPaths.writableLocation(StandardPaths.GenericCacheLocation)
    readonly property string pictures: StandardPaths.standardLocations(StandardPaths.PicturesLocation)[0]
    readonly property string downloads: StandardPaths.standardLocations(StandardPaths.DownloadLocation)[0]
    readonly property string home: StandardPaths.standardLocations(StandardPaths.HomeLocation)[0]

    // Other dirs used by the shell, without "file://"
    property string favicons: FileUtils.trimFileProtocol(`${Directories.cache}/sleex/media/favicons`)
    property string coverArt: FileUtils.trimFileProtocol(`${Directories.cache}/sleex/media/coverart`)
    property string latexOutput: FileUtils.trimFileProtocol(`${Directories.cache}/sleex/media/latex`)
    property string shellConfig: FileUtils.trimFileProtocol(`${Directories.home}/.sleex`)
    property string shellConfigName: "settings.json"
    property string shellConfigPath: `${Directories.shellConfig}/${Directories.shellConfigName}`
    property string todoPath: FileUtils.trimFileProtocol(`${Directories.home}/.sleex/user/todo.json`)
    property string notificationsPath: FileUtils.trimFileProtocol(`${Directories.cache}/sleex/notifications/notifications.json`)
    property string generatedMaterialThemePath: FileUtils.trimFileProtocol(`${Directories.state}/sleex/user/generated/colors.json`)
    property string cliphistDecode: FileUtils.trimFileProtocol(`/tmp/sleex/media/cliphist`)
    property string wallpaperSwitchScriptPath: FileUtils.trimFileProtocol('/usr/share/sleex/scripts/colors/switchwall.sh')
    property string wallpaperPath: FileUtils.trimFileProtocol(`${Directories.shellConfig}/wallpapers`)
    property string userAiPrompts: FileUtils.trimFileProtocol(`${Directories.shellConfig}/ai/prompts`)
    property string aiChats: FileUtils.trimFileProtocol(`${Directories.state}/user/ai/chats`)


    // Cleanup on init
    Component.onCompleted: {
        Quickshell.execDetached(['mkdir', '-p', `${shellConfig}`])
        Quickshell.execDetached(["mkdir", "-p", `${favicons}`])
        Quickshell.execDetached(["rm", "-rf", `${coverArt}`, ";", "mkdir", "-p", `${coverArt}`])
        Quickshell.execDetached(["rm", "-rf", `${latexOutput}`, ";", "mkdir", "-p", `${latexOutput}`])
        Quickshell.execDetached(["rm", "-rf", `${cliphistDecode}`, ";", "mkdir", "-p", `${cliphistDecode}`])
        Quickshell.execDetached(["mkdir", "-p", `${aiChats}`])
    }
}
