#include "bluetooth.hpp"
#include <QProcess>
#include <QTimer>
#include <QRegularExpression>

namespace sleex::services {

// BluetoothDevice Implementation
BluetoothDevice::BluetoothDevice(const QBluetoothDeviceInfo &info, QObject *parent)
    : QObject(parent), m_info(info), m_hasInfo(true)
{
    m_name = info.name();
    m_address = info.address().toString();
}

BluetoothDevice::BluetoothDevice(const QString &name, const QString &address, QObject *parent)
    : QObject(parent), m_name(name), m_address(address), m_hasInfo(false)
{
}

QString BluetoothDevice::icon() const {
    if (!m_hasInfo) {
        return "bluetooth_connected"; // Default icon
    }

    // Map device class to icon name
    QBluetoothDeviceInfo::MajorDeviceClass major = m_info.majorDeviceClass();
    quint8 minor = m_info.minorDeviceClass();
    
    switch (major) {
        case QBluetoothDeviceInfo::ComputerDevice:
            return "computer";
        case QBluetoothDeviceInfo::PhoneDevice:
            return "smartphone";
        case QBluetoothDeviceInfo::AudioVideoDevice:
            if (minor == QBluetoothDeviceInfo::WearableHeadsetDevice || 
                minor == QBluetoothDeviceInfo::HandsFreeDevice)
                return "headset";
            if (minor == QBluetoothDeviceInfo::Headphones)
                return "headphones";
            if (minor == QBluetoothDeviceInfo::Loudspeaker)
                return "speaker";
            return "audio_file"; // Generic audio
        case QBluetoothDeviceInfo::PeripheralDevice:
            if (minor == QBluetoothDeviceInfo::KeyboardPeripheral)
                return "keyboard_alt";
            if (minor == QBluetoothDeviceInfo::PointingDevicePeripheral)
                return "mouse";
            return "settings_input_component";
        case QBluetoothDeviceInfo::WearableDevice:
            return "watch";
        default:
            return "bluetooth_connected";
    }
}

void BluetoothDevice::update(const QBluetoothDeviceInfo &info) {
    m_info = info;
    m_hasInfo = true;
    
    if (m_name != info.name()) {
        m_name = info.name();
        emit nameChanged();
    }
    emit iconChanged();
}

void BluetoothDevice::setConnected(bool connected) {
    if (m_connected != connected) {
        m_connected = connected;
        emit connectedChanged();
    }
}

void BluetoothDevice::setPaired(bool paired) {
    if (m_paired != paired) {
        m_paired = paired;
        emit pairedChanged();
    }
}


// BluetoothService Implementation
BluetoothService::BluetoothService(QObject *parent)
    : QObject(parent)
{
    // Check for Bluetooth adapters
    const auto adapters = QBluetoothLocalDevice::allDevices();
    if (!adapters.isEmpty()) {
        m_localDevice = new QBluetoothLocalDevice(adapters.first().address(), this);
        m_available = true;
        m_enabled = (m_localDevice->hostMode() != QBluetoothLocalDevice::HostPoweredOff);
        m_discovering = false;

        connect(m_localDevice, &QBluetoothLocalDevice::hostModeStateChanged, this, [this](QBluetoothLocalDevice::HostMode mode) {
            bool enabled = (mode != QBluetoothLocalDevice::HostPoweredOff);
            if (m_enabled != enabled) {
                m_enabled = enabled;
                emit bluetoothEnabledChanged();
            }
        });
        
        connect(m_localDevice, &QBluetoothLocalDevice::deviceConnected, this, [this](const QBluetoothAddress &address){
            updateDeviceConnectionState(address.toString(), true);
        });
        
        connect(m_localDevice, &QBluetoothLocalDevice::deviceDisconnected, this, [this](const QBluetoothAddress &address){
            updateDeviceConnectionState(address.toString(), false);
        });
        
        // Initialize discovery agent
        m_discoveryAgent = new QBluetoothDeviceDiscoveryAgent(adapters.first().address(), this);
        connect(m_discoveryAgent, &QBluetoothDeviceDiscoveryAgent::deviceDiscovered, this, &BluetoothService::addOrUpdateDevice);
        connect(m_discoveryAgent, &QBluetoothDeviceDiscoveryAgent::finished, this, [this](){
            if (m_discovering) {
                // Restart if we are supposed to be discovering
                m_discoveryAgent->start();
            }
        });
        
    } else {
        // No adapters at all
        m_available = false;
    }
    
    // Start bluetoothctl monitor
    m_monitorProcess = new QProcess(this);
    m_monitorProcess->setProcessChannelMode(QProcess::MergedChannels);
    connect(m_monitorProcess, &QProcess::readyReadStandardOutput, this, &BluetoothService::parseMonitorOutput);
    m_monitorProcess->start("bluetoothctl");
    
    refreshPairedDevices();
    checkConnectedDevices();
}

void BluetoothService::setBluetoothEnabled(bool enabled)
{
    if (m_localDevice) {
        if (enabled) {
            m_localDevice->powerOn();
        } else {
            m_localDevice->setHostMode(QBluetoothLocalDevice::HostPoweredOff);
        }
    }
}

void BluetoothService::setDiscovering(bool discovering)
{
    if (m_discovering != discovering) {
        m_discovering = discovering;
        emit discoveringChanged();
        setDiscovery(discovering);
    }
}

void BluetoothService::connectDevice(const QString &address)
{
    QProcess::startDetached("bluetoothctl", {"connect", address});
}

void BluetoothService::disconnectDevice(const QString &address)
{
    QProcess::startDetached("bluetoothctl", {"disconnect", address});
}

void BluetoothService::pairDevice(const QString &address)
{
    if (m_monitorProcess && m_monitorProcess->state() == QProcess::Running) {
        m_pendingPairAddress = address;
        
        // Start scanning via the interactive monitor
        m_monitorProcess->write("scan on\n");
        
        // Setup a fallback timer in case we don't see a discovery event
        if (!m_pairTimeoutTimer) {
            m_pairTimeoutTimer = new QTimer(this);
            m_pairTimeoutTimer->setSingleShot(true);
            connect(m_pairTimeoutTimer, &QTimer::timeout, this, [this]() {
                if (!m_pendingPairAddress.isEmpty()) {
                    QString addr = m_pendingPairAddress;
                    m_pendingPairAddress.clear();
                    
                    // Try to pair anyway
                    if (m_monitorProcess) {
                        m_monitorProcess->write(QString("pair %1\n").arg(addr).toUtf8());
                        m_monitorProcess->write(QString("trust %1\n").arg(addr).toUtf8());
                        m_monitorProcess->write(QString("connect %1\n").arg(addr).toUtf8());
                        
                        // Turn off scan if we weren't discovering
                        if (!m_discovering) {
                            m_monitorProcess->write("scan off\n");
                        }
                    }
                }
            });
        }
        m_pairTimeoutTimer->start(5000); // 5 seconds timeout
    } else {
        // Fallback if monitor is dead (shouldn't happen)
        QProcess::startDetached("bash", {"-c", QString("bluetoothctl pair %1 && bluetoothctl trust %1 && bluetoothctl connect %1").arg(address)});
    }
}

void BluetoothService::unpairDevice(const QString &address)
{
    QProcess::startDetached("bluetoothctl", {"remove", address});
    // Refresh list after a short delay
    QTimer::singleShot(1000, this, &BluetoothService::refreshPairedDevices);
}

void BluetoothService::trustDevice(const QString &address)
{
    QProcess::startDetached("bluetoothctl", {"trust", address});
}

void BluetoothService::setDiscovery(bool discover)
{
    // Only use QBluetoothDeviceDiscoveryAgent for discovery to avoid conflicts
    // bluetoothctl scan on/off is handled via monitor if needed for pairing
    
    if (m_discovering != discover) {
        m_discovering = discover;
        emit discoveringChanged();
    }
    
    if (m_discoveryAgent) {
        if (discover) {
            m_discoveryAgent->start();
        } else {
            m_discoveryAgent->stop();
        }
    }
}

void BluetoothService::refreshPairedDevices()
{
    QProcess *process = new QProcess(this);
    connect(process, &QProcess::finished, this, [this, process](int exitCode, QProcess::ExitStatus exitStatus) {
        if (exitStatus == QProcess::NormalExit && exitCode == 0) {
            QString output = process->readAllStandardOutput();
            QStringList lines = output.split('\n', Qt::SkipEmptyParts);
            QStringList newPaired;
            for (const QString &line : lines) {
                // Output format: "Device <addr> <name>"
                QStringList parts = line.split(' ', Qt::SkipEmptyParts);
                if (parts.size() >= 3 && parts[0] == "Device") {
                    QString address = parts[1];
                    QString name = parts.mid(2).join(' ');
                    newPaired.append(address);
                    
                    // Check if device exists, if not create it
                    bool found = false;
                    for (QObject* obj : m_devices) {
                        BluetoothDevice* device = qobject_cast<BluetoothDevice*>(obj);
                        if (device && device->address() == address) {
                            found = true;
                            break;
                        }
                    }
                    
                    if (!found) {
                        BluetoothDevice* device = new BluetoothDevice(name, address, this);
                        device->setPaired(true);
                        m_devices.append(device);
                        emit devicesChanged();
                    }
                }
            }
            
            m_pairedAddresses = newPaired;
            
            // Update existing devices paired status
            for (QObject* obj : m_devices) {
                BluetoothDevice* device = qobject_cast<BluetoothDevice*>(obj);
                if (device) {
                    device->setPaired(m_pairedAddresses.contains(device->address()));
                }
            }
        }
        process->deleteLater();
    });
    process->start("bluetoothctl", {"devices", "Paired"});
}

void BluetoothService::updateDeviceConnectionState(const QString &address, bool connected)
{
    for (QObject* obj : m_devices) {
        BluetoothDevice* device = qobject_cast<BluetoothDevice*>(obj);
        if (device && device->address() == address) {
            device->setConnected(connected);
            return;
        }
    }
}

void BluetoothService::checkConnectedDevices()
{
    if (!m_localDevice) return;
    
    QList<QBluetoothAddress> connectedAddrs = m_localDevice->connectedDevices();
    QStringList connectedStrs;
    for (const auto &addr : connectedAddrs) {
        connectedStrs.append(addr.toString());
    }
    
    for (QObject* obj : m_devices) {
        BluetoothDevice* device = qobject_cast<BluetoothDevice*>(obj);
        if (device) {
            device->setConnected(connectedStrs.contains(device->address()));
        }
    }
}

void BluetoothService::addOrUpdateDevice(const QBluetoothDeviceInfo &info)
{
    QString address = info.address().toString();
    
    // Check if device already exists
    for (QObject* obj : m_devices) {
        BluetoothDevice* device = qobject_cast<BluetoothDevice*>(obj);
        if (device && device->address() == address) {
            device->update(info);
            return;
        }
    }
    
    // New device
    BluetoothDevice* device = new BluetoothDevice(info, this);
    device->setPaired(m_pairedAddresses.contains(address));
    
    // Check connection status
    if (m_localDevice) {
        QList<QBluetoothAddress> connectedAddrs = m_localDevice->connectedDevices();
        device->setConnected(connectedAddrs.contains(info.address()));
    }
    
    m_devices.append(device);
    emit devicesChanged();
}

void BluetoothService::parseMonitorOutput()
{
    while (m_monitorProcess->canReadLine()) {
        QString line = QString::fromUtf8(m_monitorProcess->readLine()).trimmed();
        
        // Strip color codes if present (bluetoothctl uses them)
        static QRegularExpression colorRegex("\x1B\\[[0-9;]*[mK]");
        line.remove(colorRegex);
        
        // Check for discovery of the pending device
        if (!m_pendingPairAddress.isEmpty()) {
            if (line.startsWith("[NEW] Device") || line.startsWith("[CHG] Device")) {
                QStringList parts = line.split(' ', Qt::SkipEmptyParts);
                if (parts.size() >= 3) {
                    QString address = parts[2];
                    if (address == m_pendingPairAddress) {
                        // Found it! Pair immediately.
                        if (m_pairTimeoutTimer) m_pairTimeoutTimer->stop();
                        m_pendingPairAddress.clear();
                        
                        m_monitorProcess->write(QString("pair %1\n").arg(address).toUtf8());
                        m_monitorProcess->write(QString("trust %1\n").arg(address).toUtf8());
                        m_monitorProcess->write(QString("connect %1\n").arg(address).toUtf8());
                        
                        // Turn off scan if we weren't discovering
                        if (!m_discovering) {
                            m_monitorProcess->write("scan off\n");
                        }
                    }
                }
            }
        }

        // Parse device state changes from bluetoothctl output
        if (line.startsWith("[CHG] Device")) {
            QStringList parts = line.split(' ', Qt::SkipEmptyParts);
            if (parts.size() >= 5) {
                QString address = parts[2];
                QString property = parts[3];
                QString value = parts[4];
                
                if (property == "Connected:") {
                    bool isConnected = (value == "yes");
                    bool found = false;
                    for (QObject* obj : m_devices) {
                        BluetoothDevice* device = qobject_cast<BluetoothDevice*>(obj);
                        if (device && device->address() == address) {
                            device->setConnected(isConnected);
                            found = true;
                            break;
                        }
                    }
                    if (!found && isConnected) {
                        // Device connected but not in list? Add it.
                        BluetoothDevice* device = new BluetoothDevice(address, address, this);
                        device->setConnected(true);
                        device->setPaired(m_pairedAddresses.contains(address));
                        m_devices.append(device);
                        emit devicesChanged();
                    }
                } else if (property == "Paired:") {
                    bool paired = (value == "yes");
                    for (QObject* obj : m_devices) {
                        BluetoothDevice* device = qobject_cast<BluetoothDevice*>(obj);
                        if (device && device->address() == address) {
                            device->setPaired(paired);
                            break;
                        }
                    }
                    if (paired && !m_pairedAddresses.contains(address)) {
                        m_pairedAddresses.append(address);
                    } else if (!paired) {
                        m_pairedAddresses.removeAll(address);
                    }
                }
            }
        } else if (line.startsWith("[DEL] Device")) {
            // Device removed from bluez (unpaired)
            QStringList parts = line.split(' ', Qt::SkipEmptyParts);
            if (parts.size() >= 3) {
                QString address = parts[2];
                for (QObject* obj : m_devices) {
                    BluetoothDevice* device = qobject_cast<BluetoothDevice*>(obj);
                    if (device && device->address() == address) {
                        device->setPaired(false);
                        device->setConnected(false);
                        break;
                    }
                }
                m_pairedAddresses.removeAll(address);
            }
        } else if (line.contains("Failed to connect")) {
             // Handle connection failure
             if (line.contains("In Progress") || line.contains("InProgress")) {
                 // Connection failed because it's already in progress, which is fine.
                 // We could add retry logic here if needed in the future.
             }
        }
    }
}

} // namespace sleex::services
