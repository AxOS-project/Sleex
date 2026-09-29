pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import SleexUiKit.Functions

Singleton {
    id: root

    property string apiKey: ""
    property var searchResults: []
    property bool isLoading: false
    property int currentPage: 1
    property int totalPages: 1
    property string currentQuery: "wallpapers"
    property string currentlyDownloadingId: ""

    property string downloadPath: Config.options.background.wallpaperDownloadPath

    Component.onCompleted: loadApiKey()

    function loadApiKey() {
        var path = FileUtils.trimFileProtocol(Directories.home) + "/.local/state/sleex/user/unsplash_api_key";
        var p = loadKeyProcessComponent.createObject(root, { "filePath": path });
        p.running = true;
    }

    function saveApiKey(key) {
        root.apiKey = key;
        var path = FileUtils.trimFileProtocol(Directories.home) + "/.local/state/sleex/user/unsplash_api_key";
        Quickshell.execDetached(["bash", "-c", "mkdir -p $(dirname '" + path + "') && echo '" + key + "' > '" + path + "'"]);
    }

    function search(query, page) {
        if (!query) query = "wallpapers";
        if (!page) page = 1;
        
        root.isLoading = true;
        root.currentPage = page;
        root.currentQuery = query;

        if (!root.apiKey) {
            console.error("No Unsplash API key");
            root.searchResults = [];
            root.isLoading = false;
            return;
        }
        
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                root.isLoading = false;
                if (xhr.status === 200) {
                    var response = JSON.parse(xhr.responseText);
                    root.totalPages = response.total_pages;
                    root.searchResults = response.results;
                } else {
                    console.error("Unsplash search failed: ", xhr.status, xhr.responseText);
                    root.searchResults = [];
                }
            }
        }
        xhr.open("GET", "https://api.unsplash.com/search/photos?query=" + encodeURIComponent(query) + "&per_page=28&page=" + page);
        xhr.setRequestHeader("Authorization", "Client-ID " + root.apiKey);
        xhr.send();
    }

    function applyWallpaper(id, url) {
        root.currentlyDownloadingId = id;
        Quickshell.execDetached(["mkdir", "-p", root.downloadPath]);
        
        var p = downloadProcessComponent.createObject(root, {
            "dest": root.downloadPath + "/" + id + ".jpg",
            "url": url,
            "imageId": id
        });
        p.running = true;
    }

    Component {
        id: downloadProcessComponent
        Process {
            property string dest
            property string url
            property string imageId
            
            command: ["curl", "-s", "-L", "-o", dest, url]
            onExited: {
                root.currentlyDownloadingId = "";
                Quickshell.execDetached(["bash", Quickshell.shellPath("scripts/colors/switchwall.sh"), dest, "&"])
                destroy();
            }
        }
    }

    Component {
        id: loadKeyProcessComponent
        Process {
            property string filePath
            command: ["cat", filePath]
            stdout: SplitParser {
                onRead: data => {
                    if (data && data.trim().length > 0) {
                        root.apiKey = data.trim();
                    }
                }
            }
            onExited: destroy()
        }
    }
}
