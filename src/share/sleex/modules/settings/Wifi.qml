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

    property string connectingToSsid: ""

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
                checked: Network.wifiEnabled
                onCheckedChanged: {
                    Network.enableWifi(checked)
                }
                StyledToolTip {
                    text: "Doesn't works idk why"
                }
            }
        }
    }

    RowLayout {
        spacing: 10

        StyledText {
            text: qsTr("%1 networks available").arg(Network.networks.length)
            color: Appearance.colors.colOnLayer0
            font.pixelSize: Appearance.font.pixelSize.huge
        }
    }

    ContentSection {

        Text {
            text: "Wifi diabled"
            color: Appearance.colors.colOnLayer1
            font.pixelSize: 30
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            visible: !Network.wifiEnabled
        }

        StyledTextArea {
            id: networkSearch
            Layout.fillWidth: true
            placeholderText: "Search networks"
            visible: Network.wifiEnabled
        }


        Repeater {
            model: ScriptModel {
                // values: [...Network.networks].sort((a, b) => {
                //     if (a.active !== b.active)
                //         return b.active - a.active;
                //     return b.strength - a.strength;
                // }).slice(0, 8)

                values: {
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
                readonly property bool isConnecting: root.connectingToSsid === modelData.ssid
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
                                    visible: networkItem.modelData.isSecure
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
                            }

                            MaterialSymbol {
                                visible: networkItem.modelData.isSecure
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

                            StyledSwitch {
                                id: toggleSwitch
                                scale: 0.80
                                Layout.fillWidth: false
                                checked: networkItem.modelData.active
                                enabled: networkItem.modelData.isKnown
                                onClicked: {
                                    if (!checked) {
                                        Network.disconnectFromNetwork();
                                    } else {
                                        root.connectingToSsid = networkItem.modelData.ssid;
                                        Network.connectToNetwork(networkItem.modelData.ssid, "");
                                        networkItem.expanded = false
                                    }
                                }
                                MouseArea {
                                    id: toggleSwitchArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                }
                                StyledToolTip {
                                    text: "Unlock first. Expand to enter password."
                                    visible: !networkItem.modelData.isKnown
                                    extraVisibleCondition: toggleSwitchArea.containsMouse
                                }
                            }
                        }

                        Rectangle {
                            id: dropDownBox
                            Layout.fillWidth: true
                            height: networkItem.expanded ? 140 : 0
                            color: "transparent"
                            opacity: networkItem.expanded ? 1 : 0
                            visible: height > 0

                            Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
                            Behavior on opacity { NumberAnimation { duration: 150 } }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 4
                                StyledText { text: "BSSID: " + networkItem.modelData.bssid }
                                StyledText { text: "Frequence: " + networkItem.modelData.frequency }
                                StyledText { text: "Security: " + networkItem.modelData.security }

                                RowLayout {
                                    id: actions
                                    visible: networkItem.modelData.isKnown

                                    RippleButton {
                                        id: forgetBtn

                                        colBackgroundHover: "transparent"
                                        
                                        contentItem: Rectangle {
                                            id: forgetBtnBody
                                            radius: Appearance.rounding.full
                                            color: Appearance.colors.colLayer0
                                            height: 5

                                            MaterialSymbol {
                                                id: forgetIcon

                                                anchors.centerIn: parent
                                                text: "delete"
                                                color: Appearance.colors.colOnLayer0
                                            }

                                        }

                                        MouseArea {
                                            id: forgetArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: Network.forgetNetwork(networkItem.modelData.ssid);

                                            StyledToolTip {
                                                extraVisibleCondition: forgetArea.containsMouse
                                                text: "Forget network"
                                            }
                                        }
                                    }
                                }

                                StyledText { 
                                    text: "Password:" 
                                    visible: !networkItem.modelData.isKnown
                                }
                                Rectangle {
                                    id: inputWrapper
                                    visible: !networkItem.modelData.isKnown
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
