import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import Quickshell

Item {
    id: root

    implicitHeight: indicatorsRowLayout.height
    implicitWidth: indicatorsRowLayout.width

    property bool bluetoothEnabled: Bluetooth.defaultAdapter?.enabled ?? false
    property bool bluetoothConnected: Bluetooth.devices.values.filter(d => d.state !== BluetoothDeviceState.Disconnected).length > 0
    property BluetoothDevice device: Bluetooth.devices.values.find(d => d.connected) ?? null

    property string deviceType: {
        const icon = device?.icon ?? "";

        switch (true) {
            case icon.includes("headset"):
                return "headphones";
            case icon.includes("headphones"):
                return "headphones";
            case icon.includes("earbuds"):
                return "earbuds_2";
            case icon.includes("speaker"):
                return "speaker";
            case icon.includes("keyboard"):
                return "keyboard_alt";
            case icon.includes("mouse"):
                return "mouse";
            case icon.includes("phone"):
                return "smartphone";
            case icon.includes("audio-card"):
                return "speaker"; // Closest material icon for audio-card
            case icon.includes("camera-photo"):
                return "camera";
            case icon.includes("camera-video"):
                return "camera";
            case icon.includes("computer"):
                return "computer";
            case icon.includes("input-gaming"):
                return "gamepad";
            case icon.includes("input-tablet"):
                return "tablet";
            case icon.includes("modem"):
                return "router"; // Closest for modem
            case icon.includes("multimedia-player"):
                return "play_circle";
            case icon.includes("network-wireless"):
                return "network_wifi";
            case icon.includes("printer"):
                return "print";
            case icon.includes("scanner"):
                return "document_scanner";
            case icon.includes("video-display"):
                return "monitor";
            default:
                return "bluetooth_connected"; // For unknown or other bluetooth devices
        }
    }

    RowLayout {
        id: indicatorsRowLayout

        ClippedFilledCircularProgress {
            id: circProg
            value: device?.battery
            icon: bluetoothConnected ? deviceType : bluetoothEnabled ? "bluetooth" : "bluetooth_disabled"
            colPrimary: (device?.battery * 100) <= 20 ? Appearance.m3colors.m3error : Appearance.colors.colOnLayer1
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: indicatorsRowLayout
        hoverEnabled: true
    }

    LazyLoader {
        id: popupLoader
        active: mouseArea.containsMouse

        component: PanelWindow {
            id: popupWindow
            visible: true
            color: "transparent"
            exclusiveZone: 0

            anchors.top: true
            anchors.left: true

            implicitWidth: btPopup.implicitWidth
            implicitHeight: btPopup.implicitHeight

            margins {
                left: root.mapToGlobal(Qt.point(
                    (root.width - btPopup.implicitWidth) / 2,
                    0
                )).x
                top: root.mapToGlobal(Qt.point(0, root.height)).y - 30 
            }

            mask: Region {
                item: btPopup
            }

            BtPopup {
                id: btPopup
                anchors.centerIn: parent
            }
        }
    }
}