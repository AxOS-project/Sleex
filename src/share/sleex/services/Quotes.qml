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

    property string localQuotes: "/usr/share/sleex/assets/quotes.json"
    property var file: null
    property bool online: Config.options.background.quoteSource === 1

    Component.onCompleted: {
        refresh()
    }

    Connections {
        target: Config.options.background
        function onEnableQuoteChanged() {
            root.refresh()
        }
        function onQuoteSourceChanged() {
            root.refresh()
        }
    }

    function refresh() {
        root.quote = ""
        root.author = ""
        if (Config.options.background.enableQuote == true) {
            
            if (!root.online) {
                getLocalQuote()
                setLocalQuote()
            } else if (root.online) {
                if (getQuote.running) {
                    getQuote.running = false
                }
                getQuote.running = true
            } else {
                console.warn("Unknown quote source:", Config.options.background.quoteSource)
            }
        }
    }

    function getLocalQuote() {
        localQuoteFileView.reload()
    }

    function setLocalQuote() {
        if (root.file) {
            const data = root.file
            const json = JSON.parse(data)
            const randomIndex = Math.floor(Math.random() * json.length)
            root.quote = json[randomIndex].quote
            root.author = json[randomIndex].author
        }
    }

    Process {
        id: getQuote
        running: false
        command: ["curl", "https://quotes-api-self.vercel.app/quote"]
        stdout: StdioCollector {
            onStreamFinished: {
                const json = JSON.parse(text)
                root.quote = json.quote
                root.author = json.author
            }
        }
    }

    FileView {
        id: localQuoteFileView
        path: localQuotes
        onLoadedChanged: {
            if (loaded) {
                root.file = localQuoteFileView.text()
                setLocalQuote()
            }
        }
        onLoadFailed: errorString => {
            console.warn("Error reading local quotes:", errorString)
        }
    }
}