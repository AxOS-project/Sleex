import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: resourcePopup
    readonly property real margin: 10
    implicitWidth: columnLayout.implicitWidth + margin * 2
    implicitHeight: columnLayout.implicitHeight + margin * 2
    color: Appearance.m3colors.m3background
    radius: Appearance.rounding.small
    border.width: 1
    border.color: Appearance.colors.colLayer0
    clip: true

    property BluetoothDevice device: Bluetooth.devices.values.find(d => d.connected) ?? null

    ColumnLayout {
        id: columnLayout
        anchors.centerIn: parent
        spacing: 6

        RowLayout {
            spacing: 5

            MaterialSymbol {
                fill: 1
                text: "bluetooth"
                iconSize: Appearance.font.pixelSize.larger
            }

            StyledText {
                color: Appearance.colors.colOnLayer1
                text: device.name
            }
        }
        RowLayout {
            spacing: 5

            MaterialSymbol {
                fill: 1
                text: "battery_android_full"
            }

            StyledText {
                color: Appearance.colors.colOnLayer1
                text: `${Math.round(device.battery * 100 ?? 0)}% remaining`
            }
        }
    }
}