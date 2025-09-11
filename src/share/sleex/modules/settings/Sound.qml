pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import "./volumeMixer"

ContentPage {
    id: root
    property bool showDeviceSelector: false
    property bool deviceSelectorInput
    property int dialogMargins: 16
    property PwNode selectedDevice
    readonly property list<PwNode> appPwNodes: Pipewire.nodes.values.filter((node) => {
        // return node.type == "21" // Alternative, not as clean
        return node.isSink && node.isStream
    })

    function showDeviceSelectorDialog(input: bool) {
        root.selectedDevice = null
        root.showDeviceSelector = true
        root.deviceSelectorInput = input
    }

    Keys.onPressed: (event) => {
            // Close dialog on pressing Esc if open
            if (event.key === Qt.Key_Escape && root.showDeviceSelector) {
                root.showDeviceSelector = false
                event.accepted = true;
            }
        }


    forceWidth: true

    ContentSection {
        title: "Protection"

        ConfigSwitch {
            text: "Earbang protection"
            checked: Config.options.audio.protection.enable
            onClicked: checked = !checked;
            onCheckedChanged: {
                Config.options.audio.protection.enable = checked;
            }
            StyledToolTip {
                content: "Prevents abrupt increments and restricts volume limit"
            }
        }
        ConfigSpinBox {
            id: earbangLimitSpinBox
            text: "Earbang limit"
            value: Config.options.audio.protection.maxAllowed
            from: 0
            to: 100
            stepSize: 1
            onValueChanged: {
                Config.options.audio.protection.maxAllowed = value;
            }
            StyledToolTip {
                content: "Maximum volume level allowed by earbang protection"
            }
        }
    }

    ContentSection {
        title: "Devices"

        AudioDeviceSelectorButton {
            input: false
        }
        AudioDeviceSelectorButton {
            input: true
        }
    }

    ContentSection {
        title: "Volume mixer"

        Rectangle {
            Layout.fillWidth: true
            height: warnChildren.height + 40
            color: "#40FF9800"
            radius: 6

            RowLayout {
                id: warnChildren
                anchors.fill: parent
                anchors.margins: 10

                Label {
                    text: "🚧"
                    font.pixelSize: 16 // Slightly smaller icon
                    Layout.alignment: Qt.AlignVCenter
                    rightPadding: 6
                }

                Label {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: "<b>WORK IN PROGRESS:</b> This module is incomplete. Use at your own risk.</code>"
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    textFormat: Text.RichText
                    color: "white"
                }
            }
        }

        VolumeMixer {
            id: volumeMixer
            implicitHeight: 200
            Layout.fillWidth: true
        }
    }

    ContentSection {
        title: "System sounds"

        ConfigSwitch {
            visible: UPower.displayDevice.isLaptopBattery
            text: "Enable battery notification sounds"
            checked: Config.options.battery.sound
            onClicked: checked = !checked;
            onCheckedChanged: {
                Config.options.battery.sound = checked;
            }
        }
    }
}
