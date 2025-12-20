#include "bluetooth.hpp"

BluetoothService::BluetoothService(QObject *parent)
    : QObject(parent)
{
    // Check for Bluetooth adapters
    const auto adapters = QBluetoothLocalDevice::allDevices();
    if (!adapters.isEmpty()) {
        m_localDevice = new QBluetoothLocalDevice(adapters.first().address(), this);
        m_available = true;

        m_discoveryAgent = new QBluetoothDeviceDiscoveryAgent(this);
        connect(m_localDevice, &QBluetoothLocalDevice::deviceConnected,
            this, [this](const QBluetoothAddress &address) {
                updateConnectionState(address, true);
            });
        connect(m_discoveryAgent, &QBluetoothDeviceDiscoveryAgent::deviceDiscovered,
            this, [this](const QBluetoothDeviceInfo &device) {
                if (m_localDevice->pairingStatus(device.address()) == QBluetoothLocalDevice::Paired) {
                    m_pairedDevices[device.address()] = device;
                }
            });

        connect(m_localDevice, &QBluetoothLocalDevice::deviceDisconnected,
            this, [this](const QBluetoothAddress &address) {
                updateConnectionState(address, false);
            });

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

    if (m_localDevice) {
        m_enabled = (m_localDevice->hostMode() != QBluetoothLocalDevice::HostPoweredOff);
        if (m_enabled) {
            scanForDevices();
        }
    }

}

void BluetoothService::update()
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
    if (enabled) {
        checkConnectedDevices();
    }
}

void BluetoothService::updateConnectionState(const QBluetoothAddress &address, bool connected)
{
    if (connected) {
        auto it = m_pairedDevices.find(address);
        if (it != m_pairedDevices.end()) {
            m_deviceAddress = address.toString();
            m_deviceName = it->name();
            m_connected = true;
            emit bluetoothConnectedChanged();
            emit bluetoothDeviceNameChanged();
            emit bluetoothDeviceAddressChanged();
        }
    } else {
        if (m_deviceAddress == address.toString()) {
            m_connected = false;
            m_deviceName.clear();
            m_deviceAddress.clear();
            emit bluetoothConnectedChanged();
            emit bluetoothDeviceNameChanged();
            emit bluetoothDeviceAddressChanged();
        }
    }
}

void BluetoothService::scanForDevices() {
    if (!m_available || !m_enabled || !m_discoveryAgent) return;

    if (m_discoveryAgent->isActive()) {
        m_discoveryAgent->stop();
    }
    m_discoveryAgent->start();
}

void BluetoothService::checkConnectedDevices()
{
    if (!m_localDevice) return;

    bool foundConnection = false;
    for (auto it = m_pairedDevices.begin(); it != m_pairedDevices.end(); ++it) {
        if (m_localDevice->pairingStatus(it.key()) == QBluetoothLocalDevice::Paired) {
            if (!m_connected) {
                m_deviceAddress = it.key().toString();
                m_deviceName = it->name();
                m_connected = true;
                foundConnection = true;
                emit bluetoothDeviceAddressChanged();
                emit bluetoothDeviceNameChanged();
                emit bluetoothConnectedChanged();
                break;
            }
        }
    }

    if (!foundConnection && m_connected) {
        m_connected = false;
        m_deviceName.clear();
        m_deviceAddress.clear();
        emit bluetoothConnectedChanged();
        emit bluetoothDeviceNameChanged();
        emit bluetoothDeviceAddressChanged();
    }
}
