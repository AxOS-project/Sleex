#ifdef signals
#undef signals
#endif

#include <NetworkManager.h>

#ifndef QT_NO_KEYWORDS
#define signals Q_SIGNALS
#endif

#include <QCoreApplication>
#include <QDebug>
#include <QTimer>

// Simple test to verify NetworkManager integration without the full Qt/QML overhead
int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
    
    qDebug() << "=== NetworkManager Connection Test ===";
    
    // Initialize NetworkManager client
    NMClient *client = nm_client_new(nullptr, nullptr);
    if (!client) {
        qCritical() << "Failed to initialize NetworkManager client";
        return 1;
    }
    
    // Check WiFi device
    const GPtrArray *devices = nm_client_get_devices(client);
    NMDevice *wifiDevice = nullptr;
    
    for (guint i = 0; i < devices->len; i++) {
        NMDevice *device = (NMDevice*)g_ptr_array_index(devices, i);
        if (nm_device_get_device_type(device) == NM_DEVICE_TYPE_WIFI) {
            wifiDevice = device;
            qDebug() << "Found WiFi device:" << nm_device_get_iface(device);
            break;
        }
    }
    
    if (!wifiDevice) {
        qCritical() << "No WiFi device found";
        g_object_unref(client);
        return 1;
    }
    
    // Monitor device state changes
    qDebug() << "Monitoring device states for 30 seconds...";
    qDebug() << "Start another terminal and run: nmcli device wifi connect \"NothingPhone(2a)\" password \"wrongpassword123\"";
    
    QTimer *timer = new QTimer;
    int count = 0;
    QObject::connect(timer, &QTimer::timeout, [&]() {
        count++;
        NMDeviceState state = nm_device_get_state(wifiDevice);
        NMDeviceStateReason reason = nm_device_get_state_reason(wifiDevice);
        
        NMActiveConnection *activeConn = nm_device_get_active_connection(wifiDevice);
        QString connInfo = "None";
        if (activeConn) {
            NMActiveConnectionState connState = nm_active_connection_get_state(activeConn);
            connInfo = QString("ID: %1, State: %2").arg(nm_active_connection_get_id(activeConn)).arg(connState);
        }
        
        qDebug() << QString("[%1s] Device State: %2, Reason: %3, Connection: %4")
                    .arg(count)
                    .arg(state)
                    .arg(reason)
                    .arg(connInfo);
        
        if (count >= 30) {
            app.quit();
        }
    });
    
    timer->start(1000);
    return app.exec();
}