import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.services
import qs.services as Services
import qs.modules.common
import qs.modules.common.widgets

import Sleex.Services

// qs.services imported both plain (bare Config) and as Services (Services.Network,
// to avoid clashing with the bare C++ Network singleton below)
ContentPage {
    id: root
    forceSingleColumn: true

    property bool showSensitiveInfo: false
    property bool showConnectionDetails: true
    property bool networkSearchVisible: false
    property string searchText: ""

    property bool customDnsEnabled: false
    property string customDnsProviderId: "cloudflare"

    readonly property var filteredDetailItems: {
        var arr = [];
        for (var i = 0; i < Services.Network.detailItems.length; ++i) {
            const item = Services.Network.detailItems[i];
            if (item.wifiOnly && Services.Network.activeNetwork === null) continue;
            if (!item.isSensitive || root.showSensitiveInfo)
                arr.push(item);
        }
        return arr;
    }

    function _syncViewTogglesFromConfig() {
        root.showSensitiveInfo     = Config.options.networking.sensitiveNetworkInfo  || false;
        root.showConnectionDetails = Config.options.networking.connectionDetails !== undefined
                                      ? Config.options.networking.connectionDetails : true;
        const savedProvider = Config.options.networking.dnsProvider;
        if (savedProvider) root.customDnsProviderId = savedProvider;
        root.customDnsEnabled = Config.options.networking.dnsSwitch || false;
    }

    Component.onCompleted: root._syncViewTogglesFromConfig()

    // Re-sync on every Config reload since load order relative to Config isn't guaranteed
    Connections {
        target: Config
        function onIsReloadingChanged() {
            if (!Config.isReloading) root._syncViewTogglesFromConfig();
        }
    }

    Connections {
        target: Network

        function onPasswordRequired(ssid) {
            for (let i = 0; i < networkRepeater.count; i++) {
                const item = networkRepeater.itemAt(i);
                if (item?.modelData?.ssid === ssid) {
                    item.expanded = true;
                    break;
                }
            }
            Services.Network.bumpRefresh();
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
                checked: Services.Network.wifiEnabled
                onClicked: Network.toggleWifi()
                StyledToolTip {
                    text: Services.Network.wifiEnabled ? "Click to disable WiFi" : "Click to enable WiFi"
                }
            }

            ConfigSwitch {
                text: "Connection Details"
                checked: root.showConnectionDetails
                onClicked: {
                    root.showConnectionDetails = !root.showConnectionDetails;
                    try {
                        Config.setNestedValue("networking.connectionDetails", root.showConnectionDetails);
                    } catch (e) {
                        console.log("[Wifi] Failed to persist connectionDetails:", e);
                    }
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
                    try {
                        Config.setNestedValue("networking.sensitiveNetworkInfo", root.showSensitiveInfo);
                    } catch (e) {
                        console.log("[Wifi] Failed to persist sensitiveNetworkInfo:", e);
                    }
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
        readonly property real targetHeight: Services.Network.hasActiveConnection && root.showConnectionDetails
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
            visible: Services.Network.hasActiveConnection && root.showConnectionDetails
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
                        text: Services.Network.activeConnectionType.includes("wireless") ? "wifi" : "settings_ethernet"
                        font.pixelSize: Appearance.font.pixelSize.title
                        color: Appearance.m3colors.m3primary
                    }

                    ColumnLayout {
                        spacing: 2

                        StyledText {
                            text: Services.Network.activeNetwork?.ssid || (Services.Network.hasWiredConnection ? "Wired Connection" : "")
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
                                fill: Services.Network.speedTestRunning ? 1 : 0

                                SequentialAnimation on opacity {
                                    running: Services.Network.speedTestRunning && root.showConnectionDetails
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
                            cursorShape: Services.Network.speedTestRunning ? Qt.ArrowCursor : Qt.PointingHandCursor
                            enabled: !Services.Network.speedTestRunning
                            onClicked: Services.Network.startSpeedTest()

                            StyledToolTip {
                                extraVisibleCondition: speedTestHeaderArea.containsMouse
                                text: Services.Network.speedTestRunning ? "Testing…" : "Perform a network speed test\nUses the Cloudflare provider"
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
                                fill: Services.Network.fetchingNetworkInfo ? 1 : 0

                                RotationAnimation on rotation {
                                    running: Services.Network.fetchingNetworkInfo && root.showConnectionDetails
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
                            onClicked: Services.Network.fetchNetworkInfo()

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
                    visible: Services.Network.netInfoError !== ""
                    text: Services.Network.netInfoError
                    color: Appearance.m3colors.m3error
                    font.pixelSize: Appearance.font.pixelSize.small
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    height: 100

                    Rectangle {
                        visible: Services.Network.activeNetwork !== null
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
                                    width: parent.width * Math.min(Services.Network.activeNetwork?.strength ?? 0, 100) / 100
                                    height: parent.height
                                    radius: 2
                                    color: Appearance.m3colors.m3primary
                                }
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: (Services.Network.activeNetwork?.strength ?? 0) + "%"
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

                        readonly property string targetSsid: Services.Network.activeNetwork ? Services.Network.activeNetwork.ssid : ""
                        readonly property real pingValue: Services.Network.speedTestPing(targetSsid)
                        readonly property bool hasResult: pingValue >= 0

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            MaterialSymbol {
                                Layout.alignment: Qt.AlignHCenter
                                text: "timer"
                                font.pixelSize: 24
                                color: Appearance.m3colors.m3primary
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
                                    : "…"
                                font.pixelSize: Appearance.font.pixelSize.large
                                font.weight: 600
                                color: parent.parent.hasResult ? Appearance.m3colors.m3primary : Appearance.colors.colSubtext
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

                        readonly property string targetSsid: Services.Network.activeNetwork ? Services.Network.activeNetwork.ssid : ""
                        readonly property real downloadValue: Services.Network.speedTestDownload(targetSsid)

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
                                    : "…"
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

                        readonly property string targetSsid: Services.Network.activeNetwork ? Services.Network.activeNetwork.ssid : ""
                        readonly property real uploadValue: Services.Network.speedTestUpload(targetSsid)

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
                                    : "…"
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
                                    width: infoContent.width
                                    text: Services.Network.detailValue(modelData.valueIdx)
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
        readonly property real targetHeight: Services.Network.activeNetwork !== null
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
            visible: Services.Network.activeNetwork !== null
            title: "Custom DNS"
            icon: "dns"

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 14

                ConfigSwitch {
                    text: "Custom DNS"
                    checked: root.customDnsEnabled
                    enabled: !Services.Network.dnsApplying
                    onClicked: {
                        root.customDnsEnabled = !root.customDnsEnabled;
                        Config.options.networking.dnsSwitch = root.customDnsEnabled;
                        Services.Network.applyDnsSettings(root.customDnsEnabled, root.customDnsProviderId);
                    }
                    StyledToolTip {
                        text: Services.Network.dnsApplying
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

                                        readonly property var provider:    Services.Network.dnsProviderMap[modelData] ?? null
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
                                            enabled: !Services.Network.dnsApplying
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.customDnsProviderId = modelData;
                                                Config.options.networking.dnsProvider = modelData;
                                                Services.Network.applyDnsSettings(root.customDnsEnabled, modelData);
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
                    visible: Services.Network.dnsApplyError !== ""

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
                        text: Services.Network.dnsApplyError
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
                        visible: Services.Network.activeNetwork !== null
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
                                    running: Services.Network.activeNetwork !== null
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
                    visible: Services.Network.wifiEnabled

                    contentItem: Rectangle {
                        radius: Appearance.rounding.full
                        color: Services.Network.wifiScanning ? Appearance.m3colors.m3primary : Appearance.colors.colLayer2
                        implicitWidth: height

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "refresh"
                            color: Services.Network.wifiScanning
                                ? Appearance.m3colors.m3onSecondary
                                : Appearance.m3colors.m3onSecondaryContainer
                            fill: Services.Network.wifiScanning ? 1 : 0
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
                    visible: Services.Network.wifiEnabled

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
                visible: !Services.Network.wifiEnabled
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
                visible: Services.Network.wifiEnabled

                Repeater {
                    id: networkRepeater

                    model: ScriptModel {
                        id: networkModel
                        values: {
                            let _t = Services.Network.refreshTrigger; // forces re-evaluation on bump
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
                        property bool expanded: false

                        readonly property bool isActive: modelData?.active   || false
                        readonly property bool isSecure: modelData?.isSecure || false
                        readonly property bool isKnown:  modelData?.isKnown  || false

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
                            border.width: networkItem.isActive ? 2 : 0
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
                                            visible: networkItem.isSecure
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
                                            font.weight: networkItem.isActive ? 500 : 400
                                            color: networkItem.isActive
                                                ? Appearance.m3colors.m3primary
                                                : Appearance.colors.colOnLayer1
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: "Open Network"
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            color: Appearance.colors.colSubtext
                                            visible: !networkItem.isSecure
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: "Failed to connect: " + Services.Network.lastConnectionError
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            color: Appearance.m3colors.m3error
                                            wrapMode: Text.WordWrap
                                            visible: Services.Network.showConnectionError && Services.Network.errorSsid === networkItem.modelData.ssid
                                        }
                                    }

                                    RippleButton {
                                        id: expandBtn
                                        visible: networkItem.isSecure || networkItem.isActive

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
                                            checked: networkItem.isActive
                                            enabled: false
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: (mouse) => {
                                                mouse.accepted = true;
                                                const isActive = networkItem.isActive;
                                                const isSecure = networkItem.isSecure;
                                                const isKnown  = networkItem.isKnown;

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
                                                text: networkItem.isActive
                                                    ? "Disconnect from network"
                                                    : networkItem.isKnown
                                                        ? "Connect to known network"
                                                        : networkItem.isSecure
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
                                                StyledText { text: Services.Network.formatFrequency(networkItem.modelData.frequency); font.pixelSize: Appearance.font.pixelSize.small }
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
                                            readonly property real pingValue: Services.Network.speedTestPing(networkItem.modelData.ssid)
                                            readonly property bool isLive: Services.Network.speedTestIsLive(networkItem.modelData.ssid)
                                            spacing: 10
                                            visible: pingValue >= 0 || isLive
                                            MaterialSymbol { text: "timer"; font.pixelSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colOnSecondaryContainer }
                                            ColumnLayout {
                                                spacing: 2
                                                StyledText { text: "Latency"; font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colSubtext }
                                                StyledText {
                                                    text: latencyRow.pingValue >= 0
                                                        ? latencyRow.pingValue.toFixed(0) + " ms"
                                                        : "…"
                                                    font.pixelSize: Appearance.font.pixelSize.small
                                                }
                                            }
                                        }

                                        RowLayout {
                                            id: downloadRow
                                            readonly property real downloadValue: Services.Network.speedTestDownload(networkItem.modelData.ssid)
                                            readonly property bool isLive: Services.Network.speedTestIsLive(networkItem.modelData.ssid)
                                            spacing: 10
                                            visible: downloadValue >= 0 || isLive
                                            MaterialSymbol { text: "arrow_downward"; font.pixelSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colOnSecondaryContainer }
                                            ColumnLayout {
                                                spacing: 2
                                                StyledText { text: "Download"; font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colSubtext }
                                                StyledText {
                                                    text: downloadRow.downloadValue >= 0
                                                        ? downloadRow.downloadValue.toFixed(1) + " Mbps"
                                                        : "…"
                                                    font.pixelSize: Appearance.font.pixelSize.small
                                                }
                                            }
                                        }

                                        RowLayout {
                                            id: uploadRow
                                            readonly property real uploadValue: Services.Network.speedTestUpload(networkItem.modelData.ssid)
                                            readonly property bool isLive: Services.Network.speedTestIsLive(networkItem.modelData.ssid)
                                            spacing: 10
                                            visible: uploadValue >= 0 || isLive
                                            MaterialSymbol { text: "arrow_upward"; font.pixelSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colOnSecondaryContainer }
                                            ColumnLayout {
                                                spacing: 2
                                                StyledText { text: "Upload"; font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colSubtext }
                                                StyledText {
                                                    text: uploadRow.uploadValue >= 0
                                                        ? uploadRow.uploadValue.toFixed(1) + " Mbps"
                                                        : "…"
                                                    font.pixelSize: Appearance.font.pixelSize.small
                                                }
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.topMargin: 16
                                        spacing: 10
                                        visible: networkItem.isSecure &&
                                                 (!networkItem.isKnown ||
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
                                        visible: networkItem.isActive || networkItem.isKnown

                                        Rectangle { Layout.fillWidth: true; height: 1; color: Appearance.colors.colOutlineVariant }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 14

                                            RowLayout {
                                                spacing: 6
                                                visible: networkItem.isActive

                                                RippleButtonWithIcon {
                                                    materialIcon: "speed"
                                                    mainText: Services.Network.speedTestRunning
                                                        ? "Testing…"
                                                        : Services.Network.speedTestIsDone(networkItem.modelData.ssid)
                                                            ? "Test Again"
                                                            : "Speed Test"
                                                    enabled: !Services.Network.speedTestRunning
                                                    onClicked: Services.Network.startSpeedTest()
                                                }

                                                Rectangle {
                                                    Layout.preferredWidth: 6
                                                    Layout.preferredHeight: 6
                                                    Layout.alignment: Qt.AlignVCenter
                                                    radius: 3
                                                    color: Appearance.m3colors.m3primary
                                                    visible: Services.Network.speedTestRunning

                                                    SequentialAnimation on opacity {
                                                        running: Services.Network.speedTestRunning && networkItem.expanded
                                                        loops: Animation.Infinite
                                                        NumberAnimation { from: 1;    to: 0.25; duration: 550; easing.type: Easing.InOutQuad }
                                                        NumberAnimation { from: 0.25; to: 1;    duration: 550; easing.type: Easing.InOutQuad }
                                                    }
                                                }
                                            }

                                            RippleButtonWithIcon {
                                                materialIcon: "qr_code_2"
                                                mainText: "Share QR"
                                                visible: networkItem.isActive
                                                enabled: true
                                                onClicked: {
                                                    if (Services.Network.qrGenerating)
                                                        return;

                                                    if (Services.Network.qrActiveSsid === networkItem.modelData.ssid &&
                                                        (Services.Network.qrImagePath !== "" || Services.Network.qrError !== "")) {
                                                        Services.Network.qrActiveSsid = "";
                                                        Services.Network.qrImagePath  = "";
                                                        Services.Network.qrError      = "";
                                                        qrPanel.opacity = 0;
                                                        qrFadeInAnim.stop();
                                                    } else {
                                                        Services.Network.generateQrCode(networkItem.modelData.ssid,
                                                            networkItem.modelData.security || "");
                                                        qrPanel.opacity = 0;
                                                        qrFadeInAnim.restart();
                                                    }
                                                }
                                            }

                                            RippleButtonWithIcon {
                                                materialIcon: "delete"
                                                mainText: "Forget Network"
                                                visible: networkItem.isKnown
                                                onClicked: {
                                                    Network.forgetNetwork(networkItem.modelData.ssid);
                                                    networkItem.expanded = false;
                                                }
                                            }

                                            Item { Layout.fillWidth: true }
                                        }

                                        Item {
                                            Layout.fillWidth: true
                                            readonly property bool qrActive: Services.Network.qrActiveSsid === networkItem.modelData.ssid &&
                                                                             networkItem.isActive &&
                                                                             (Services.Network.qrGenerating || Services.Network.qrImagePath !== "" || Services.Network.qrError !== "")
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
                                                    visible: Services.Network.qrGenerating &&
                                                             Services.Network.qrActiveSsid === networkItem.modelData.ssid
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

                                                            SequentialAnimation on opacity {
                                                                running: Services.Network.qrGenerating && Services.Network.qrActiveSsid === networkItem.modelData.ssid
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
                                                                running: Services.Network.qrGenerating && Services.Network.qrActiveSsid === networkItem.modelData.ssid
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
                                                    visible: Services.Network.qrError !== "" &&
                                                             Services.Network.qrActiveSsid === networkItem.modelData.ssid
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
                                                            text: Services.Network.qrError
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
                                                    visible: Services.Network.qrImagePath !== "" &&
                                                             Services.Network.qrActiveSsid === networkItem.modelData.ssid
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
                                                                source: Services.Network.qrImagePath
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
                                                                text: Services.Network.qrActiveSsid
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
                                                                        text: networkItem.isSecure ? "lock" : "lock_open"
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

    Item {
        implicitHeight: 24
    }
}
