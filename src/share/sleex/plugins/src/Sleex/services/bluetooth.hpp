#pragma once
#include <QObject>
#include <QtQml/qqmlregistration.h>
#include <QtBluetooth/QBluetoothLocalDevice>
#include <QtBluetooth/QBluetoothDeviceInfo>
#include <QtBluetooth/QBluetoothDeviceDiscoveryAgent>

class Bluetooth : public QObject {
    Q_OBJECT
    QML_SINGLETON
    QML_ELEMENT
    Q_PROPERTY(bool bluetoothEnabled READ bluetoothEnabled NOTIFY bluetoothEnabledChanged)
    Q_PROPERTY(bool bluetoothConnected READ bluetoothConnected NOTIFY bluetoothConnectedChanged)
    Q_PROPERTY(QString bluetoothDeviceName READ bluetoothDeviceName NOTIFY bluetoothDeviceChanged)
    Q_PROPERTY(QString bluetoothDeviceAddress READ bluetoothDeviceAddress NOTIFY bluetoothDeviceChanged)

public:
    explicit Bluetooth(QObject *parent = nullptr);

    bool bluetoothEnabled() const { return m_enabled; }
    bool bluetoothConnected() const { return m_connected; }
    QString bluetoothDeviceName() const { return m_deviceName; }
    QString bluetoothDeviceAddress() const { return m_deviceAddress; }

    Q_INVOKABLE void startScan();

signals:
    void bluetoothEnabledChanged();
    void bluetoothConnectedChanged();
    void bluetoothDeviceChanged();

private slots:
    void updateHostMode(QBluetoothLocalDevice::HostMode mode);
    void onDeviceDiscovered(const QBluetoothDeviceInfo &info);

private:
    QBluetoothLocalDevice m_localDevice;
    QBluetoothDeviceDiscoveryAgent m_discoveryAgent;

    bool m_enabled = false;
    bool m_connected = false;
    QString m_deviceName;
    QString m_deviceAddress;
};
