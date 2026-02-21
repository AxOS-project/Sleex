import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    property var wallpaperList: []
    
    property string wallpaperPath: Config.options.background.wallpaperSelectorPath.lenght != 0 ? Config.options.background.wallpaperSelectorPath : Directories.wallpaperPath

    Process {
        id: listWallpapers
        running: true
        command: [
            "bash", "-c",
            "find " + root.wallpaperPath + " -type f \\( -iname '*.jpg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.webp' \\) -printf '%P\\n'"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                root.wallpaperList = text.split('\n').filter(function(item) { return item.length > 0; });
            }
        }
    }

}
