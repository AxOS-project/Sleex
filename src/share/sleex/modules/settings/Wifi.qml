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
        
        function onPasswordRequired(ssid) {
            // Security type changed - expand the network for password input
            for (let i = 0; i < networkRepeater.count; i++) {
                let item = networkRepeater.itemAt(i);
                if (item && item.modelData && item.modelData.ssid === ssid) {
                    item.expanded = true;
                    break;
                }
            }
            
            // Also refresh the network list
            root.refreshTrigger++;
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

        StyledTextArea {
            id: networkSearch
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
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
                property bool expandedForPassword: false  // Track when we expand for password input
                
                onExpandedChanged: {
                    console.log("DEBUG: expanded property changed to:", expanded, "for network:", modelData.ssid);
                }

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

                                // Connection error display for this network
                                StyledText {
                                    Layout.fillWidth: true
                                    text: "Failed to connect: " + root.lastConnectionError
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.m3colors.m3error
                                    wrapMode: Text.WordWrap
                                    visible: root.showConnectionError && root.errorSsid === networkItem.modelData.ssid
                                }
                            }

                            RippleButtonWithIcon {
                                visible: networkItem.modelData?.isSecure || false
                                materialIcon: networkItem.expanded ? "keyboard_arrow_up" : "keyboard_arrow_down"
                                mainText: ""
                                enabled: !Network.hasConnectionFailed(networkItem.modelData.ssid)
                                onClicked: {
                                    console.log("DEBUG: RippleButtonWithIcon clicked for", networkItem.modelData.ssid, "- current expanded:", networkItem.expanded);
                                    networkItem.expanded = !networkItem.expanded;
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
                                    onClicked: function(mouse) {
                                        console.log("DEBUG: MouseArea onClicked - START for", networkItem.modelData.ssid);
                                        mouse.accepted = true;  // Prevent event propagation
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
                                            } else if (isKnown) {
                                                // Known secure network - if previous attempt failed, prompt for password
                                                // otherwise try stored credentials
                                                const hasFailed = Network.hasConnectionFailed(networkItem.modelData.ssid);
                                                console.log("DEBUG: Network", networkItem.modelData.ssid, "isKnown:", isKnown, "hasFailed:", hasFailed);
                                                if (hasFailed) {
                                                    console.log("DEBUG: Showing password input for failed network:", networkItem.modelData.ssid);
                                                    // Show password input so user can re-enter credentials
                                                    console.log("DEBUG: Setting expanded to true for", networkItem.modelData.ssid, "current expanded:", networkItem.expanded);
                                                    // Use Qt.callLater to ensure expansion happens after any conflicting handlers
                                                    Qt.callLater(function() {
                                                        console.log("DEBUG: Inside callLater - about to set expanded to true");
                                                        networkItem.expandedForPassword = true;
                                                        networkItem.expanded = true;
                                                        console.log("DEBUG: After callLater - expanded is now:", networkItem.expanded);
                                                        
                                                        // Add a small delay to check if something changes it back
                                                        Qt.callLater(function() {
                                                            console.log("DEBUG: Double check - expanded is still:", networkItem.expanded);
                                                        });
                                                    });
                                                } else {
                                                    console.log("DEBUG: Auto-connecting to known network:", networkItem.modelData.ssid);
                                                    // Backend will handle security mismatches automatically
                                                    Network.connectToNetwork(networkItem.modelData.ssid, "");
                                                }
                                            } else {
                                                // Unknown secure network - expand for password input
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
                                            return "Connect to known network";
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
                                    visible: networkItem.modelData.ssid === "NothingPhone(2a)" || ((networkItem.modelData?.isSecure || false) && (!(networkItem.modelData?.isKnown || false) || Network.hasConnectionFailed(networkItem.modelData.ssid)))
                                    
                                    Component.onCompleted: {
                                        console.log("DEBUG: Password label for", networkItem.modelData.ssid, "- isSecure:", networkItem.modelData?.isSecure, "isKnown:", networkItem.modelData?.isKnown, "hasConnectionFailed:", Network.hasConnectionFailed(networkItem.modelData.ssid), "visible:", visible);
                                    }
                                }
                                Rectangle {
                                    id: inputWrapper
                                    visible: networkItem.modelData.ssid === "NothingPhone(2a)" || ((networkItem.modelData?.isSecure || false) && (!(networkItem.modelData?.isKnown || false) || Network.hasConnectionFailed(networkItem.modelData.ssid)))
                                    Layout.fillWidth: true
                                    
                                    Component.onCompleted: {
                                        console.log("DEBUG: Input wrapper for", networkItem.modelData.ssid, "- visible:", visible);
                                        console.log("DEBUG: Input wrapper - isSecure:", networkItem.modelData?.isSecure);
                                        console.log("DEBUG: Input wrapper - isKnown:", networkItem.modelData?.isKnown);
                                        console.log("DEBUG: Input wrapper - hasConnectionFailed:", Network.hasConnectionFailed(networkItem.modelData.ssid));
                                    }
                                    
                                    onVisibleChanged: {
                                        console.log("DEBUG: Input wrapper visibility changed to:", visible, "for", networkItem.modelData.ssid);
                                    }
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



                                    }
                                }

                                // Forget button for known networks, separated at bottom
                                RippleButtonWithIcon {
                                    Layout.fillWidth: true
                                    Layout.topMargin: 8
                                    materialIcon: "delete"
                                    mainText: "Forget Network"
                                    visible: networkItem.modelData?.isKnown || false
                                    onClicked: {
                                        Network.forgetNetwork(networkItem.modelData.ssid);
                                        networkItem.expanded = false;
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
