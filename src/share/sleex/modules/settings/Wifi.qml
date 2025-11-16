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
    forceWidth: true
    
    // Connection error tracking
    property string lastConnectionError: ""
    property string errorSsid: ""
    property bool showConnectionError: false
    
    // UI refresh trigger
    property int refreshTrigger: 0
    
    // Network connection result handlers
    Connections {
        target: Network
        
        function onConnectionSucceeded(ssid) {
            // Clear any previous errors
            root.showConnectionError = false;
            root.lastConnectionError = "";
            root.errorSsid = "";
            
            // Refresh UI to show updated connection state
            root.refreshTrigger++;
            
            Qt.callLater(function() {
                if (Network.updateNetworks) {
                    Network.updateNetworks();
                }
                if (Network.updateActiveConnection) {
                    Network.updateActiveConnection();
                }
                // Force ScriptModel re-evaluation
                root.refreshTrigger++;
            });
        }
        
        function onConnectionFailed(ssid, error) {
            root.lastConnectionError = error;
            root.errorSsid = ssid;
            root.showConnectionError = true;
            
            // Auto-hide error after 5 seconds
            errorTimer.restart();
            
            // Refresh UI to show current state
            root.refreshTrigger++;
            
            Qt.callLater(function() {
                if (Network.updateNetworks) {
                    Network.updateNetworks();
                }
                if (Network.updateActiveConnection) {
                    Network.updateActiveConnection();
                }
                // Force ScriptModel re-evaluation
                root.refreshTrigger++;
            });
        }
    }
    
    // Timer to auto-hide connection errors
    Timer {
        id: errorTimer
        interval: 5000
        onTriggered: {
            root.showConnectionError = false;
        }
    }



    // Rectangle {
    //     Layout.fillWidth: true
    //     height: warnChildren.height + 40
    //     color: "#40FF9800"
    //     radius: 6

    //     RowLayout {
    //         id: warnChildren
    //         anchors.fill: parent
    //         anchors.margins: 10

    //         Label {
    //             text: "🚧"
    //             font.pixelSize: 16 // Slightly smaller icon
    //             Layout.alignment: Qt.AlignVCenter
    //             rightPadding: 6
    //         }

    //         Label {
    //             Layout.fillWidth: true
    //             Layout.alignment: Qt.AlignVCenter
    //             text: "<b>WORK IN PROGRESS:</b> This module is incomplete. You can connect and disconnect to known devices, nothing else.</code>"
    //             font.pixelSize: 12
    //             wrapMode: Text.WordWrap
    //             textFormat: Text.RichText
    //             color: "white"
    //         }
    //     }
    // }

    ContentSection {
        title: "Wifi settings"

        RowLayout {
            spacing: 10
            uniformCellSizes: true

            ConfigSwitch {
                text: "Enabled"
                checked: Network.wifiEnabled || false
                onClicked: {
                    const newState = !checked;
                    // Toggle WiFi state
                    Network.toggleWifi();
                }
                StyledToolTip {
                    text: Network.wifiEnabled ? "Click to disable WiFi" : "Click to enable WiFi"
                }
            }
        }
    }

    RowLayout {
        spacing: 10

        StyledText {
            text: {
                const networks = Network.networks;
                let available = qsTr("%1 network%2 available").arg(networks.length).arg(networks.length === 1 ? "" : "s");
                const connected = networks.filter(n => n.active).length;
                if (connected > 0)
                    available += qsTr(" (%1 connected)").arg(connected);
                return available;
            }
            color: Appearance.colors.colOnLayer0
            font.pixelSize: Appearance.font.pixelSize.huge
        }

        RippleButton {
            id: discoverBtn

            visible: Network.wifiEnabled || false

            contentItem: Rectangle {
                id: discoverBtnBody
                radius: Appearance.rounding.full
                color: (Network.scanning || false) ? Appearance.m3colors.m3primary : Appearance.colors.colLayer2
                implicitWidth: height

                MaterialSymbol {
                    id: scanIcon

                    anchors.centerIn: parent
                    text: "refresh"
                    color: (Network.scanning || false) ? Appearance.m3colors.m3onSecondary : Appearance.m3colors.m3onSecondaryContainer
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
    }

    ContentSection {

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            visible: !(Network.wifiEnabled || false)
            spacing: 10

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: "wifi_off"
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

        // Connection error display
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.showConnectionError ? (errorContent.contentHeight + 32) : 0
            Layout.topMargin: -40
            Layout.bottomMargin: root.showConnectionError ? 25 : 0
            color: Appearance.colors.colLayer2
            border.color: Appearance.m3colors.m3outline
            border.width: 1
            radius: Appearance.rounding.small
            visible: root.showConnectionError && (Network.wifiEnabled || false)
            opacity: root.showConnectionError ? 1 : 0
            
            Behavior on Layout.preferredHeight { NumberAnimation { duration: 200 } }
            Behavior on Layout.bottomMargin { NumberAnimation { duration: 200 } }
            Behavior on opacity { NumberAnimation { duration: 200 } }
            
            StyledText {
                id: errorContent
                anchors.fill: parent
                anchors.margins: 16
                
                text: "Failed to connect to \"" + root.errorSsid + "\"\n\n" + root.lastConnectionError
                color: Appearance.colors.colOnLayer1
                font.weight: 500
                font.pixelSize: Appearance.font.pixelSize.small || 14
                wrapMode: Text.WordWrap
                verticalAlignment: Text.AlignVCenter
                textFormat: Text.PlainText
            }
        }

        StyledTextArea {
            id: networkSearch
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.topMargin: root.showConnectionError ? 15 : 0
            placeholderText: "Search networks"
            visible: Network.wifiEnabled || false
        }



        Repeater {
            id: networkRepeater
            visible: Network.wifiEnabled || false
            model: ScriptModel {
                id: networkModel
                // values: [...Network.networks].sort((a, b) => {
                //     if (a.active !== b.active)
                //         return b.active - a.active;
                //     return b.strength - a.strength;
                // }).slice(0, 8)

                values: {
                    // Force model re-evaluation when network state changes
                    let trigger = root.refreshTrigger;
                    
                    let networks = [...Network.networks].sort((a, b) => {
                        if (a.active !== b.active)
                            return b.active - a.active;
                        return b.strength - a.strength;
                    });
                    if (networkSearch.text.trim() !== "") {
                        networks = networks.filter(n => n.ssid.toLowerCase().includes(networkSearch.text.toLowerCase()));
                    }
                    return networks;
                }
            }

            RowLayout {
                id: networkItem

                required property var modelData
                readonly property bool isConnecting: Network.connectingToSsid === modelData.ssid
                readonly property bool loading: networkItem.isConnecting

                property bool expanded: false

                Layout.fillWidth: true
                spacing: 10

                

                Rectangle {
                    id: netRect
                    Layout.fillWidth: true
                    implicitHeight: netCard.height  + dropDownBox.height
                    radius: Appearance.rounding.small

                    color: Appearance.colors.colLayer2
                    
                    ColumnLayout {
                        width: parent.width
                        id: netCard

                        RowLayout {
                            spacing: 10
                            Layout.margins: 10
                            
                            RowLayout {

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
                                id: cardTexts

                                StyledText {
                                    Layout.fillWidth: true
                                    text: networkItem.modelData.ssid
                                    font.pixelSize: Appearance.font.pixelSize.large
                                    font.weight: networkItem.modelData.active ? 500 : 400
                                    color: networkItem.modelData.active ? Appearance.m3colors.m3primary : Appearance.colors.colOnLayer1
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: "Open Network"
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colSubtext
                                    visible: !(networkItem.modelData?.isSecure || false)
                                }
                            }

                            MaterialSymbol {
                                visible: networkItem.modelData?.isSecure || false
                                text: networkItem.expanded ? "keyboard_arrow_up" : "keyboard_arrow_down"
                                font.pixelSize: Appearance.font.pixelSize.larger
                                color: Appearance.colors.colOnSecondaryContainer

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: {
                                        networkItem.expanded = !networkItem.expanded
                                    }
                                }
                            }

                            // Forget network button for known networks
                            RippleButton {
                                id: forgetNetworkBtn
                                visible: networkItem.modelData?.isKnown || false
                                implicitWidth: 32
                                implicitHeight: 32
                                buttonRadius: Appearance.rounding.full
                                
                                contentItem: MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "delete"
                                    color: Appearance.m3colors.m3error
                                    iconSize: 16
                                }
                                
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        Network.forgetNetwork(networkItem.modelData.ssid);
                                    }
                                }

                                StyledToolTip {
                                    extraVisibleCondition: forgetNetworkBtn.hovered
                                    text: "Forget this network"
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
                                    enabled: false  // Make it visual-only
                                }
                                
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        const isActive = networkItem.modelData?.active || false;
                                        const isSecure = networkItem.modelData?.isSecure || false;
                                        const isKnown = networkItem.modelData?.isKnown || false;
                                        
                                        if (isActive) {
                                            // Currently connected - disconnect
                                            Network.disconnectFromNetwork();
                                        } else {
                                            // Not connected - try to connect
                                            if (!isSecure) {
                                                // Open network - connect directly
                                                Network.connectToNetwork(networkItem.modelData.ssid, "");
                                            } else {
                                                // Secure network - expand for password input
                                                networkItem.expanded = true;
                                            }
                                        }
                                    }
                                }
                                
                                StyledToolTip {
                                    text: {
                                        if (networkItem.modelData?.active) {
                                            return "Disconnect from network";
                                        } else if (networkItem.modelData?.isKnown) {
                                            return "Connect to network";
                                        } else if (networkItem.modelData?.isSecure) {
                                            return "Click to enter password";
                                        } else {
                                            return "Click to connect to open network";
                                        }
                                    }
                                    visible: parent.containsMouse || false
                                }
                            } // Close Item container
                        }

                        Rectangle {
                            id: dropDownBox
                            Layout.fillWidth: true
                            height: networkItem.expanded ? dropDownContent.implicitHeight + 16 : 0
                            color: "transparent"
                            opacity: networkItem.expanded ? 1 : 0
                            visible: height > 0

                            Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
                            Behavior on opacity { NumberAnimation { duration: 150 } }

                            ColumnLayout {
                                id: dropDownContent
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 4
                                StyledText { text: "BSSID: " + networkItem.modelData.bssid }
                                StyledText { text: "Frequence: " + networkItem.modelData.frequency }
                                StyledText { text: "Security: " + networkItem.modelData.security }



                                StyledText { 
                                    text: "Password:" 
                                    visible: networkItem.modelData?.isSecure || false
                                }
                                Rectangle {
                                    id: inputWrapper
                                    visible: networkItem.modelData?.isSecure || false
                                    Layout.fillWidth: true
                                    radius: Appearance.rounding.small
                                    color: Appearance.colors.colLayer1
                                    height: passwdInput.height
                                    clip: true
                                    border.color: Appearance.colors.colOutlineVariant
                                    border.width: 1

                                    RowLayout { // Input field and show button
                                        id: inputFieldRowLayout
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.topMargin: 5
                                        spacing: 0

                                        StyledTextInput {
                                            id: passwdInput
                                            Layout.fillWidth: true
                                            padding: 10
                                            //placeholderText: "Password"
                                            color: Appearance.colors.colOnLayer1
                                            echoMode: showButton.toggled ? TextInput.Normal : TextInput.Password
                                            passwordCharacter: "●"
                                            passwordMaskDelay: 0
                                            verticalAlignment: TextInput.AlignVCenter

                                            Text {
                                                text: "Enter password..."
                                                color: Appearance.m3colors.m3outline
                                                font.pixelSize: Appearance?.font.pixelSize.small
                                                visible: !passwdInput.text && !passwdInput.activeFocus
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.left: parent.left
                                                anchors.leftMargin: 10
                                            }

                                            Keys.onPressed: function (event) {
                                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                                    Network.connectToNetwork(networkItem.modelData.ssid, passwdInput.text);
                                                    networkItem.expanded = false
                                                }
                                            }
                                        }

                                        RippleButton { // Show button
                                            id: showButton
                                            Layout.alignment: Qt.AlignTop
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
                                                onClicked: {
                                                    showButton.toggled = !showButton.toggled
                                                }
                                            }

                                            contentItem: MaterialSymbol {
                                                anchors.centerIn: parent
                                                horizontalAlignment: Text.AlignHCenter
                                                iconSize: Appearance.font.pixelSize.larger
                                                color: showButton.toggled ? Appearance.colors.colOnLayer2 : Appearance.colors.colOnLayer2Disabled
                                                text: showButton.toggled ? "visibility" : "visibility_off"
                                            }
                                        }

                                        RippleButton { // Connect button
                                            id: sendButton
                                            Layout.alignment: Qt.AlignTop
                                            Layout.rightMargin: 5
                                            implicitHeight: 40
                                            buttonRadius: Appearance.rounding.small
                                            enabled: passwdInput.text.length != 0

                                            colBackground: "transparent"
                                            colBackgroundHover: "transparent"
                                            colBackgroundToggled: "transparent"
                                            colBackgroundToggledHover: "transparent"

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: sendButton.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                onClicked: {
                                                    Network.connectToNetwork(networkItem.modelData.ssid, passwdInput.text);
                                                    networkItem.expanded = false
                                                }
                                            }

                                            contentItem: MaterialSymbol {
                                                anchors.centerIn: parent
                                                horizontalAlignment: Text.AlignHCenter
                                                iconSize: Appearance.font.pixelSize.larger
                                                color: sendButton.enabled ? Appearance.colors.colOnLayer2 : Appearance.colors.colOnLayer2Disabled
                                                text: "lock_open_right"
                                            }
                                        }

                                        RippleButton { // Forget button (for all networks)
                                            id: forgetButton
                                            Layout.alignment: Qt.AlignTop
                                            Layout.rightMargin: 5
                                            implicitHeight: 40
                                            buttonRadius: Appearance.rounding.small
                                            visible: true

                                            colBackground: "transparent"
                                            colBackgroundHover: "transparent"
                                            colBackgroundToggled: "transparent"
                                            colBackgroundToggledHover: "transparent"

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    Network.forgetNetwork(networkItem.modelData.ssid);
                                                    networkItem.expanded = false;
                                                }
                                            }

                                            contentItem: MaterialSymbol {
                                                anchors.centerIn: parent
                                                horizontalAlignment: Text.AlignHCenter
                                                iconSize: Appearance.font.pixelSize.larger
                                                color: Appearance.m3colors.m3error
                                                text: "delete"
                                            }

                                            StyledToolTip {
                                                text: "Forget this network"
                                                visible: forgetButton.hovered
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
