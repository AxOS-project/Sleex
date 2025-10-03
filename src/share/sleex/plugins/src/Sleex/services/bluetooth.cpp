#include "bluetooth.hpp"

Bluetooth::Bluetooth(QObject *parent)
    : QObject(parent), m_discoveryAgent(this)
{
    connect(&m_localDevice, &QBluetoothLocalDevice::hostModeStateChanged,
            this, &Bluetooth::updateHostMode);

    connect(&m_discoveryAgent, &QBluetoothDeviceDiscoveryAgent::deviceDiscovered,
            this, &Bluetooth::onDeviceDiscovered);

    // Initial state
    updateHostMode(m_localDevice.hostMode());
}

void Bluetooth::updateHostMode(QBluetoothLocalDevice::HostMode mode) {
    bool enabled = (mode != QBluetoothLocalDevice::HostPoweredOff);
    if (m_enabled != enabled) {
        m_enabled = enabled;
        emit bluetoothEnabledChanged();
    }
}

void Bluetooth::startScan() {
    m_discoveryAgent.start();
}

void Bluetooth::onDeviceDiscovered(const QBluetoothDeviceInfo &info) {
    if (info.isValid()) {
        m_deviceName = info.name();
        m_deviceAddress = info.address().toString();
        m_connected = true;

        emit bluetoothDeviceChanged();
        emit bluetoothConnectedChanged();

        m_discoveryAgent.stop(); // stop after first found
    }
}
