#pragma once

#include <QObject>
#include <QtBluetooth/QBluetoothLocalDevice>
#include <QtBluetooth/QBluetoothDeviceDiscoveryAgent>
#include <QtBluetooth/QBluetoothDeviceInfo>
#include <QtQml/qqml.h>
#include <QProcess>
#include <QTimer>

namespace sleex::services {

class BluetoothDevice : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Created by BluetoothService")
    
    Q_PROPERTY(QString name READ name NOTIFY nameChanged)
    Q_PROPERTY(QString address READ address CONSTANT)
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    Q_PROPERTY(bool paired READ paired NOTIFY pairedChanged)
    Q_PROPERTY(QString icon READ icon NOTIFY iconChanged)

public:
    explicit BluetoothDevice(const QBluetoothDeviceInfo &info, QObject *parent = nullptr);
    explicit BluetoothDevice(const QString &name, const QString &address, QObject *parent = nullptr);
    
    QString name() const { return m_name; }
    QString address() const { return m_address; }
    bool connected() const { return m_connected; }
    bool paired() const { return m_paired; }
    QString icon() const;
    
    void update(const QBluetoothDeviceInfo &info);
    void setConnected(bool connected);
    void setPaired(bool paired);

signals:
    void nameChanged();
    void connectedChanged();
    void pairedChanged();
    void iconChanged();

private:
    QBluetoothDeviceInfo m_info;
    QString m_name;
    QString m_address;
    bool m_connected = false;
    bool m_paired = false;
    bool m_hasInfo = false;
};

class BluetoothService : public QObject {
    Q_OBJECT
    QML_SINGLETON
    QML_NAMED_ELEMENT(BluetoothService)

    Q_PROPERTY(bool bluetoothAvailable READ bluetoothAvailable NOTIFY bluetoothAvailableChanged FINAL)
    Q_PROPERTY(bool bluetoothEnabled READ bluetoothEnabled WRITE setBluetoothEnabled NOTIFY bluetoothEnabledChanged FINAL)
    Q_PROPERTY(QList<QObject*> devices READ devices NOTIFY devicesChanged FINAL)
    Q_PROPERTY(bool discovering READ discovering WRITE setDiscovering NOTIFY discoveringChanged FINAL)

public:
    explicit BluetoothService(QObject *parent = nullptr);

    bool bluetoothAvailable() const { return m_available; }
    bool bluetoothEnabled() const { return m_enabled; }
    void setBluetoothEnabled(bool enabled);
    
    bool discovering() const { return m_discovering; }
    void setDiscovering(bool discovering);
    
    QList<QObject*> devices() const { return m_devices; }

    Q_INVOKABLE void connectDevice(const QString &address);
    Q_INVOKABLE void disconnectDevice(const QString &address);
    Q_INVOKABLE void pairDevice(const QString &address);
    Q_INVOKABLE void unpairDevice(const QString &address);
    Q_INVOKABLE void trustDevice(const QString &address);
    Q_INVOKABLE void setDiscovery(bool discover);
    Q_INVOKABLE void refreshPairedDevices();

signals:
    void bluetoothAvailableChanged();
    void bluetoothEnabledChanged();
    void devicesChanged();
    void discoveringChanged();

private:
    void addOrUpdateDevice(const QBluetoothDeviceInfo &info);
    void updateDeviceConnectionState(const QString &address, bool connected);
    void checkConnectedDevices();
    void parseMonitorOutput();

    QBluetoothLocalDevice *m_localDevice = nullptr;
    QBluetoothDeviceDiscoveryAgent *m_discoveryAgent = nullptr;
    QProcess *m_monitorProcess = nullptr;
    bool m_available = false;
    bool m_enabled = false;
    bool m_discovering = false;
    QList<QObject*> m_devices;
    QStringList m_pairedAddresses;
    QString m_pendingPairAddress;
    QTimer *m_pairTimeoutTimer = nullptr;
};

} // namespace sleex::services
