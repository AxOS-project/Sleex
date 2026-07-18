pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.functions
import Sleex.Services

// Bare "Network" below refers to the C++ singleton (Sleex.Services), not this file
Singleton {
    id: root

    property string lastConnectionError: ""
    property string errorSsid: ""
    property bool showConnectionError: false

    property int refreshTrigger: 0
    function bumpRefresh() { root.refreshTrigger++; }

    readonly property var activeNetwork: Network.active || null

    property string activeConnectionType: ""

    // ~/.cache/sleex/network, resolved synchronously via Directories
    readonly property string cacheDir: FileUtils.trimFileProtocol(`${Directories.cache}/sleex/network`)

    // nmcli TYPE is "802-3-ethernet" for wired, "802-11-wireless" for WiFi
    readonly property bool hasWiredConnection: root.activeConnectionType.includes("ethernet")
    readonly property bool hasActiveConnection: root.activeNetwork !== null || root.hasWiredConnection

    readonly property bool wifiEnabled: Network.wifiEnabled || false
    readonly property bool wifiScanning: Network.scanning || false

    property bool speedTestRunning: false
    property string speedTestStage: "idle"
    property real speedTestPingMs: -1
    property real speedTestDownloadMbps: -1
    property real speedTestUploadMbps: -1
    property string speedTestError: ""
    property string speedTestSsid: ""

    property var speedTestResults: ({})

    function cacheSpeedTestResult(ssid) {
        if (!ssid) return;
        const next = Object.assign({}, root.speedTestResults);
        next[ssid] = {
            pingMs: root.speedTestPingMs,
            downloadMbps: root.speedTestDownloadMbps,
            uploadMbps: root.speedTestUploadMbps
        };
        root.speedTestResults = next;
        try {
            speedTestCacheFile.setText(JSON.stringify(next, null, 2));
        } catch (e) {
        }
    }

    function speedTestPing(ssid) {
        if (root.speedTestSsid === ssid) return root.speedTestPingMs;
        return root.speedTestResults[ssid]?.pingMs ?? -1;
    }
    function speedTestDownload(ssid) {
        if (root.speedTestSsid === ssid) return root.speedTestDownloadMbps;
        return root.speedTestResults[ssid]?.downloadMbps ?? -1;
    }
    function speedTestUpload(ssid) {
        if (root.speedTestSsid === ssid) return root.speedTestUploadMbps;
        return root.speedTestResults[ssid]?.uploadMbps ?? -1;
    }
    function speedTestIsLive(ssid) {
        return root.speedTestRunning && root.speedTestSsid === ssid;
    }
    function speedTestIsDone(ssid) {
        if (root.speedTestSsid === ssid) return root.speedTestStage === "done" || root.speedTestStage === "error";
        return !!root.speedTestResults[ssid];
    }

    function startSpeedTest() {
        if (root.speedTestRunning) return;
        root.speedTestSsid         = root.activeNetwork ? root.activeNetwork.ssid : "";
        root.speedTestRunning      = true;
        root.speedTestStage        = "ping";
        root.speedTestPingMs       = -1;
        root.speedTestDownloadMbps = -1;
        root.speedTestUploadMbps   = -1;
        root.speedTestError        = "";
        speedTestPingProcess.running = true;
    }

    property bool   qrGenerating:  false
    property string qrImagePath:   ""
    property string qrError:       ""
    property string qrActiveSsid:  ""
    property string _qrPassword:   ""

    function generateQrCode(ssid, securityStr) {
        root.qrActiveSsid = ssid;
        root.qrGenerating = true;
        root.qrImagePath  = "";
        root.qrError      = "";
        root._qrPassword  = "";
        const sec = (securityStr || "").toLowerCase();
        if (!sec || sec === "none" || sec === "--") {
            root._encodeQr(ssid, "", "nopass");
            return;
        }
        qrPasswordProcess.running = true;
    }

    function _encodeQr(ssid, password, authType) {
        function esc(s) {
            return s.replace(/\\/g, "\\\\")
                    .replace(/;/g,  "\\;")
                    .replace(/,/g,  "\\,")
                    .replace(/"/g,  "\\\"")
                    .replace(/:/g,  "\\:");
        }
        const content  = "WIFI:T:" + authType + ";S:" + esc(ssid) + ";P:" + esc(password) + ";;";
        const shellArg = "'" + content.replace(/'/g, "'\\''") + "'";
        qrEncodeProcess.command = ["bash", "-c",
            "printf '%s' " + shellArg + " | qrencode -o /tmp/axos_wifi_qr.png -s 8 -m 4"];
        qrEncodeProcess.running = true;
    }

    property string localIp: ""
    property string gatewayIp: ""
    property string dnsServers: ""
    property string publicIp: ""
    property string netInfoError: ""

    // Process needs a full stop/start cycle to re-run; setting running=true
    // while already true is a no-op
    function _restartProcess(proc) {
        if (proc.running) {
            proc.running = false;
            Qt.callLater(() => { proc.running = true; });
        } else {
            proc.running = true;
        }
    }

    function fetchNetworkInfo() {
        if (!root.hasActiveConnection) return;
        root.netInfoError = "";
        root._restartProcess(localNetInfoProcess);
        root._restartProcess(publicIpProcess);
    }

    // Exposed so Wifi.qml can drive its refresh spinner without a cross-file Process id
    readonly property bool fetchingNetworkInfo: localNetInfoProcess.running || publicIpProcess.running

    property bool dnsApplying: false
    property bool _dnsReapplyQueued: false
    property string dnsApplyError: ""
    property string _dnsConnectionName: ""
    property string _dnsDeviceName: ""

    // Operational state for the in-flight apply, not authoritative preference (Wifi.qml owns that)
    property bool _pendingDnsEnabled: false
    property string _pendingDnsProviderId: "cloudflare"

    readonly property var dnsProviders: [
        { id: "cloudflare",         name: "Cloudflare",           servers: "1.1.1.1,1.0.0.1"              },
        { id: "google",             name: "Google",               servers: "8.8.8.8,8.8.4.4"              },
        { id: "quad9",              name: "Quad9",                servers: "9.9.9.9,149.112.112.112"      },
        { id: "cloudflare-malware", name: "Cloudflare (Security)",servers: "1.1.1.2,1.0.0.2"              },
        { id: "opendns",            name: "OpenDNS",              servers: "208.67.222.222,208.67.220.220" },
        { id: "cloudflare-family",  name: "Cloudflare (Family)",  servers: "1.1.1.3,1.0.0.3"              },
        { id: "opendns-family",     name: "OpenDNS FamilyShield", servers: "208.67.222.123,208.67.220.123" }
    ]

    // O(1) lookup instead of .find() at every call site
    readonly property var dnsProviderMap: {
        var map = {};
        for (var i = 0; i < root.dnsProviders.length; i++) {
            map[root.dnsProviders[i].id] = root.dnsProviders[i];
        }
        return map;
    }

    function providerById(id) {
        return root.dnsProviderMap[id] || root.dnsProviders[0];
    }

    function applyDnsSettings(enabled, providerId) {
        if (!root.activeNetwork) return;
        root._pendingDnsEnabled    = enabled;
        root._pendingDnsProviderId = providerId;

        if (root.dnsApplying) {
            // Re-run once the in-flight apply finishes instead of dropping this change
            root._dnsReapplyQueued = true;
            return;
        }

        root.dnsApplyError = "";
        root.dnsServers = enabled ? root.providerById(providerId).servers : "—";

        root.dnsApplying        = true;
        root._dnsConnectionName = "";
        dnsConnectionNameProcess.running = true;
    }

    function formatFrequency(freqRaw) {
        const match = String(freqRaw).match(/\d+/);
        if (!match) return String(freqRaw);
        const freq = parseInt(match[0], 10);
        if (freq >= 2400 && freq <= 2495)
            return "2.4GHz, Channel " + ((freq === 2484) ? 14 : Math.round((freq - 2407) / 5));
        if (freq >= 5925 && freq <= 7125)
            return "6GHz, Channel " + Math.round((freq - 5950) / 5);
        if (freq >= 5000 && freq <= 5895)
            return "5GHz, Channel " + Math.round((freq - 5000) / 5);
        return freq + " MHz";
    }

    function detailValue(index) {
        switch (index) {
            case 0: return root.localIp;
            case 1: return root.gatewayIp;
            case 2: return (root.dnsServers || "").replace(/,\s*/g, ", "); // one entry per line when wrapped
            case 3: return root.publicIp;
            case 4: return root.activeNetwork ? root.formatFrequency(root.activeNetwork.frequency ?? "") : "—";
            case 5: return root.activeNetwork?.security || "—";
        }
        return "";
    }

    readonly property var detailItems: [
        { label: "Local IP",   icon: "lan",                    valueIdx: 0, isSensitive: true,  wifiOnly: false },
        { label: "Gateway",    icon: "router",                 valueIdx: 1, isSensitive: true,  wifiOnly: false },
        { label: "DNS",        icon: "dns",                    valueIdx: 2, isSensitive: false, wifiOnly: false },
        { label: "Public IP",  icon: "public",                 valueIdx: 3, isSensitive: true,  wifiOnly: false },
        { label: "Frequency",  icon: "settings_input_antenna", valueIdx: 4, isSensitive: false, wifiOnly: true  },
        { label: "Security",   icon: "encrypted",              valueIdx: 5, isSensitive: false, wifiOnly: true  }
    ]

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", root.cacheDir]);
        speedTestCacheFile.reload();
        connectionTypeProcess.running = true;
    }

    Component.onDestruction: {
        errorTimer.stop();
        connectionTypeProcess.running     = false;
        speedTestPingProcess.running      = false;
        speedTestDownloadProcess.running  = false;
        speedTestUploadProcess.running    = false;
        localNetInfoProcess.running       = false;
        publicIpProcess.running           = false;
        dnsConnectionNameProcess.running  = false;
        dnsModifyProcess.running          = false;
        qrPasswordProcess.running         = false;
        qrEncodeProcess.running           = false;
    }

    onRefreshTriggerChanged: {
        if (root.hasActiveConnection) {
            connectionTypeProcess.running = true;
        }
    }

    // Bumps refreshTrigger before and after the async Network update lands, so
    // anything bound to it re-evaluates against the final settled state
    function _refreshNetworkState(alsoFetchInfo) {
        root.refreshTrigger++;
        Qt.callLater(() => {
            Network.updateNetworks?.();
            Network.updateActiveConnection?.();
            root.refreshTrigger++;
            if (alsoFetchInfo) root.fetchNetworkInfo();
        });
    }

    Connections {
        target: Network

        function onConnectionSucceeded(ssid) {
            root.showConnectionError = false;
            root.lastConnectionError = "";
            root.errorSsid           = "";
            root._refreshNetworkState(true);
        }

        function onConnectionFailed(ssid, error) {
            root.lastConnectionError = error;
            root.errorSsid           = ssid;
            root.showConnectionError = true;
            errorTimer.restart();
            root._refreshNetworkState(false);
        }
        // onPasswordRequired is handled in Wifi.qml - it needs the network list's Repeater
    }

    Timer {
        id: errorTimer
        interval: 5000
        onTriggered: root.showConnectionError = false
    }

    FileView {
        id: speedTestCacheFile
        path: root.cacheDir + "/network.json"
        printErrors: false
        watchChanges: false

        onLoaded: {
            try {
                const parsed = JSON.parse(text());
                root.speedTestResults = (parsed && typeof parsed === "object") ? parsed : {};
            } catch (e) {
                root.speedTestResults = {};
            }
        }

        onLoadFailed: (error) => {
            root.speedTestResults = {};
        }
    }

    Process {
        id: connectionTypeProcess
        running: false
        command: ["bash", "-c", "nmcli -t -f TYPE connection show --active 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.activeConnectionType = (text || "").trim();
                if (root.hasActiveConnection) {
                    root.fetchNetworkInfo();
                }
            }
        }
    }

    Process {
        id: speedTestPingProcess
        running: false
        command: ["bash", "-c",
            "LC_ALL=C curl --max-time 10 -o /dev/null -s -w '%{time_connect}' 'https://speed.cloudflare.com/__down?bytes=0'"]

        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseFloat(text);
                if (!isNaN(v)) {
                    root.speedTestPingMs = v * 1000;
                }
            }
        }

        onExited: (code) => {
            if (code !== 0) {
                root.speedTestError   = "Couldn't reach the network (ping failed)";
                root.speedTestStage   = "error";
                root.speedTestRunning = false;
                root.cacheSpeedTestResult(root.speedTestSsid);
                return;
            }
            root.speedTestStage = "download";
            speedTestDownloadProcess.running = true;
        }
    }

    Process {
        id: speedTestDownloadProcess
        running: false
        command: ["bash", "-c",
            "LC_ALL=C curl --max-time 20 -o /dev/null -s -w '%{speed_download}' 'https://speed.cloudflare.com/__down?bytes=25000000'"]

        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseFloat(text);
                if (!isNaN(v)) {
                    root.speedTestDownloadMbps = (v * 8) / 1000000;
                }
            }
        }

        onExited: (code) => {
            if (code !== 0) {
                root.speedTestError   = "Download test failed";
                root.speedTestStage   = "error";
                root.speedTestRunning = false;
                root.cacheSpeedTestResult(root.speedTestSsid);
                return;
            }
            root.speedTestStage = "upload";
            speedTestUploadProcess.running = true;
        }
    }

    Process {
        id: speedTestUploadProcess
        running: false
        command: ["bash", "-c",
            "LC_ALL=C curl --max-time 20 -X POST -s -o /dev/null -w '%{speed_upload}' --data-binary @<(head -c 8000000 /dev/urandom) 'https://speed.cloudflare.com/__up'"]

        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseFloat(text);
                if (!isNaN(v)) {
                    root.speedTestUploadMbps = (v * 8) / 1000000;
                }
            }
        }

        onExited: (code) => {
            root.speedTestStage   = (code !== 0) ? "error" : "done";
            root.speedTestRunning = false;
            if (code !== 0) root.speedTestError = "Upload test failed";
            root.cacheSpeedTestResult(root.speedTestSsid);
        }
    }

    Process {
        id: localNetInfoProcess
        running: false
        command: ["bash", "-c",
            "ip -4 route get 1.1.1.1 2>/dev/null | head -n1; echo '||'; " +
            "awk '/^nameserver/{print $2}' /etc/resolv.conf 2>/dev/null | paste -sd ',' -"]

        stdout: StdioCollector {
            onStreamFinished: {
                const raw   = text || "";
                const parts = raw.split("||");
                const route = (parts[0] || "").trim();
                const dns   = (parts[1] || "").trim();
                root.localIp    = (route.match(/src\s+(\S+)/)  || [])[1] || "—";
                root.gatewayIp  = (route.match(/via\s+(\S+)/)  || [])[1] || "—";
                // Only update DNS from resolv.conf when we are not actively applying
                // and when custom DNS is not enabled (otherwise we keep the manually set value)
                if (!root.dnsApplying && !Config.options.networking.dnsSwitch) {
                    root.dnsServers = dns.length > 0 ? dns : "—";
                }
            }
        }

        onExited: (code) => { if (code !== 0) root.netInfoError = "Couldn't read local network info"; }
    }

    Process {
        id: publicIpProcess
        running: false
        command: ["bash", "-c", "curl --max-time 6 -s https://api.ipify.org"]

        stdout: StdioCollector {
            onStreamFinished: {
                const v = (text || "").trim();
                root.publicIp = v.length > 0 ? v : "—";
            }
        }

        onExited: (code) => { if (code !== 0) root.publicIp = "—"; }
    }

    Process {
        id: dnsConnectionNameProcess
        running: false
        command: ["bash", "-c",
            "nmcli -t -f NAME,DEVICE,TYPE connection show --active 2>/dev/null | " +
            "awk -F: '$3==\"802-11-wireless\"{print $1\"|\"$2; exit}'"]

        stdout: StdioCollector {
            onStreamFinished: {
                const parts = (text || "").trim().split("|");
                root._dnsConnectionName = parts[0] || "";
                root._dnsDeviceName     = parts[1] || "";
            }
        }

        onExited: (code) => {
            if (code !== 0 || !root._dnsConnectionName || !root._dnsDeviceName) {
                root.dnsApplyError = "Couldn't find the active connection";
                root.dnsApplying   = false;
                if (root._dnsReapplyQueued) {
                    root._dnsReapplyQueued = false;
                    root.applyDnsSettings(root._pendingDnsEnabled, root._pendingDnsProviderId);
                }
                return;
            }
            const name    = root._dnsConnectionName.replace(/"/g, "\\\"");
            const device  = root._dnsDeviceName.replace(/"/g, "\\\"");
            const reapply = `(nmcli device reapply "${device}" || nmcli connection up "${name}")`;
            const cmd = root._pendingDnsEnabled
                ? `nmcli connection modify "${name}" ipv4.ignore-auto-dns yes ipv4.dns "${root.providerById(root._pendingDnsProviderId).servers}" && ${reapply}`
                : `nmcli connection modify "${name}" ipv4.ignore-auto-dns no ipv4.dns "" && ${reapply}`;
            dnsModifyProcess.command = ["bash", "-c", cmd];
            dnsModifyProcess.running = true;
        }
    }

    Process {
        id: dnsModifyProcess
        running: false
        command: ["bash", "-c", "true"]

        onExited: (code) => {
            root.dnsApplying = false;
            if (code !== 0) root.dnsApplyError = "Failed to apply DNS settings";
            Qt.callLater(root.fetchNetworkInfo);
            if (root._dnsReapplyQueued) {
                root._dnsReapplyQueued = false;
                root.applyDnsSettings(root._pendingDnsEnabled, root._pendingDnsProviderId);
            }
        }
    }

    Process {
        id: qrPasswordProcess
        running: false
        command: ["bash", "-c",
            "nmcli -s -g 802-11-wireless-security.psk connection show " +
            "\"$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | " +
            "awk -F: '$2==\"802-11-wireless\"{print $1; exit}')\" 2>/dev/null"]

        stdout: StdioCollector {
            onStreamFinished: { root._qrPassword = (text || "").trim(); }
        }

        onExited: (code) => {
            if (code !== 0 || !root._qrPassword) {
                root.qrError     = "Couldn't retrieve the stored WiFi password.\nEnsure NetworkManager has this connection saved with a password.";
                root.qrGenerating = false;
                return;
            }
            const sec      = (root.activeNetwork?.security || "").toLowerCase();
            const authType = sec.includes("wep") ? "WEP" : "WPA";
            root._encodeQr(root.qrActiveSsid, root._qrPassword, authType);
            root._qrPassword = "";
        }
    }

    Process {
        id: qrEncodeProcess
        running: false
        command: ["bash", "-c", "true"]

        onExited: (code) => {
            root.qrGenerating = false;
            if (code !== 0) {
                root.qrError = "QR generation failed. Is 'qrencode' installed?\n(sudo pacman -S qrencode)";
                return;
            }
            root.qrImagePath = "";
            Qt.callLater(() => { root.qrImagePath = "file:///tmp/axos_wifi_qr.png"; });
        }
    }
}
