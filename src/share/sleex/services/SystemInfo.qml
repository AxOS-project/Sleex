pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Provides some system info: distro, username etc...
 */
Singleton {
    property string distroName: "Unknown"
    property string distroId: "unknown"
    property string distroIcon: "linux-symbolic"
    property string username: "user"
    property string osReleaseVersion: "Unknown"
    property string axosVersion: ""

    property string sleexVersion: "Unknown"

    Timer {
        triggeredOnStart: true
        interval: 10
        running: true
        repeat: false
        onTriggered: {
            getUsername.running = true
            getSleexVersion.running = true
            fileOsRelease.reload()
            const textOsRelease = fileOsRelease.text()

            // Extract the friendly name (PRETTY_NAME field, fallback to NAME)
            const prettyNameMatch = textOsRelease.match(/^PRETTY_NAME="(.+?)"/m)
            const nameMatch = textOsRelease.match(/^NAME="(.+?)"/m)
            distroName = prettyNameMatch ? prettyNameMatch[1] : (nameMatch ? nameMatch[1].replace(/Linux/i, "").trim() : "Unknown")

            if (distroName == "AxOS") axosVersion = axosVersionFile.text()

            // Extract the OS release version (VERSION field, fallback to "Unknown")
            const versionMatch = textOsRelease.match(/^VERSION="(.+?)"/m)
            osReleaseVersion = versionMatch ? versionMatch[1] : "Unknown"

            // Extract the ID (LOGO field, fallback to "unknown")
            const logoMatch = textOsRelease.match(/^LOGO=(.+)$/m)
            distroId = logoMatch ? logoMatch[1].replace(/"/g, "") : "unknown"

            // Update the distroIcon property based on distroId
            switch (distroId) {
                case "axos": distroIcon = "axos-symbolic"; break;
                default: distroIcon = "linux-symbolic"; break;
            }
        }
    }

    Process {
        id: getUsername
        command: ["whoami"]
        stdout: SplitParser {
            onRead: data => {
                username = data.trim();
            }
        }
    }

    Process {
        id: getSleexVersion
        command: ["sh", "-c", "pacman -Q sleex 2>/dev/null || pacman -Q sleex-git 2>/dev/null"]
        stdout: SplitParser {
            onRead: data => {
                const versionMatch = data.match(/^sleex(?:-git)?\s+(\S+)/);
                sleexVersion = versionMatch ? versionMatch[1].trim() : "Unknown";
            }
        }
    }

    FileView {
        id: fileOsRelease
        path: "/etc/os-release"
    }

    FileView {
        id: axosVersionFile
        path: "/etc/axos-version"
    }
}