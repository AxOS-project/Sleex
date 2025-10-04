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


    ContentSection {
        title: "Bluetooth settings"
        visible: Bluetooth.adapters.values.length > 0

        RowLayout {
            spacing: 10
            uniformCellSizes: true

            ConfigSwitch {
                text: "Enabled"
                checked: Config.options.bar.showTitle
                onClicked: checked = !checked;
                onCheckedChanged: {
                    if (Bluetooth.defaultAdapter)
                        Bluetooth.defaultAdapter.enabled = checked;
                }
            }

            ConfigSwitch {
                text: "Discoverable"
                checked: Bluetooth.defaultAdapter.discoverable
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
                const devices = Bluetooth.devices.values;
                let available = qsTr("%1 device%2 available").arg(devices.length).arg(devices.length === 1 ? "" : "s");
                const connected = devices.filter(d => d.connected).length;
                if (connected > 0)
                    available += qsTr(" (%1 connected)").arg(connected);
                return available;
            }
            color: Appearance.colors.colOnLayer0
            font.pixelSize: Appearance.font.pixelSize.huge
        }

        RippleButton {
            id: discoverBtn

            visible: Bluetooth.adapters.values.length > 0

            contentItem: Rectangle {
                id: discoverBtnBody
                radius: Appearance.rounding.full
                color: Bluetooth.defaultAdapter?.discovering ? Appearance.m3colors.m3primary : Appearance.colors.colLayer2
                implicitWidth: height

                MaterialSymbol {
                    id: scanIcon

                    anchors.centerIn: parent
                    text: "bluetooth_searching"
                    color: Bluetooth.defaultAdapter?.discovering ? Appearance.m3colors.m3onSecondary : Appearance.m3colors.m3onSecondaryContainer
                    fill: Bluetooth.defaultAdapter?.discovering ? 1 : 0
                }
            }

            MouseArea {
                id: discoverArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: Bluetooth.defaultAdapter.discovering = !Bluetooth.defaultAdapter.discovering

                StyledToolTip {
                    extraVisibleCondition: discoverArea.containsMouse
                    content: "Discover new devices"
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

        Repeater {
            model: ScriptModel {
                values: [...Bluetooth.devices.values].sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired))
            }

            RowLayout {
                id: device

                required property BluetoothDevice modelData
                readonly property bool loading: modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting

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
                                text: getDeviceIcon(device.modelData)
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
                                text: device.modelData.address + (device.modelData.connected ? qsTr(" (Connected)") : device.modelData.bonded ? qsTr(" (Paired)") : "")
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colSubtext
                            }
                        }

                        StyledSwitch {
                            scale: 0.80
                            Layout.fillWidth: false
                            checked: device.modelData.connected
                            onClicked: device.modelData.connected = !device.modelData.connected
                        }
                    }
                }


                Loader {
                    asynchronous: true
                    active: device.modelData.bonded
                    sourceComponent: Item {
                        implicitWidth: connectBtn.implicitWidth
                        implicitHeight: connectBtn.implicitHeight

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "delete"
                        }
                    }
                }
            }
        }
    }
}
