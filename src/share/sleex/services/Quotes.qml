import qs.modules.common
import qs.services
import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    property string quote
    property string author

    Process {
        id: getQuote
        running: true
        command: ["curl", "https://quotes-api-self.vercel.app/quote"]
        stdout: StdioCollector {
            onStreamFinished: {
                const json = JSON.parse(text)
                root.quote = json.quote
                root.author = json.author
            }
        }
    }
}