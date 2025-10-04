#include "bluetooth.hpp"

Bluetooth::Bluetooth(QObject *parent)
    : QObject(parent)
{
    // Check for Bluetooth adapters
    const auto adapters = QBluetoothLocalDevice::allDevices();
    if (!adapters.isEmpty()) {
        m_localDevice = new QBluetoothLocalDevice(adapters.first().address(), this);
        m_available = true;

        connect(m_localDevice, &QBluetoothLocalDevice::hostModeStateChanged, this, [this](QBluetoothLocalDevice::HostMode mode) {
            bool enabled = (mode != QBluetoothLocalDevice::HostPoweredOff);
            if (m_enabled != enabled) {
                m_enabled = enabled;
                emit bluetoothEnabledChanged();
            }
        });
    } else {
        // No adapters at all
        m_available = false;
    }
}

void Bluetooth::update()
{
    if (!m_available || !m_localDevice) {
        // Reset state if no adapter
        if (m_enabled) { m_enabled = false; emit bluetoothEnabledChanged(); }
        if (m_connected) { m_connected = false; emit bluetoothConnectedChanged(); }
        if (!m_deviceName.isEmpty()) { m_deviceName.clear(); emit bluetoothDeviceNameChanged(); }
        if (!m_deviceAddress.isEmpty()) { m_deviceAddress.clear(); emit bluetoothDeviceAddressChanged(); }
        return;
    }

    // Update enabled state
    bool enabled = (m_localDevice->hostMode() != QBluetoothLocalDevice::HostPoweredOff);
    if (m_enabled != enabled) {
        m_enabled = enabled;
        emit bluetoothEnabledChanged();
    }

    // If enabled, fetch connected device info (stubbed here, needs device discovery logic)
    // For now, just reset connected state
    if (!m_connected) {
        m_connected = false;
        emit bluetoothConnectedChanged();
    }
}
