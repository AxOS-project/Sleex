import "../"
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

import Sleex.Services

QuickToggleButton {
    toggled: BluetoothService.bluetoothEnabled
    buttonIcon: BluetoothService.bluetoothConnected ? "bluetooth_connected" : BluetoothService.bluetoothEnabled ? "bluetooth" : "bluetooth_disabled"
    onClicked: {
        toggleBluetooth.running = true
    }
    altAction: () => {
        Quickshell.execDetached(["bash", "-c", `${Config.options.apps.bluetooth}`])
        GlobalStates.dashboardOpen = false
    }
    Process {
        id: toggleBluetooth
        command: ["bash", "-c", `bluetoothctl power ${BluetoothService.bluetoothEnabled ? "off" : "on"}`]
        onRunningChanged: {
            if(!running) {
                Bluetooth.update()
            }
        }
    }
    StyledToolTip {
        content: StringUtils.format(qsTr("{0} | Right-click to configure"),
            (BluetoothService.bluetoothEnabled && BluetoothService.bluetoothDeviceName.length > 0) ?
            BluetoothService.bluetoothDeviceName : qsTr("Bluetooth"))

    }
}
