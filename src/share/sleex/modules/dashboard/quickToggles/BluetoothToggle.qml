import "../"
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Hyprland

import Sleex.Services

QuickToggleButton {
    toggled: Bluetooth.defaultAdapter.enabled
    buttonIcon: BluetoothService.bluetoothConnected ? "bluetooth_connected" : Bluetooth.defaultAdapter.enabled ? "bluetooth" : "bluetooth_disabled"
    onClicked: {
        Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled
    }
    altAction: () => {
        Quickshell.execDetached(["bash", "-c", `${Config.options.apps.bluetooth}`])
        GlobalStates.dashboardOpen = false
    }
    Process {
        id: toggleBluetooth
        command: ["bash", "-c", `bluetoothctl power ${Bluetooth.defaultAdapter.enabled ? "off" : "on"}`]
        onRunningChanged: {
            if(!running) {
                BluetoothService.update()
            }
        }
    }
    StyledToolTip {
        text: StringUtils.format(qsTr("{0} | Right-click to configure"),
            (Bluetooth.defaultAdapter.enabled && BluetoothService.bluetoothDeviceName.length > 0) ?
            BluetoothService.bluetoothDeviceName : qsTr("Bluetooth"))

    }
}
