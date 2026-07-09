import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Bluetooth
import qs.services
import qs.modules.common
import qs.modules.common.widgets

import Sleex.Services

ContentPage {
    id: root
    forceSingleColumn: true

    // Connection error tracking
    property string lastConnectionError: ""
    property string errorSsid: ""
    property bool showConnectionError: false

    // UI refresh trigger and bump to force ScriptModel/computed re-evaluation
    property int refreshTrigger: 0

    // View toggles
    property bool showSensitiveInfo: false
    property bool showConnectionDetails: true
    property bool networkSearchVisible: false
    property string searchText: ""

    // Currently active (connected) network, kept in sync with refreshTrigger
    readonly property var activeNetwork: {
        let _t = root.refreshTrigger;
        const nets = Network.networks || [];
        for (let i = 0; i < nets.length; i++) {
            if (nets[i].active) return nets[i];
        }
        return null;
    }

    property string activeConnectionType: ""

    // nmcli reports "802-3-ethernet" for wired and "802-11-wireless" for WiFi.
    // activeNetwork above only ever reflects WiFi, so on its own it can't tell
    // us a wired connection is up, but hasActiveConnection covers both.
    readonly property bool hasWiredConnection: root.activeConnectionType.includes("ethernet")
    readonly property bool hasActiveConnection: root.activeNetwork !== null || root.hasWiredConnection

    // Speed test state reflects whichever test is currently in-flight (or was
    // most recently run). `speedTestSsid` says which network that is.
    property bool speedTestRunning: false
    property string speedTestStage: "idle"
    property real speedTestPingMs: -1
    property real speedTestDownloadMbps: -1
    property real speedTestUploadMbps: -1
    property string speedTestError: ""
    property string speedTestSsid: ""

    // Completed results, kept per-SSID and keyed by SSID -> { pingMs, downloadMbps, uploadMbps }.
    property var speedTestResults: ({})

    function cacheSpeedTestResult(ssid) {
        if (!ssid) return;
        const next = Object.assign({}, root.speedTestResults);
        next[ssid] = {
            pingMs: root.speedTestPingMs,
            downloadMbps: root.speedTestDownloadMbps,
            uploadMbps: root.speedTestUploadMbps
        };
        root.speedTestResults = next; // reassign (not mutate) so bindings notice
        try {
            Config.options.networking.speedTestResultsJson = JSON.stringify(next);
        } catch (e) {
            // Non-fatal - worst case the result just won't survive a restart.
        }
    }

    // Resolves what should be shown for a given network right now: live
    // in-progress numbers if that's the network currently being tested,
    // otherwise whatever was cached for it (or -1 if it's never been tested).
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
    // True while ssid is the one actually being tested right now (drives the
    // "…" placeholders and the animated icon for that specific row only).
    function speedTestIsLive(ssid) {
        return root.speedTestRunning && root.speedTestSsid === ssid;
    }
    // True once ssid has a finished (done or error) test to show "Test Again" for.
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

    // QR code sharing state
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

    // Local/public network info (connection details)
    property string localIp: ""
    property string gatewayIp: ""
    property string dnsServers: ""
    property string publicIp: ""
    property string netInfoError: ""

    // Improved refresh by restarting any running process to guarantee fresh data
    function fetchNetworkInfo() {
        if (!root.hasActiveConnection) return;
        root.netInfoError = "";

        // Kill any in-flight process and start fresh
        if (localNetInfoProcess.running) {
            localNetInfoProcess.running = false;
            Qt.callLater(() => { localNetInfoProcess.running = true; });
        } else {
            localNetInfoProcess.running = true;
        }

        if (publicIpProcess.running) {
            publicIpProcess.running = false;
            Qt.callLater(() => { publicIpProcess.running = true; });
        } else {
            publicIpProcess.running = true;
        }
    }

    // Custom DNS provider state
    property bool customDnsEnabled: false
    property string customDnsProviderId: "cloudflare"
    property bool dnsApplying: false
    property string dnsApplyError: ""
    property string _dnsConnectionName: ""
    property string _dnsDeviceName: ""

    // The network's own (non-overridden) DNS, captured live every time we read
    // resolv.conf while custom DNS is off. Scoped to _defaultDnsSsid so a backup
    // from one network can never leak into another after switching connections.
    property string _defaultDnsBackup: ""
    property string _defaultDnsSsid: ""

    // After disabling, NetworkManager's reapply doesn't roll resolv.conf back to
    // the real DHCP DNS instantly - a read taken too soon can still show the
    // just-disabled custom DNS. Track retries so we can wait it out instead of
    // trusting (and caching) a stale value.
    property int _dnsSettleRetries: 0
    readonly property var _allProviderDnsStrings: root.dnsProviders.map(p => p.servers)

    // Drop any cached default the moment the active network changes - it belongs
    // to whichever SSID it was captured under and is meaningless anywhere else.
    onActiveNetworkChanged: {
        if (!root.activeNetwork || root._defaultDnsSsid !== root.activeNetwork.ssid) {
            root._defaultDnsBackup = "";
            root._defaultDnsSsid   = "";
        }
        root._dnsSettleRetries = 0;
        dnsSettleRetryTimer.stop();
    }

    readonly property var dnsProviders: [
        { id: "cloudflare",         name: "Cloudflare",           servers: "1.1.1.1,1.0.0.1"              },
        { id: "google",             name: "Google",               servers: "8.8.8.8,8.8.4.4"              },
        { id: "quad9",              name: "Quad9",                servers: "9.9.9.9,149.112.112.112"      },
        { id: "cloudflare-malware", name: "Cloudflare (Security)",servers: "1.1.1.2,1.0.0.2"              },
        { id: "opendns",            name: "OpenDNS",              servers: "208.67.222.222,208.67.220.220" },
        { id: "cloudflare-family",  name: "Cloudflare (Family)",  servers: "1.1.1.3,1.0.0.3"              },
        { id: "opendns-family",     name: "OpenDNS FamilyShield", servers: "208.67.222.123,208.67.220.123" }
    ]

    // O(1) lookup map instead of .find() everywhere
    readonly property var dnsProviderMap: {
        var map = {};
        for (var i = 0; i < root.dnsProviders.length; i++) {
            map[root.dnsProviders[i].id] = root.dnsProviders[i];
        }
        return map;
    }

    function currentDnsProvider() {
        return root.dnsProviderMap[root.customDnsProviderId] || root.dnsProviders[0];
    }

    // Apply DNS settings is guarded against double‑apply, with UI instant update
    function applyDnsSettings() {
        if (!root.activeNetwork) return;
        if (root.dnsApplying) return;   // already applying

        root.dnsApplyError = "";
        root._dnsSettleRetries = 0;
        dnsSettleRetryTimer.stop();
        const ssid = root.activeNetwork.ssid;
        const haveBackupForThisNetwork = root._defaultDnsSsid === ssid && root._defaultDnsBackup !== "";

        if (root.customDnsEnabled) {
            // Safety net: normally the backup is kept fresh continuously by
            // fetchNetworkInfo() (see localNetInfoProcess) while DNS isn't
            // overridden. If we somehow don't have one yet for this network,
            // grab whatever's showing right now as a best-effort fallback.
            if (!haveBackupForThisNetwork && root.dnsServers !== "—") {
                root._defaultDnsBackup = root.dnsServers;
                root._defaultDnsSsid   = ssid;
            }
            root.dnsServers = currentDnsProvider().servers;
        } else {
            // Restore instantly if we trust the cached value; otherwise show a
            // pending state rather than leaving the old custom DNS on screen -
            // fetchNetworkInfo() will fill in the real value once nmcli settles.
            root.dnsServers = haveBackupForThisNetwork ? root._defaultDnsBackup : "—";
        }

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
            // Comma-separated with no spaces (e.g. "1.1.1.1,2606:4700:4700::1111")
            // gives WordWrap nothing to break on, so a long DNS list just overflows
            // its card. Insert a space after each comma so it wraps one entry per
            // line instead.
            case 2: return (root.dnsServers || "").replace(/,\s*/g, ", ");
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

    // Frequency/Security only mean anything for a WiFi connection - drop them
    // entirely over Ethernet rather than showing "—" placeholders.
    readonly property var filteredDetailItems: {
        var arr = [];
        for (var i = 0; i < detailItems.length; ++i) {
            const item = detailItems[i];
            if (item.wifiOnly && root.activeNetwork === null) continue;
            if (!item.isSensitive || root.showSensitiveInfo)
                arr.push(item);
        }
        return arr;
    }

    function loadSavedSpeedTestResults() {
        const raw = Config.options.networking.speedTestResultsJson;
        if (!raw) return {};
        try {
            const parsed = JSON.parse(raw);
            return (parsed && typeof parsed === "object") ? parsed : {};
        } catch (e) {
            return {};
        }
    }

    Component.onCompleted: {
        // Always check - this is how we discover a wired connection exists at
        // all (activeNetwork only ever reflects WiFi). fetchNetworkInfo() is
        // triggered from connectionTypeProcess's own handler below once we
        // actually know whether something is connected.
        connectionTypeProcess.running = true;
        const savedProvider = Config.options.networking.dnsProvider;
        if (savedProvider) root.customDnsProviderId = savedProvider;
        root.customDnsEnabled      = Config.options.networking.dnsSwitch            || false;
        root.showSensitiveInfo     = Config.options.networking.sensitiveNetworkInfo  || false;
        root.showConnectionDetails = Config.options.networking.connectionDetails !== undefined
                                      ? Config.options.networking.connectionDetails : true;

        // Restore every network's last speed test result (not just one "best
        // guess" network) so switching back to a previously-tested network -
        // even across a shell restart - still shows its numbers.
        root.speedTestResults = root.loadSavedSpeedTestResults();
    }

    // Stop any in-flight background work if the page is torn down mid-request -
    // otherwise a speed test or DNS apply can keep a curl/nmcli process (and its
    // infinite pulse animation) alive after navigating away.
    Component.onDestruction: {
        errorTimer.stop();
        dnsSettleRetryTimer.stop();
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

    // Shared tail of the connection-succeeded/failed handlers below - re-asks the
    // Network service for fresh state and forces a second ScriptModel re-evaluation
    // once that state has actually landed (single source of truth, avoids drift
    // between the two handlers).
    function _refreshNetworkState(alsoFetchInfo) {
        root.refreshTrigger++;
        Qt.callLater(() => {
            Network.updateNetworks?.();
            Network.updateActiveConnection?.();
            root.refreshTrigger++;
            if (alsoFetchInfo) root.fetchNetworkInfo();
        });
    }

    // Network connection result handlers
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

        function onPasswordRequired(ssid) {
            // Security type changed - expand the network for password input
            for (let i = 0; i < networkRepeater.count; i++) {
                const item = networkRepeater.itemAt(i);
                if (item?.modelData?.ssid === ssid) {
                    item.expanded = true;
                    break;
                }
            }
            root.refreshTrigger++;
        }
    }

    // Timer to auto-hide connection errors
    Timer {
        id: errorTimer
        interval: 5000
        onTriggered: root.showConnectionError = false
    }

    // Retries fetchNetworkInfo() a few times when a post-toggle DNS read still
    // looks like the just-disabled custom DNS instead of the real default.
    Timer {
        id: dnsSettleRetryTimer
        interval: 500
        onTriggered: root.fetchNetworkInfo()
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
                // DNS will be updated only if we are not in the middle of a custom DNS switch
                // (the apply function has already set the instant value)
                if (!root.dnsApplying) {
                    const value = dns.length > 0 ? dns : "—";

                    // If custom DNS is supposed to be off but this read still matches one
                    // of our known provider strings, NetworkManager hasn't rolled resolv.conf
                    // back to the real DHCP DNS yet. Don't trust or cache it - wait it out.
                    const looksLikeLeftoverCustomDns = !root.customDnsEnabled &&
                        root._allProviderDnsStrings.indexOf(value) !== -1;

                    if (looksLikeLeftoverCustomDns && root._dnsSettleRetries < 6) {
                        root._dnsSettleRetries++;
                        dnsSettleRetryTimer.restart();
                    } else {
                        root._dnsSettleRetries = 0;
                        root.dnsServers = value;
                        if (!root.customDnsEnabled && root.activeNetwork) {
                            // Custom DNS is off, so whatever resolv.conf reports right now
                            // genuinely IS this network's default - keep the backup current
                            // so a future toggle-off can restore it instantly and correctly.
                            root._defaultDnsBackup = value;
                            root._defaultDnsSsid   = root.activeNetwork.ssid;
                        }
                    }
                }
                // else: keep the instant value until apply finishes, then fetchNetworkInfo will be called
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
                return;
            }
            const name    = root._dnsConnectionName.replace(/"/g, "\\\"");
            const device  = root._dnsDeviceName.replace(/"/g, "\\\"");
            const reapply = `(nmcli device reapply "${device}" || nmcli connection up "${name}")`;
            const cmd = root.customDnsEnabled
                ? `nmcli connection modify "${name}" ipv4.ignore-auto-dns yes ipv4.dns "${root.currentDnsProvider().servers}" && ${reapply}`
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
            if (code !== 0) {
                // Rollback – the apply failed, so the DNS setting did not change
                root.customDnsEnabled = !root.customDnsEnabled;
                Config.options.networking.dnsSwitch = root.customDnsEnabled;
                root.dnsApplyError = "Failed to apply DNS settings";
                // Also revert the UI DNS to the real system state
                Qt.callLater(root.fetchNetworkInfo);
                return;
            }
            if (root.customDnsEnabled)
                Config.options.networking.dnsProvider = root.customDnsProviderId;
            // Refresh UI with actual values (will also overwrite the instant DNS with the real one)
            Qt.callLater(root.fetchNetworkInfo);
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

    ContentSection {
        title: "Wifi settings"
        icon: "network_wifi"

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 18

            ConfigSwitch {
                text: "Enabled"
                checked: Network.wifiEnabled || false
                onClicked: Network.toggleWifi()
                StyledToolTip {
                    text: Network.wifiEnabled ? "Click to disable WiFi" : "Click to enable WiFi"
                }
            }

            ConfigSwitch {
                text: "Connection Details"
                checked: root.showConnectionDetails
                onClicked: {
                    root.showConnectionDetails = !root.showConnectionDetails;
                    Config.options.networking.connectionDetails = root.showConnectionDetails;
                }
                StyledToolTip {
                    text: root.showConnectionDetails
                        ? "Hide Connection Details"
                        : "Show Connection Details"
                }
            }

            ConfigSwitch {
                text: "Sensitive Info"
                checked: root.showSensitiveInfo
                onClicked: {
                    root.showSensitiveInfo = !root.showSensitiveInfo;
                    Config.options.networking.sensitiveNetworkInfo = root.showSensitiveInfo;
                }
                StyledToolTip {
                    text: root.showSensitiveInfo
                        ? "Hide sensitive network details"
                        : "Show sensitive network details"
                }
            }
        }
    }

    Item {
        Layout.fillWidth: true
        readonly property real targetHeight: root.hasActiveConnection && root.showConnectionDetails
            ? healthDashboard.implicitHeight : 0
        height: targetHeight
        implicitHeight: targetHeight
        clip: true

        Behavior on height {
            NumberAnimation { duration: 180; easing.type: Easing.InOutQuad }
        }

        ContentSection {
            id: healthDashboard
            width: parent.width
            visible: root.hasActiveConnection && root.showConnectionDetails
            title: "Connection Details"
            icon: "monitoring"

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 16

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    MaterialSymbol {
                        id: connectionTypeIcon
                        Layout.alignment: Qt.AlignVCenter
                        text: root.activeConnectionType.includes("wireless") ? "wifi" : "settings_ethernet"
                        font.pixelSize: Appearance.font.pixelSize.title
                        color: Appearance.m3colors.m3primary
                    }

                    ColumnLayout {
                        spacing: 2

                        StyledText {
                            text: root.activeNetwork?.ssid || (root.hasWiredConnection ? "Wired Connection" : "")
                            font.pixelSize: Appearance.font.pixelSize.large
                            font.weight: 500
                            color: Appearance.m3colors.m3primary
                        }
                        StyledText {
                            text: "Connected"
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                        }
                    }

                    Item { Layout.fillWidth: true }

                    RippleButton {
                        id: speedTestHeaderBtn

                        contentItem: Rectangle {
                            radius: Appearance.rounding.full
                            color: Appearance.colors.colLayer2
                            implicitWidth: height

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "speed"
                                color: Appearance.m3colors.m3onSecondaryContainer
                                fill: root.speedTestRunning ? 1 : 0

                                // Only tick while the dashboard is actually shown - avoids a
                                // perpetual repaint loop running behind a collapsed section.
                                SequentialAnimation on opacity {
                                    running: root.speedTestRunning && root.showConnectionDetails
                                    loops: Animation.Infinite
                                    NumberAnimation { from: 1;   to: 0.4; duration: 550; easing.type: Easing.InOutQuad }
                                    NumberAnimation { from: 0.4; to: 1;   duration: 550; easing.type: Easing.InOutQuad }
                                }
                            }
                        }

                        MouseArea {
                            id: speedTestHeaderArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: root.speedTestRunning ? Qt.ArrowCursor : Qt.PointingHandCursor
                            enabled: !root.speedTestRunning
                            onClicked: root.startSpeedTest()

                            StyledToolTip {
                                extraVisibleCondition: speedTestHeaderArea.containsMouse
                                text: root.speedTestRunning ? "Testing…" : "Perform a network speed test\nUses the Cloudflare provider"
                            }
                        }
                    }

                    RippleButton {
                        id: refreshInfoBtn

                        contentItem: Rectangle {
                            radius: Appearance.rounding.full
                            color: Appearance.colors.colLayer2
                            implicitWidth: height

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "refresh"
                                color: Appearance.m3colors.m3onSecondaryContainer
                                fill: (localNetInfoProcess.running || publicIpProcess.running) ? 1 : 0

                                RotationAnimation on rotation {
                                    running: (localNetInfoProcess.running || publicIpProcess.running) && root.showConnectionDetails
                                    loops: Animation.Infinite
                                    from: 0; to: 360; duration: 900
                                }
                            }
                        }

                        MouseArea {
                            id: refreshInfoArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.fetchNetworkInfo()

                            StyledToolTip {
                                extraVisibleCondition: refreshInfoArea.containsMouse
                                text: "Refresh connection info"
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Appearance.colors.colOutlineVariant
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: root.netInfoError !== ""
                    text: root.netInfoError
                    color: Appearance.m3colors.m3error
                    font.pixelSize: Appearance.font.pixelSize.small
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    height: 100

                    Rectangle {
                        // Meaningless over Ethernet - hide rather than show a misleading 0%
                        visible: root.activeNetwork !== null
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Appearance.rounding.small
                        color: Appearance.colors.colLayer2
                        border.width: 1
                        border.color: Appearance.colors.colOutlineVariant

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            MaterialSymbol {
                                Layout.alignment: Qt.AlignHCenter
                                text: "signal_cellular_alt"
                                font.pixelSize: 24
                                color: Appearance.m3colors.m3primary
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Signal Strength"
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colSubtext
                            }
                            Rectangle {
                                Layout.preferredWidth: 80
                                Layout.preferredHeight: 4
                                radius: 2
                                color: Appearance.colors.colOutlineVariant
                                Layout.alignment: Qt.AlignHCenter

                                Rectangle {
                                    width: parent.width * Math.min(root.activeNetwork?.strength ?? 0, 100) / 100
                                    height: parent.height
                                    radius: 2
                                    color: Appearance.m3colors.m3primary
                                }
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: (root.activeNetwork?.strength ?? 0) + "%"
                                font.pixelSize: Appearance.font.pixelSize.large
                                font.weight: 600
                                color: Appearance.m3colors.m3primary
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Appearance.rounding.small
                        color: Appearance.colors.colLayer2
                        border.width: 1
                        border.color: Appearance.colors.colOutlineVariant

                        readonly property string targetSsid: root.activeNetwork ? root.activeNetwork.ssid : ""
                        readonly property real pingValue: root.speedTestPing(targetSsid)
                        readonly property bool isLive: root.speedTestIsLive(targetSsid)
                        readonly property bool hasResult: pingValue >= 0
                        readonly property color latencyColor: {
                            if (!hasResult) return Appearance.m3colors.m3outline;
                            return pingValue < 50 ? Appearance.m3colors.m3primary
                                 : pingValue < 100 ? Appearance.m3colors.m3tertiary
                                 : Appearance.m3colors.m3error;
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            MaterialSymbol {
                                Layout.alignment: Qt.AlignHCenter
                                text: "timer"
                                font.pixelSize: 24
                                color: parent.parent.latencyColor
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Latency"
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colSubtext
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: parent.parent.hasResult
                                    ? parent.parent.pingValue.toFixed(0) + " ms"
                                    : (parent.parent.isLive && root.speedTestStage === "ping" ? "…" : "—")
                                font.pixelSize: Appearance.font.pixelSize.large
                                font.weight: 600
                                color: parent.parent.hasResult ? parent.parent.latencyColor : Appearance.colors.colSubtext
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    height: 100

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Appearance.rounding.small
                        color: Appearance.colors.colLayer2
                        border.width: 1
                        border.color: Appearance.colors.colOutlineVariant

                        readonly property string targetSsid: root.activeNetwork ? root.activeNetwork.ssid : ""
                        readonly property real downloadValue: root.speedTestDownload(targetSsid)
                        readonly property bool isLive: root.speedTestIsLive(targetSsid)

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            MaterialSymbol {
                                Layout.alignment: Qt.AlignHCenter
                                text: "arrow_downward"
                                font.pixelSize: 24
                                color: Appearance.m3colors.m3primary
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Download"
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colSubtext
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: parent.parent.downloadValue >= 0
                                    ? parent.parent.downloadValue.toFixed(1) + " Mbps"
                                    : (parent.parent.isLive && (root.speedTestStage === "ping" || root.speedTestStage === "download") ? "…" : "—")
                                font.pixelSize: Appearance.font.pixelSize.large
                                font.weight: 600
                                color: parent.parent.downloadValue >= 0 ? Appearance.m3colors.m3primary : Appearance.colors.colSubtext
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Appearance.rounding.small
                        color: Appearance.colors.colLayer2
                        border.width: 1
                        border.color: Appearance.colors.colOutlineVariant

                        readonly property string targetSsid: root.activeNetwork ? root.activeNetwork.ssid : ""
                        readonly property real uploadValue: root.speedTestUpload(targetSsid)
                        readonly property bool isLive: root.speedTestIsLive(targetSsid)

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            MaterialSymbol {
                                Layout.alignment: Qt.AlignHCenter
                                text: "arrow_upward"
                                font.pixelSize: 24
                                color: Appearance.m3colors.m3primary
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Upload"
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colSubtext
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: parent.parent.uploadValue >= 0
                                    ? parent.parent.uploadValue.toFixed(1) + " Mbps"
                                    : (parent.parent.isLive ? "…" : "—")
                                font.pixelSize: Appearance.font.pixelSize.large
                                font.weight: 600
                                color: parent.parent.uploadValue >= 0 ? Appearance.m3colors.m3primary : Appearance.colors.colSubtext
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Appearance.colors.colOutlineVariant }

                GridLayout {
                    id: infoGrid
                    Layout.fillWidth: true
                    columns: 3
                    columnSpacing: 12
                    rowSpacing: 12

                    Repeater {
                        model: root.filteredDetailItems

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            Layout.preferredWidth: 1
                            implicitHeight: infoContent.implicitHeight + 24
                            clip: true
                            radius: Appearance.rounding.small
                            color: Appearance.colors.colLayer2
                            border.width: 1
                            border.color: Appearance.colors.colOutlineVariant

                            ColumnLayout {
                                id: infoContent
                                anchors.centerIn: parent
                                width: parent.width - 16
                                spacing: 4

                                MaterialSymbol {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modelData.icon
                                    font.pixelSize: 20
                                    color: Appearance.m3colors.m3primary
                                }
                                StyledText {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modelData.label
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colSubtext
                                }
                                StyledText {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    // Bind width explicitly rather than trusting Layout.fillWidth alone -
                                    // Text's implicit size is its natural, unwrapped width, so without a
                                    // concrete width forced here the column can end up sized to fit the
                                    // whole DNS string on one line and it overflows the card instead of
                                    // ever actually wrapping.
                                    width: infoContent.width
                                    text: root.detailValue(modelData.valueIdx)
                                    font.pixelSize: Appearance.font.pixelSize.large
                                    font.weight: 600
                                    color: Appearance.colors.colOnLayer1
                                    wrapMode: Text.Wrap
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Item {
        Layout.fillWidth: true
        readonly property real targetHeight: root.activeNetwork !== null
            ? customDnsSection.implicitHeight : 0
        height: targetHeight
        implicitHeight: targetHeight
        clip: true

        Behavior on height {
            NumberAnimation { duration: 180; easing.type: Easing.InOutQuad }
        }

        ContentSection {
            id: customDnsSection
            width: parent.width
            visible: root.activeNetwork !== null
            title: "Custom DNS"
            icon: "dns"

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 14

                // Disable switch while DNS is being applied to prevent races
                ConfigSwitch {
                    text: "Custom DNS"
                    checked: root.customDnsEnabled
                    enabled: !root.dnsApplying
                    onClicked: {
                        root.customDnsEnabled = !root.customDnsEnabled;
                        Config.options.networking.dnsSwitch = root.customDnsEnabled;
                        root.applyDnsSettings();
                    }
                    StyledToolTip {
                        text: root.dnsApplying
                            ? "Applying DNS settings…"
                            : (root.customDnsEnabled
                                ? "Click to use this network's default DNS"
                                : "Click to use a custom DNS provider")
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    visible: root.customDnsEnabled

                    Repeater {
                        model: [
                            { group: "General",  ids: ["cloudflare", "google", "quad9"]           },
                            { group: "Security", ids: ["cloudflare-malware", "opendns"]           },
                            { group: "Family",   ids: ["cloudflare-family", "opendns-family"]     }
                        ]

                        delegate: ColumnLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 4

                            StyledText {
                                text: modelData.group
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colSubtext
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Repeater {
                                    model: modelData.ids

                                    delegate: Rectangle {
                                        required property string modelData
                                        required property int index

                                        // O(1) lookup via map
                                        readonly property var provider:    root.dnsProviderMap[modelData] ?? null
                                        readonly property bool isSelected:  root.customDnsProviderId === modelData
                                        readonly property string primaryIp: provider?.servers.split(",")[0] ?? ""

                                        Layout.fillWidth: true
                                        height: 64
                                        radius: Appearance.rounding.small

                                        color: isSelected
                                            ? Qt.rgba(Appearance.m3colors.m3primaryContainer.r,
                                                      Appearance.m3colors.m3primaryContainer.g,
                                                      Appearance.m3colors.m3primaryContainer.b, 0.55)
                                            : Appearance.colors.colLayer2
                                        border.width: isSelected ? 0 : 1
                                        border.color: Appearance.colors.colOutlineVariant

                                        Behavior on color        { ColorAnimation  { duration: 150 } }
                                        Behavior on border.width { NumberAnimation { duration: 150 } }

                                        ColumnLayout {
                                            anchors { fill: parent; margins: 8; topMargin: 12 }
                                            spacing: 2

                                            RowLayout {
                                                spacing: 4

                                                MaterialSymbol {
                                                    visible: isSelected
                                                    text: "check"
                                                    font.pixelSize: Appearance.font.pixelSize.small
                                                    color: Appearance.m3colors.m3primary
                                                }

                                                StyledText {
                                                    text: provider?.name ?? ""
                                                    font.pixelSize: Appearance.font.pixelSize.normal
                                                    font.weight: isSelected ? 600 : 400
                                                    color: isSelected
                                                        ? Appearance.m3colors.m3primary
                                                        : Appearance.colors.colOnLayer1
                                                    Behavior on color { ColorAnimation { duration: 150 } }
                                                }
                                            }

                                            StyledText {
                                                text: primaryIp
                                                font.pixelSize: Appearance.font.pixelSize.small
                                                color: isSelected
                                                    ? Appearance.m3colors.m3primary
                                                    : Appearance.colors.colSubtext
                                                opacity: isSelected ? 0.75 : 1.0
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            enabled: !root.dnsApplying
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.customDnsProviderId = modelData;
                                                root.applyDnsSettings();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: root.dnsApplyError !== ""

                    MaterialSymbol {
                        text: "error_outline"
                        font.pixelSize: Appearance.font.pixelSize.larger
                        color: Appearance.m3colors.m3error
                    }

                    StyledText {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.m3colors.m3error
                        text: root.dnsApplyError
                    }
                }
            }
        }
    }

    ContentSection {
        title: "Networks"
        icon: "wifi"

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 18

            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    visible: !root.networkSearchVisible
                    spacing: 10

                    StyledText {
                        text: {
                            const c = (Network.networks || []).length;
                            return qsTr("%1 network%2 available").arg(c).arg(c === 1 ? "" : "s");
                        }
                        color: Appearance.colors.colOnLayer0
                        font.pixelSize: Appearance.font.pixelSize.large
                        font.weight: 500
                    }

                    Rectangle {
                        visible: root.activeNetwork !== null
                        radius: Appearance.rounding.full
                        color: Appearance.colors.colLayer2
                        implicitWidth: connectedPillRow.implicitWidth + 20
                        implicitHeight: connectedPillRow.implicitHeight + 10

                        RowLayout {
                            id: connectedPillRow
                            anchors.centerIn: parent
                            spacing: 6

                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                width: 6; height: 6
                                radius: Appearance.rounding.full
                                color: Appearance.m3colors.m3primary

                                SequentialAnimation on opacity {
                                    running: root.activeNetwork !== null
                                    loops: Animation.Infinite
                                    NumberAnimation { from: 1;    to: 0.35; duration: 900; easing.type: Easing.InOutQuad }
                                    NumberAnimation { from: 0.35; to: 1;    duration: 900; easing.type: Easing.InOutQuad }
                                }
                            }

                            StyledText {
                                text: qsTr("Connected")
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: 500
                                color: Appearance.m3colors.m3primary
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                Rectangle {
                    Layout.fillWidth: true
                    visible: root.networkSearchVisible
                    implicitHeight: searchInputField.implicitHeight
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colLayer1
                    border.color: Appearance.colors.colOutlineVariant
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        spacing: 0

                        MaterialSymbol {
                            Layout.leftMargin: 8
                            text: "search"
                            font.pixelSize: Appearance.font.pixelSize.larger
                            color: Appearance.colors.colSubtext
                        }

                        StyledTextInput {
                            id: searchInputField
                            Layout.fillWidth: true
                            padding: 8
                            color: Appearance.colors.colOnLayer1
                            verticalAlignment: TextInput.AlignVCenter
                            focus: root.networkSearchVisible
                            onTextChanged: root.searchText = text

                            Text {
                                text: "Search networks…"
                                color: Appearance.m3colors.m3outline
                                font.pixelSize: Appearance.font.pixelSize.small
                                visible: !searchInputField.text && !searchInputField.activeFocus
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 4
                            }
                        }

                        RippleButton {
                            id: clearSearchBtn
                            visible: searchInputField.text.length > 0
                            Layout.alignment: Qt.AlignVCenter
                            Layout.rightMargin: 5
                            implicitHeight: 40
                            buttonRadius: Appearance.rounding.small
                            colBackground: "transparent"
                            colBackgroundHover: "transparent"
                            colBackgroundToggled: "transparent"
                            colBackgroundToggledHover: "transparent"

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: searchInputField.text = ""
                            }

                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                iconSize: Appearance.font.pixelSize.larger
                                color: Appearance.colors.colOnLayer2Disabled
                                text: "close"
                            }
                        }
                    }
                }

                RippleButton {
                    id: discoverBtn
                    visible: Network.wifiEnabled || false

                    contentItem: Rectangle {
                        radius: Appearance.rounding.full
                        color: (Network.scanning || false) ? Appearance.m3colors.m3primary : Appearance.colors.colLayer2
                        implicitWidth: height

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "refresh"
                            color: (Network.scanning || false)
                                ? Appearance.m3colors.m3onSecondary
                                : Appearance.m3colors.m3onSecondaryContainer
                            fill: (Network.scanning || false) ? 1 : 0
                        }
                    }

                    MouseArea {
                        id: discoverArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: Network.rescanWifi()

                        StyledToolTip {
                            extraVisibleCondition: discoverArea.containsMouse
                            text: "Discover new networks"
                        }
                    }
                }

                RippleButton {
                    id: searchToggleBtn
                    visible: Network.wifiEnabled || false

                    contentItem: Rectangle {
                        radius: Appearance.rounding.full
                        color: root.networkSearchVisible ? Appearance.m3colors.m3primary : Appearance.colors.colLayer2
                        implicitWidth: height

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "search"
                            color: root.networkSearchVisible
                                ? Appearance.m3colors.m3onSecondary
                                : Appearance.m3colors.m3onSecondaryContainer
                            fill: root.networkSearchVisible ? 1 : 0
                        }
                    }

                    MouseArea {
                        id: searchToggleArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.networkSearchVisible = !root.networkSearchVisible;
                            if (!root.networkSearchVisible) {
                                searchInputField.text = "";
                                root.searchText = "";
                            } else {
                                Qt.callLater(searchInputField.forceActiveFocus);
                            }
                        }

                        StyledToolTip {
                            extraVisibleCondition: searchToggleArea.containsMouse
                            text: root.networkSearchVisible ? "Hide search" : "Search networks"
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                Layout.topMargin: 12
                Layout.bottomMargin: 12
                visible: !(Network.wifiEnabled || false)
                spacing: 14

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: "signal_wifi_off"
                    font.pixelSize: 48
                    color: Appearance.colors.colOnLayer1
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Turn on WiFi to see available networks"
                    color: Appearance.colors.colOnLayer1
                    font.pixelSize: Appearance.font.pixelSize.large
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 14
                visible: Network.wifiEnabled || false

                Repeater {
                    id: networkRepeater

                    model: ScriptModel {
                        id: networkModel
                        values: {
                            let _t = root.refreshTrigger;
                            const search = root.searchText.toLowerCase().trim();
                            let nets = [...(Network.networks || [])];
                            if (search) nets = nets.filter(n => n.ssid.toLowerCase().includes(search));
                            nets.sort((a, b) => a.active !== b.active ? (b.active - a.active) : (b.strength - a.strength));
                            return nets;
                        }
                    }

                    RowLayout {
                        id: networkItem

                        required property var modelData
                        readonly property bool isConnecting: Network.connectingToSsid === modelData.ssid

                        property bool expanded: false

                        Layout.fillWidth: true
                        spacing: 10

                        onExpandedChanged: {
                            if (!expanded) {
                                passwdInput.text   = "";
                                showButton.toggled = false;
                            }
                        }

                        Rectangle {
                            id: netRect
                            Layout.fillWidth: true
                            implicitHeight: netCard.height + dropDownBox.height
                            radius: Appearance.rounding.small
                            color: Appearance.colors.colLayer2
                            border.width: (networkItem.modelData?.active || false) ? 2 : 0
                            border.color: Appearance.m3colors.m3primary

                            Behavior on border.width { NumberAnimation { duration: 150 } }

                            ColumnLayout {
                                id: netCard
                                width: parent.width

                                RowLayout {
                                    spacing: 16
                                    Layout.margins: 18

                                    RowLayout {
                                        spacing: 6

                                        MaterialSymbol {
                                            text: Network.getNetworkIcon(networkItem.modelData.strength)
                                            font.pixelSize: Appearance.font.pixelSize.title
                                            color: Appearance.colors.colOnSecondaryContainer
                                        }

                                        MaterialSymbol {
                                            visible: networkItem.modelData?.isSecure || false
                                            text: "lock"
                                            font.pixelSize: Appearance.font.pixelSize.larger
                                            color: Appearance.colors.colOnSecondaryContainer
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: networkItem.modelData.ssid
                                            font.pixelSize: Appearance.font.pixelSize.large
                                            font.weight: networkItem.modelData.active ? 500 : 400
                                            color: networkItem.modelData.active
                                                ? Appearance.m3colors.m3primary
                                                : Appearance.colors.colOnLayer1
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: "Open Network"
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            color: Appearance.colors.colSubtext
                                            visible: !(networkItem.modelData?.isSecure || false)
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: "Failed to connect: " + root.lastConnectionError
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            color: Appearance.m3colors.m3error
                                            wrapMode: Text.WordWrap
                                            visible: root.showConnectionError && root.errorSsid === networkItem.modelData.ssid
                                        }
                                    }

                                    RippleButton {
                                        id: expandBtn
                                        visible: (networkItem.modelData?.isSecure || false) || (networkItem.modelData?.active || false)

                                        contentItem: Rectangle {
                                            radius: Appearance.rounding.full
                                            color: Appearance.colors.colLayer2
                                            implicitWidth: height

                                            MaterialSymbol {
                                                anchors.centerIn: parent
                                                text: networkItem.expanded ? "keyboard_arrow_up" : "keyboard_arrow_down"
                                                color: Appearance.m3colors.m3onSecondaryContainer
                                                fill: 0
                                            }
                                        }

                                        MouseArea {
                                            id: expandArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: networkItem.expanded = !networkItem.expanded

                                            StyledToolTip {
                                                extraVisibleCondition: expandArea.containsMouse
                                                text: networkItem.expanded ? "Collapse" : "Expand"
                                            }
                                        }
                                    }

                                    Item {
                                        Layout.fillWidth: false
                                        Layout.preferredWidth: toggleSwitch.width
                                        Layout.preferredHeight: toggleSwitch.height

                                        StyledSwitch {
                                            id: toggleSwitch
                                            anchors.centerIn: parent
                                            scale: 0.80
                                            checked: networkItem.modelData?.active || false
                                            enabled: false
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: (mouse) => {
                                                mouse.accepted = true;
                                                const isActive = networkItem.modelData?.active  || false;
                                                const isSecure = networkItem.modelData?.isSecure || false;
                                                const isKnown  = networkItem.modelData?.isKnown  || false;

                                                if (isActive) {
                                                    Network.disconnectFromNetwork();
                                                } else if (!isSecure) {
                                                    Network.connectToNetwork(networkItem.modelData.ssid, "");
                                                } else if (isKnown) {
                                                    if (Network.hasConnectionFailed(networkItem.modelData.ssid)) {
                                                        Qt.callLater(() => { networkItem.expanded = true; });
                                                    } else {
                                                        Network.connectToNetwork(networkItem.modelData.ssid, "");
                                                    }
                                                } else {
                                                    networkItem.expanded = true;
                                                }
                                            }

                                            StyledToolTip {
                                                text: networkItem.modelData?.active
                                                    ? "Disconnect from network"
                                                    : networkItem.modelData?.isKnown
                                                        ? "Connect to known network"
                                                        : networkItem.modelData?.isSecure
                                                            ? "Click to enter password"
                                                            : "Click to connect to open network"
                                                visible: parent.containsMouse || false
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                id: dropDownBox
                                anchors.top: netCard.bottom
                                width: parent.width
                                height: networkItem.expanded ? dropDownContent.implicitHeight + 36 : 0
                                color: "transparent"
                                opacity: networkItem.expanded ? 1 : 0
                                visible: height > 0

                                Behavior on height  { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
                                Behavior on opacity { NumberAnimation { duration: 150 } }

                                ColumnLayout {
                                    id: dropDownContent
                                    anchors.fill: parent
                                    anchors.margins: 18
                                    spacing: 0

                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 20

                                        RowLayout {
                                            spacing: 10
                                            visible: root.showSensitiveInfo
                                            MaterialSymbol { text: "fingerprint"; font.pixelSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colOnSecondaryContainer }
                                            ColumnLayout {
                                                spacing: 2
                                                StyledText { text: "BSSID"; font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colSubtext }
                                                StyledText { text: networkItem.modelData.bssid; font.pixelSize: Appearance.font.pixelSize.small }
                                            }
                                        }

                                        RowLayout {
                                            spacing: 10
                                            MaterialSymbol { text: "settings_input_antenna"; font.pixelSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colOnSecondaryContainer }
                                            ColumnLayout {
                                                spacing: 2
                                                StyledText { text: "Frequency"; font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colSubtext }
                                                StyledText { text: root.formatFrequency(networkItem.modelData.frequency); font.pixelSize: Appearance.font.pixelSize.small }
                                            }
                                        }

                                        RowLayout {
                                            spacing: 10
                                            MaterialSymbol { text: "encrypted"; font.pixelSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colOnSecondaryContainer }
                                            ColumnLayout {
                                                spacing: 2
                                                StyledText { text: "Security"; font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colSubtext }
                                                StyledText { text: networkItem.modelData.security; font.pixelSize: Appearance.font.pixelSize.small }
                                            }
                                        }

                                        RowLayout {
                                            id: latencyRow
                                            readonly property real pingValue: root.speedTestPing(networkItem.modelData.ssid)
                                            readonly property bool isLive: root.speedTestIsLive(networkItem.modelData.ssid)
                                            spacing: 10
                                            visible: pingValue >= 0 || (isLive && root.speedTestStage === "ping")
                                            MaterialSymbol { text: "timer"; font.pixelSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colOnSecondaryContainer }
                                            ColumnLayout {
                                                spacing: 2
                                                StyledText { text: "Latency"; font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colSubtext }
                                                StyledText {
                                                    text: latencyRow.pingValue >= 0
                                                        ? latencyRow.pingValue.toFixed(0) + " ms"
                                                        : (latencyRow.isLive && root.speedTestStage === "ping" ? "…" : "—")
                                                    font.pixelSize: Appearance.font.pixelSize.small
                                                }
                                            }
                                        }

                                        RowLayout {
                                            id: downloadRow
                                            readonly property real downloadValue: root.speedTestDownload(networkItem.modelData.ssid)
                                            readonly property bool isLive: root.speedTestIsLive(networkItem.modelData.ssid)
                                            spacing: 10
                                            visible: downloadValue >= 0 || (isLive && (root.speedTestStage === "ping" || root.speedTestStage === "download"))
                                            MaterialSymbol { text: "arrow_downward"; font.pixelSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colOnSecondaryContainer }
                                            ColumnLayout {
                                                spacing: 2
                                                StyledText { text: "Download"; font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colSubtext }
                                                StyledText {
                                                    text: downloadRow.downloadValue >= 0
                                                        ? downloadRow.downloadValue.toFixed(1) + " Mbps"
                                                        : (downloadRow.isLive ? "…" : "—")
                                                    font.pixelSize: Appearance.font.pixelSize.small
                                                }
                                            }
                                        }

                                        RowLayout {
                                            id: uploadRow
                                            readonly property real uploadValue: root.speedTestUpload(networkItem.modelData.ssid)
                                            readonly property bool isLive: root.speedTestIsLive(networkItem.modelData.ssid)
                                            spacing: 10
                                            visible: uploadValue >= 0 || (isLive && root.speedTestStage === "upload")
                                            MaterialSymbol { text: "arrow_upward"; font.pixelSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colOnSecondaryContainer }
                                            ColumnLayout {
                                                spacing: 2
                                                StyledText { text: "Upload"; font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colSubtext }
                                                StyledText {
                                                    text: uploadRow.uploadValue >= 0
                                                        ? uploadRow.uploadValue.toFixed(1) + " Mbps"
                                                        : (uploadRow.isLive ? "…" : "—")
                                                    font.pixelSize: Appearance.font.pixelSize.small
                                                }
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.topMargin: 16
                                        spacing: 10
                                        visible: (networkItem.modelData?.isSecure || false) &&
                                                 (!(networkItem.modelData?.isKnown || false) ||
                                                  Network.hasConnectionFailed(networkItem.modelData.ssid))

                                        Rectangle { Layout.fillWidth: true; height: 1; color: Appearance.colors.colOutlineVariant }

                                        StyledText { text: "Password"; font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colSubtext }

                                        Rectangle {
                                            id: inputWrapper
                                            Layout.fillWidth: true
                                            radius: Appearance.rounding.small
                                            color: Appearance.colors.colLayer1
                                            implicitHeight: passwdInput.implicitHeight
                                            clip: true
                                            border.color: Appearance.colors.colOutlineVariant
                                            border.width: 1

                                            RowLayout {
                                                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                                                spacing: 0

                                                StyledTextInput {
                                                    id: passwdInput
                                                    Layout.fillWidth: true
                                                    padding: 12
                                                    color: Appearance.colors.colOnLayer1
                                                    echoMode: showButton.toggled ? TextInput.Normal : TextInput.Password
                                                    passwordCharacter: "●"
                                                    passwordMaskDelay: 0
                                                    verticalAlignment: TextInput.AlignVCenter

                                                    Text {
                                                        text: "Enter password..."
                                                        color: Appearance.m3colors.m3outline
                                                        font.pixelSize: Appearance.font.pixelSize.small
                                                        visible: !passwdInput.text && !passwdInput.activeFocus
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        anchors.left: parent.left
                                                        anchors.leftMargin: 10
                                                    }

                                                    Keys.onPressed: (event) => {
                                                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                                            Network.connectToNetwork(networkItem.modelData.ssid, passwdInput.text);
                                                            networkItem.expanded = false;
                                                        }
                                                    }
                                                }

                                                RippleButton {
                                                    id: showButton
                                                    Layout.alignment: Qt.AlignVCenter
                                                    Layout.leftMargin: 5
                                                    implicitHeight: 40
                                                    buttonRadius: Appearance.rounding.small
                                                    toggled: false
                                                    colBackground: "transparent"
                                                    colBackgroundHover: "transparent"
                                                    colBackgroundToggled: "transparent"
                                                    colBackgroundToggledHover: "transparent"

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: showButton.toggled = !showButton.toggled
                                                    }

                                                    contentItem: MaterialSymbol {
                                                        anchors.centerIn: parent
                                                        horizontalAlignment: Text.AlignHCenter
                                                        iconSize: Appearance.font.pixelSize.larger
                                                        color: showButton.toggled
                                                            ? Appearance.colors.colOnLayer2
                                                            : Appearance.colors.colOnLayer2Disabled
                                                        text: showButton.toggled ? "visibility" : "visibility_off"
                                                    }
                                                }

                                                RippleButton {
                                                    id: sendButton
                                                    Layout.alignment: Qt.AlignVCenter
                                                    Layout.rightMargin: 5
                                                    implicitHeight: 40
                                                    buttonRadius: Appearance.rounding.small
                                                    enabled: passwdInput.text.length !== 0
                                                    colBackground: "transparent"
                                                    colBackgroundHover: "transparent"
                                                    colBackgroundToggled: "transparent"
                                                    colBackgroundToggledHover: "transparent"

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: sendButton.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                        onClicked: {
                                                            Network.connectToNetwork(networkItem.modelData.ssid, passwdInput.text);
                                                            networkItem.expanded = false;
                                                        }
                                                    }

                                                    contentItem: MaterialSymbol {
                                                        anchors.centerIn: parent
                                                        horizontalAlignment: Text.AlignHCenter
                                                        iconSize: Appearance.font.pixelSize.larger
                                                        color: sendButton.enabled
                                                            ? Appearance.colors.colOnLayer2
                                                            : Appearance.colors.colOnLayer2Disabled
                                                        text: "lock_open_right"
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.topMargin: 16
                                        spacing: 14
                                        visible: (networkItem.modelData?.active || false) || (networkItem.modelData?.isKnown || false)

                                        Rectangle { Layout.fillWidth: true; height: 1; color: Appearance.colors.colOutlineVariant }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 14

                                            RowLayout {
                                                spacing: 6
                                                visible: networkItem.modelData?.active || false

                                                RippleButtonWithIcon {
                                                    materialIcon: "speed"
                                                    mainText: root.speedTestRunning
                                                        ? "Testing…"
                                                        : root.speedTestIsDone(networkItem.modelData.ssid)
                                                            ? "Test Again"
                                                            : "Speed Test"
                                                    enabled: !root.speedTestRunning
                                                    onClicked: root.startSpeedTest()
                                                }

                                                Rectangle {
                                                    Layout.preferredWidth: 6
                                                    Layout.preferredHeight: 6
                                                    Layout.alignment: Qt.AlignVCenter
                                                    radius: 3
                                                    color: Appearance.m3colors.m3primary
                                                    visible: root.speedTestRunning

                                                    // Scoped to this row's expanded state - a Repeater can
                                                    // have many delegates; no reason to animate the ones
                                                    // that aren't expanded/visible.
                                                    SequentialAnimation on opacity {
                                                        running: root.speedTestRunning && networkItem.expanded
                                                        loops: Animation.Infinite
                                                        NumberAnimation { from: 1;    to: 0.25; duration: 550; easing.type: Easing.InOutQuad }
                                                        NumberAnimation { from: 0.25; to: 1;    duration: 550; easing.type: Easing.InOutQuad }
                                                    }
                                                }
                                            }

                                            RippleButtonWithIcon {
                                                materialIcon: "qr_code_2"
                                                mainText: "Share QR"
                                                visible: networkItem.modelData?.active || false
                                                enabled: true
                                                onClicked: {
                                                    if (root.qrGenerating)
                                                        return;

                                                    if (root.qrActiveSsid === networkItem.modelData.ssid &&
                                                        (root.qrImagePath !== "" || root.qrError !== "")) {
                                                        root.qrActiveSsid = "";
                                                        root.qrImagePath  = "";
                                                        root.qrError      = "";
                                                        qrPanel.opacity = 0;
                                                        qrFadeInAnim.stop();
                                                    } else {
                                                        root.generateQrCode(networkItem.modelData.ssid,
                                                                            networkItem.modelData.security || "");
                                                        qrPanel.opacity = 0;
                                                        qrFadeInAnim.restart();
                                                    }
                                                }
                                            }

                                            RippleButtonWithIcon {
                                                materialIcon: "delete"
                                                mainText: "Forget Network"
                                                visible: networkItem.modelData?.isKnown || false
                                                onClicked: {
                                                    Network.forgetNetwork(networkItem.modelData.ssid);
                                                    networkItem.expanded = false;
                                                }
                                            }

                                            Item { Layout.fillWidth: true }
                                        }

                                        Item {
                                            Layout.fillWidth: true
                                            readonly property bool qrActive: root.qrActiveSsid === networkItem.modelData.ssid &&
                                                                             (networkItem.modelData?.active || false) &&
                                                                             (root.qrGenerating || root.qrImagePath !== "" || root.qrError !== "")
                                            readonly property real targetH: qrActive ? qrPanel.implicitHeight : 0
                                            height: targetH
                                            implicitHeight: targetH
                                            clip: true

                                            Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.InOutQuad } }

                                            SequentialAnimation {
                                                id: qrFadeInAnim
                                                PauseAnimation { duration: 150 }
                                                NumberAnimation { target: qrPanel; property: "opacity"; to: 1; duration: 220; easing.type: Easing.InOutQuad }
                                            }

                                            ColumnLayout {
                                                id: qrPanel
                                                width: parent.width
                                                spacing: 10
                                                opacity: 0

                                                Rectangle { Layout.fillWidth: true; height: 1; color: Appearance.colors.colOutlineVariant }

                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    implicitHeight: 76
                                                    radius: Appearance.rounding.small
                                                    clip: true
                                                    visible: root.qrGenerating &&
                                                             root.qrActiveSsid === networkItem.modelData.ssid
                                                    color: Qt.rgba(Appearance.m3colors.m3primaryContainer.r,
                                                                   Appearance.m3colors.m3primaryContainer.g,
                                                                   Appearance.m3colors.m3primaryContainer.b, 0.22)

                                                    RowLayout {
                                                        anchors {
                                                            left: parent.left; right: parent.right
                                                            verticalCenter: parent.verticalCenter
                                                            leftMargin: 16; rightMargin: 16
                                                        }
                                                        spacing: 14

                                                        MaterialSymbol {
                                                            text: "qr_code_2"
                                                            font.pixelSize: 30
                                                            color: Appearance.m3colors.m3primary

                                                            // Scoped to this delegate's ssid so a Repeater with
                                                            // multiple known/active networks doesn't animate
                                                            // hidden rows while one QR code is generating.
                                                            SequentialAnimation on opacity {
                                                                running: root.qrGenerating && root.qrActiveSsid === networkItem.modelData.ssid
                                                                loops: Animation.Infinite
                                                                NumberAnimation { from: 1.0; to: 0.2; duration: 650; easing.type: Easing.InOutQuad }
                                                                NumberAnimation { from: 0.2; to: 1.0; duration: 650; easing.type: Easing.InOutQuad }
                                                            }
                                                        }

                                                        ColumnLayout {
                                                            Layout.fillWidth: true
                                                            spacing: 3

                                                            StyledText {
                                                                text: "Generating QR code"
                                                                font.pixelSize: Appearance.font.pixelSize.normal
                                                                font.weight: 500
                                                                color: Appearance.m3colors.m3primary
                                                            }
                                                            StyledText {
                                                                text: "Retrieving network credentials…"
                                                                font.pixelSize: Appearance.font.pixelSize.small
                                                                color: Appearance.colors.colSubtext
                                                            }
                                                        }
                                                    }

                                                    Rectangle {
                                                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                                                        height: 3
                                                        color: Qt.rgba(Appearance.m3colors.m3primary.r,
                                                                       Appearance.m3colors.m3primary.g,
                                                                       Appearance.m3colors.m3primary.b, 0.25)

                                                        Rectangle {
                                                            id: qrScanBar
                                                            height: parent.height
                                                            width: 80
                                                            radius: 2
                                                            color: Appearance.m3colors.m3primary

                                                            SequentialAnimation on x {
                                                                running: root.qrGenerating && root.qrActiveSsid === networkItem.modelData.ssid
                                                                loops: Animation.Infinite
                                                                NumberAnimation { from: -qrScanBar.width; to: qrScanBar.parent.width; duration: 1000; easing.type: Easing.InOutCubic }
                                                            }
                                                        }
                                                    }
                                                }

                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    implicitHeight: qrErrorRow.implicitHeight + 24
                                                    radius: Appearance.rounding.small
                                                    visible: root.qrError !== "" &&
                                                             root.qrActiveSsid === networkItem.modelData.ssid
                                                    color: Qt.rgba(Appearance.m3colors.m3errorContainer.r,
                                                                   Appearance.m3colors.m3errorContainer.g,
                                                                   Appearance.m3colors.m3errorContainer.b, 0.35)

                                                    RowLayout {
                                                        id: qrErrorRow
                                                        anchors {
                                                            left: parent.left; right: parent.right; top: parent.top
                                                            margins: 14
                                                        }
                                                        spacing: 10

                                                        MaterialSymbol {
                                                            Layout.alignment: Qt.AlignTop
                                                            text: "error_outline"
                                                            font.pixelSize: Appearance.font.pixelSize.larger
                                                            color: Appearance.m3colors.m3error
                                                        }
                                                        StyledText {
                                                            Layout.fillWidth: true
                                                            text: root.qrError
                                                            font.pixelSize: Appearance.font.pixelSize.small
                                                            color: Appearance.m3colors.m3error
                                                            wrapMode: Text.WordWrap
                                                        }
                                                    }
                                                }

                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    implicitHeight: qrReadyRow.implicitHeight + 32
                                                    radius: Appearance.rounding.small
                                                    visible: root.qrImagePath !== "" &&
                                                             root.qrActiveSsid === networkItem.modelData.ssid
                                                    color: Qt.rgba(Appearance.m3colors.m3primaryContainer.r,
                                                                   Appearance.m3colors.m3primaryContainer.g,
                                                                   Appearance.m3colors.m3primaryContainer.b, 0.22)

                                                    RowLayout {
                                                        id: qrReadyRow
                                                        anchors {
                                                            left: parent.left; right: parent.right; top: parent.top
                                                            leftMargin: 16; rightMargin: 16; topMargin: 16
                                                        }
                                                        spacing: 20

                                                        Rectangle {
                                                            width: 148; height: 148
                                                            color: "white"
                                                            radius: Appearance.rounding.small

                                                            Image {
                                                                anchors { fill: parent; margins: 8 }
                                                                source: root.qrImagePath
                                                                smooth: false
                                                                fillMode: Image.PreserveAspectFit
                                                                cache: false
                                                            }
                                                        }

                                                        ColumnLayout {
                                                            Layout.fillWidth: true
                                                            Layout.alignment: Qt.AlignVCenter
                                                            spacing: 8

                                                            StyledText {
                                                                Layout.fillWidth: true
                                                                text: root.qrActiveSsid
                                                                font.pixelSize: Appearance.font.pixelSize.large
                                                                font.weight: 600
                                                                color: Appearance.m3colors.m3primary
                                                                elide: Text.ElideRight
                                                            }

                                                            Rectangle {
                                                                radius: Appearance.rounding.full
                                                                color: Qt.rgba(Appearance.m3colors.m3primary.r,
                                                                               Appearance.m3colors.m3primary.g,
                                                                               Appearance.m3colors.m3primary.b, 0.12)
                                                                implicitWidth: qrSecBadge.implicitWidth + 16
                                                                implicitHeight: qrSecBadge.implicitHeight + 8

                                                                RowLayout {
                                                                    id: qrSecBadge
                                                                    anchors.centerIn: parent
                                                                    spacing: 4

                                                                    MaterialSymbol {
                                                                        text: (networkItem.modelData?.isSecure || false) ? "lock" : "lock_open"
                                                                        font.pixelSize: Appearance.font.pixelSize.small
                                                                        color: Appearance.m3colors.m3primary
                                                                    }
                                                                    StyledText {
                                                                        text: networkItem.modelData.security || "Open"
                                                                        font.pixelSize: Appearance.font.pixelSize.small
                                                                        color: Appearance.m3colors.m3primary
                                                                    }
                                                                }
                                                            }

                                                            Rectangle {
                                                                Layout.fillWidth: true
                                                                height: 1
                                                                color: Appearance.colors.colOutlineVariant
                                                                opacity: 0.5
                                                            }

                                                            StyledText {
                                                                Layout.fillWidth: true
                                                                text: "Point your phone's camera at this code to connect instantly — no typing required."
                                                                font.pixelSize: Appearance.font.pixelSize.small
                                                                color: Appearance.colors.colSubtext
                                                                wrapMode: Text.WordWrap
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Item { implicitHeight: 24 }
}
