#pragma once

#include <QObject>
#include <QtBluetooth/QBluetoothLocalDevice>
#include <QtBluetooth/QBluetoothDeviceDiscoveryAgent>
#include <QtQml/qqml.h>

// I Added this headers
#include <QTimer>
#include <QHash>
#include <QtBluetooth/QBluetoothDeviceInfo>
#include <QtBluetooth/QBluetoothAddress>

class BluetoothService : public QObject {
    Q_OBJECT
    QML_SINGLETON
    QML_NAMED_ELEMENT(BluetoothService)

    Q_PROPERTY(bool bluetoothAvailable READ bluetoothAvailable NOTIFY bluetoothAvailableChanged FINAL)
    Q_PROPERTY(bool bluetoothEnabled READ bluetoothEnabled NOTIFY bluetoothEnabledChanged FINAL)
    Q_PROPERTY(bool bluetoothConnected READ bluetoothConnected NOTIFY bluetoothConnectedChanged FINAL)
    Q_PROPERTY(QString bluetoothDeviceName READ bluetoothDeviceName NOTIFY bluetoothDeviceNameChanged FINAL)
    Q_PROPERTY(QString bluetoothDeviceAddress READ bluetoothDeviceAddress NOTIFY bluetoothDeviceAddressChanged FINAL)

public:
    explicit BluetoothService(QObject *parent = nullptr);

    bool bluetoothAvailable() const { return m_available; }
    bool bluetoothEnabled() const { return m_enabled; }
    bool bluetoothConnected() const { return m_connected; }
    QString bluetoothDeviceName() const { return m_deviceName; }
    QString bluetoothDeviceAddress() const { return m_deviceAddress; }

    Q_INVOKABLE void update();

signals:
    void bluetoothAvailableChanged();
    void bluetoothEnabledChanged();
    void bluetoothConnectedChanged();
    void bluetoothDeviceNameChanged();
    void bluetoothDeviceAddressChanged();

private:
    void scanForDevices();
    void updateConnectionState(const QBluetoothAddress &&address, bool connected);

    QBluetoothLocalDevice *m_localDevice = nullptr;
    QBluetoothDeviceDiscoveryAgent *m_discoveryAgent = nullptr;
    QHash<QBluetoothAddress, QBluetoothDeviceInfo> m_pairedDevices;
    bool m_available = false;
    bool m_enabled = false;
    bool m_connected = false;
    QString m_deviceName;
    QString m_deviceAddress;
};
