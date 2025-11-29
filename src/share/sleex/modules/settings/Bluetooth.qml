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
    forceWidth: true

    function getDeviceIcon(modelData) {
        const icon = modelData?.icon ?? "";

        switch (true) {
            case icon.includes("headset"):
                return "headphones";
            case icon.includes("earbuds"):
                return "earbuds_2";
            case icon.includes("speaker"):
                return "speaker";
            case icon.includes("keyboard"):
                return "keyboard_alt";
            case icon.includes("mouse"):
                return "mouse";
            default:
                return "bluetooth_connected";
        }
    }

    Timer {
        id: refreshTimer
        interval: 8000
        onTriggered: BluetoothService.refreshPairedDevices()
    }

    function unpairDevice(address) {
        BluetoothService.unpairDevice(address);
        refreshTimer.start();
    }

    function connectDevice(device) {
        if (device.paired) {
            BluetoothService.connectDevice(device.address);
        } else {
            BluetoothService.pairDevice(device.address);
        }
    }

    function disconnectDevice(address) {
        BluetoothService.disconnectDevice(address);
    }


    ContentSection {
        title: "Bluetooth settings"
        visible: Bluetooth.adapters.values.length > 0

        RowLayout {
            spacing: 10
            uniformCellSizes: true

            ConfigSwitch {
                text: "Enabled"
                checked: BluetoothService.bluetoothEnabled
                onClicked: checked = !checked;
                onCheckedChanged: {
                    BluetoothService.bluetoothEnabled = checked;
                }
            }

            ConfigSwitch {
                text: "Discoverable"
                checked: Bluetooth.defaultAdapter?.discoverable ?? false
                onClicked: checked = !checked;
                onCheckedChanged: {
                    if (Bluetooth.defaultAdapter)
                        Bluetooth.defaultAdapter.discoverable = checked;
                }
            }
        }
    }

    RowLayout {
        spacing: 10

        StyledText {
            text: {
                const devices = BluetoothService.devices;
                let available = qsTr("%1 device%2 available").arg(devices.length).arg(devices.length === 1 ? "" : "s");
                const connected = devices.filter(d => d.connected).length;
                if (connected > 0)
                    available += qsTr(" (%1 connected)").arg(connected);
                return available;
            }
            color: Appearance.colors.colOnLayer0
            font.pixelSize: Appearance.font.pixelSize.huge
        }

        RowLayout {
            spacing: 10
            
            RippleButton {
                id: discoverBtn

                visible: Bluetooth.adapters.values.length > 0

                contentItem: Rectangle {
                    id: discoverBtnBody
                    radius: Appearance.rounding.full
                    color: BluetoothService.discovering ? Appearance.m3colors.m3primary : Appearance.colors.colLayer2
                    implicitWidth: height

                    MaterialSymbol {
                        id: scanIcon

                        anchors.centerIn: parent
                        text: "bluetooth_searching"
                        color: BluetoothService.discovering ? Appearance.m3colors.m3onSecondary : Appearance.m3colors.m3onSecondaryContainer
                        fill: BluetoothService.discovering ? 1 : 0
                    }
                }

                MouseArea {
                    id: discoverArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        BluetoothService.discovering = !BluetoothService.discovering;
                    }

                    StyledToolTip {
                        extraVisibleCondition: discoverArea.containsMouse
                        text: "Discover new devices"
                    }
                }
            }

            RippleButton {
                id: refreshBtn
                visible: Bluetooth.adapters.values.length > 0
                width: 40
                height: 40

                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "refresh"
                    color: Appearance.colors.colOnLayer2
                }

                MouseArea {
                    id: refreshArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        BluetoothService.refreshPairedDevices();
                        refreshTimer.restart();
                    }

                    StyledToolTip {
                        extraVisibleCondition: refreshArea.containsMouse
                        text: "Refresh device list"
                    }
                }
            }
        }
    }

    ContentSection {


        Text {
            text: "No bluetooth adapter found"
            color: Appearance.colors.colOnLayer1
            font.pixelSize: 30
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            visible: !Bluetooth.adapters.values.length > 0
        }

        StyledTextArea {
            id: deviceSearch
            Layout.fillWidth: true
            placeholderText: "Search devices"
            visible: Bluetooth.adapters.values.length > 0
        }

        Repeater {
            model: ScriptModel {
                values: {
                    // Only show devices if Bluetooth is enabled
                    if (!BluetoothService.bluetoothEnabled) {
                        return [];
                    }
                    let devices = [...BluetoothService.devices].sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired));
                    
                    if (deviceSearch.text.trim() !== "") {
                        devices = devices.filter(d => d.name.toLowerCase().includes(deviceSearch.text.toLowerCase()) || d.address.toLowerCase().includes(deviceSearch.text.toLowerCase()));
                    }
                    return devices;
                }
            }

            RowLayout {
                id: device

                required property var modelData
                readonly property bool loading: false // Placeholder if needed

                Layout.fillWidth: true
                spacing: 10

                RippleButton {
                    id: deviceCard
                    Layout.fillWidth: true
                    implicitHeight: contentItem.implicitHeight + 8 * 2

                    contentItem: RowLayout {
                        spacing: 10

                        Rectangle {
                            width: cardTexts.height
                            height: cardTexts.height
                            radius: 8
                            color: Appearance.colors.colSecondaryContainer
                            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: device.modelData.icon
                                font.pixelSize: Appearance.font.pixelSize.title
                                color: Appearance.colors.colOnSecondaryContainer
                            }
                        }

                        ColumnLayout {
                            id: cardTexts

                            StyledText {
                                Layout.fillWidth: true
                                text: device.modelData.name
                                font.pixelSize: Appearance.font.pixelSize.huge
                                color: Appearance.colors.colOnSecondaryContainer
                            }
                            StyledText {
                                text: device.modelData.address + (device.modelData.connected ? qsTr(" (Connected)") : (device.modelData.paired ? qsTr(" (Paired)") : qsTr(" (Available)")))
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colSubtext
                            }
                        }

                        RippleButton {
                            id: forgetButton
                            visible: device.modelData.paired
                            
                            width: 40
                            height: 40
                            buttonRadius: Appearance.rounding.normal
                            colBackground: "transparent"
                            colBackgroundHover: Appearance.colors.colSurfaceContainerHigh
                            hoverEnabled: true
                            
                            property bool processing: false
                            
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                text: forgetButton.processing ? "hourglass_empty" : "link_off"
                                font.pixelSize: Appearance.font.pixelSize.normal
                                color: forgetButton.hovered ? Appearance.colors.colOnSurface : Appearance.colors.colOnSurfaceVariant
                            }
                            
                            onClicked: {
                                if (forgetButton.processing) return;
                                
                                forgetButton.processing = true;
                                unpairDevice(device.modelData.address);
                                
                                // Reset processing state after a delay
                                Qt.callLater(() => {
                                    processingTimer.start();
                                });
                            }
                            
                            Timer {
                                id: processingTimer
                                interval: 5000
                                onTriggered: forgetButton.processing = false
                            }
                            
                            StyledToolTip {
                                extraVisibleCondition: forgetButton.hovered
                                text: forgetButton.processing ? "Removing device..." : "Forget device"
                            }
                        }

                        StyledSwitch {
                            scale: 0.80
                            Layout.fillWidth: false
                            checked: device.modelData.connected
                            onClicked: {
                                if (checked) {
                                    connectDevice(device.modelData);
                                } else {
                                    disconnectDevice(device.modelData.address);
                                }
                                // Restore binding to ensure switch reflects actual state
                                checked = Qt.binding(function() { return device.modelData.connected; });
                            }
                        }
                    }
                }
            }
        }
    }
}
