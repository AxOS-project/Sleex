import qs.modules.common
import qs.services
import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    property int contribution_number
    property string author: Config.options.dashboard.ghUsername
    property var contributions: []

    Timer {
        interval: 600000 // 10 minutes
        running: root.author && root.author.trim() !== ""
        repeat: true
        onTriggered: getContributions.running = true
    }

    Process {
        id: getContributions
        running: root.author && root.author.trim() !== ""
        command: ["curl", `https://github-contributions-api.jogruber.de/v4/${root.author}`]
        stdout: StdioCollector {
            onStreamFinished: {
                const json = JSON.parse(text)
                const year = DateTime.year
                // Calculate total contributions in the last 365 days
                const oneYearAgo = new Date();
                oneYearAgo.setDate(oneYearAgo.getDate() - 365);
                root.contribution_number = json.contributions
                    .filter(c => new Date(c.date) >= oneYearAgo)
                    .reduce((sum, c) => sum + c.count, 0);

                const allContribs = json.contributions;
                const today = new Date();
                const cutoff = new Date(today);
                cutoff.setDate(cutoff.getDate() - 280);

                const recentContribs = allContribs
                    .filter(c => new Date(c.date) >= cutoff)
                    .sort((a, b) => new Date(a.date) - new Date(b.date));

                root.contributions = recentContribs;
            }
        }
    }
}
