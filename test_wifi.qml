//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

import Quickshell
import QtQuick
import QtQuick.Controls
import Sleex.Services

ApplicationWindow {
    id: root
    visible: true
    width: 800
    height: 600
    title: "WiFi Debug Test"

    Network {
        id: network
    }

    ScrollView {
        anchors.fill: parent
        anchors.margins: 20

        Column {
            width: parent.width
            spacing: 10

            Text {
                text: "WiFi Networks Debug"
                font.pointSize: 16
                font.bold: true
            }

            Text {
                text: "Enabled: " + network.wirelessEnabled
                font.pointSize: 12
            }

            Text {
                text: "Connected SSID: " + network.connectedWifiSSID
                font.pointSize: 12
            }

            Repeater {
                model: network.wifiNetworks
                delegate: Rectangle {
                    width: parent.width
                    height: 60
                    border.color: "#ccc"
                    border.width: 1
                    radius: 5

                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: modelData.ssid
                            font.bold: true
                        }
                        Text {
                            text: "Security: " + modelData.securityType + " | Signal: " + modelData.signalStrength + "% | Connected: " + modelData.connected
                            font.pointSize: 10
                            color: "#666"
                        }
                        Text {
                            text: modelData.errorMessage ? "Error: " + modelData.errorMessage : ""
                            font.pointSize: 10
                            color: "red"
                            visible: modelData.errorMessage !== ""
                        }
                    }

                    Button {
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.connected ? "Disconnect" : "Connect"
                        
                        onClicked: {
                            if (modelData.connected) {
                                network.disconnectFromWifi(modelData.ssid)
                            } else {
                                // For testing wrong password scenarios
                                network.connectToWifi(modelData.ssid, "wrongpassword123")
                            }
                        }
                    }
                }
            }
        }
    }
}