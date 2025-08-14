import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth

Item {
    id: root

    implicitHeight: indicatorsRowLayout.height
    implicitWidth: indicatorsRowLayout.width

    property bool bluetoothEnabled: Bluetooth.defaultAdapter?.enabled ?? false
    property bool bluetoothConnected: Bluetooth.devices.values.filter(d => d.state !== BluetoothDeviceState.Disconnected).length > 0
    property BluetoothDevice device: Bluetooth.devices.values.find(d => d.connected)

    property string deviceType: {
        const icon = device?.icon ?? "";

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

    RowLayout {
        id: indicatorsRowLayout

        MaterialSymbol {
            Layout.rightMargin: bluetoothConnected ? 4 : indicatorsRowLayout.realSpacing
            text: bluetoothConnected ? deviceType : bluetoothEnabled ? "bluetooth" : "bluetooth_disabled"
            iconSize: Appearance.font.pixelSize.larger
            color: rightSidebarButton.colText
        }
        
        // Repeater {
        //     model: Bluetooth.devices.values.filter(d => d.state !== BluetoothDeviceState.Disconnected)
        //     delegate: StyledText {
        //         text: `${modelData.battery * 100}%`
        //         visible: modelData.state !== BluetoothDeviceState.Disconnected
        //         Layout.rightMargin: indicatorsRowLayout.realSpacing
        //     }
        // }

        StyledText {
            // Round the battery percentage to avoid decimal points
            text: `${Math.round(device?.battery * 100 ?? 0)}%`
            visible: device?.batteryAvailable ?? false
        }

    }
}
