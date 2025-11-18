#pragma once

#ifdef signals
#undef signals
#endif

#include <NetworkManager.h>

#ifndef QT_NO_KEYWORDS
#define signals Q_SIGNALS
#endif

#include <QObject>
#include <QtQml/qqmlregistration.h>
#include <QTimer>

namespace sleex::services {

class AccessPoint : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("AccessPoints are created by Network")
    Q_PROPERTY(QString ssid READ ssid NOTIFY ssidChanged)
    Q_PROPERTY(QString bssid READ bssid NOTIFY bssidChanged)
    Q_PROPERTY(int strength READ strength NOTIFY strengthChanged)
    Q_PROPERTY(int frequency READ frequency NOTIFY frequencyChanged)
    Q_PROPERTY(bool active READ active NOTIFY activeChanged)
    Q_PROPERTY(bool isSecure READ isSecure NOTIFY isSecureChanged)
    Q_PROPERTY(bool isKnown READ isKnown NOTIFY isKnownChanged)

public:
    explicit AccessPoint(NMAccessPoint *ap, NMDeviceWifi *device, QObject *parent = nullptr);
    ~AccessPoint();
    
    QString ssid() const { return m_ssid; }
    QString bssid() const { return m_bssid; }
    int strength() const { return m_strength; }
    int frequency() const { return m_frequency; }
    bool active() const;
    bool isSecure() const { return m_isSecure; }
    bool isKnown() const { return m_isKnown; }
    
    NMAccessPoint* nmAccessPoint() const { return m_ap; }
    void updateProperties();
    void updateAccessPoint(NMAccessPoint *newAp);
    void setIsKnown(bool known);

signals:
    void ssidChanged();
    void bssidChanged();
    void strengthChanged();
    void frequencyChanged();
    void activeChanged();
    void isSecureChanged();
    void isKnownChanged();

private:
    NMAccessPoint *m_ap;
    NMDeviceWifi *m_device;
    QString m_ssid;
    QString m_bssid;
    int m_strength;
    int m_frequency;
    bool m_isSecure;
    bool m_isKnown;
    gulong m_strengthChangedId;
};

class Network : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(QList<AccessPoint*> networks READ networks NOTIFY networksChanged)
    Q_PROPERTY(AccessPoint* active READ active NOTIFY activeChanged)
    Q_PROPERTY(bool wifiEnabled READ wifiEnabled NOTIFY wifiEnabledChanged)
    Q_PROPERTY(bool ethernet READ ethernet NOTIFY ethernetChanged)
    Q_PROPERTY(bool scanning READ scanning NOTIFY scanningChanged)
    Q_PROPERTY(QString connectingToSsid READ connectingToSsid NOTIFY connectingToSsidChanged)

public:
    explicit Network(QObject *parent = nullptr);
    ~Network();
    
    QList<AccessPoint*> networks() const { return m_networks; }
    AccessPoint* active() const { return m_active; }
    bool wifiEnabled() const { return m_wifiEnabled; }
    bool ethernet() const { return m_ethernet; }
    bool scanning() const { return m_scanning; }
    QString connectingToSsid() const { return m_connectingToSsid; }
    
    // Check if a connection has authentication failure (callable from QML)
    Q_INVOKABLE bool hasConnectionFailed(const QString &ssid) const;
    
    // Internal methods to track connection failures
    void markConnectionFailed(const QString &ssid);
    Q_INVOKABLE void clearConnectionFailed(const QString &ssid);
    void emitConnectionFailedOnce(const QString &ssid, const QString &message, bool isAuthError = false);
    
    Q_INVOKABLE QString getNetworkIcon(int strength);
    Q_INVOKABLE void enableWifi(bool enabled);
    Q_INVOKABLE void toggleWifi();
    Q_INVOKABLE void rescanWifi();
    Q_INVOKABLE void connectToNetwork(const QString &ssid, const QString &password);
    Q_INVOKABLE void disconnectFromNetwork();
    Q_INVOKABLE void forgetNetwork(const QString &ssid);
    Q_INVOKABLE void updateNetworks();
    Q_INVOKABLE void updateActiveConnection();

private slots:
    void verifyDelayedConnection(const QString &ssid);

private:
    void emitConnectionSucceededWithVerification(const QString &ssid);

signals:
    void networksChanged();
    void activeChanged();
    void wifiEnabledChanged();
    void ethernetChanged();
    void scanningChanged();
    void connectingToSsidChanged();
    void connectionSucceeded(const QString &ssid);
    void connectionFailed(const QString &ssid, const QString &error);
    void passwordRequired(const QString &ssid);

private:
    static void onAccessPointAdded(NMDeviceWifi *device, NMAccessPoint *ap, gpointer user_data);
    static void onAccessPointRemoved(NMDeviceWifi *device, NMAccessPoint *ap, gpointer user_data);
    static void onDeviceAdded(NMClient *client, NMDevice *device, gpointer user_data);
    static void onDeviceRemoved(NMClient *client, NMDevice *device, gpointer user_data);
    static void onWirelessEnabledChanged(GObject *object, GParamSpec *pspec, gpointer user_data);
    static void onActiveConnectionsChanged(GObject *object, GParamSpec *pspec, gpointer user_data);
    static void onScanDone(GObject *source, GAsyncResult *result, gpointer user_data);
    static void onConnectionActivated(GObject *source, GAsyncResult *result, gpointer user_data);
    static void onConnectionAddedAndActivated(GObject *source, GAsyncResult *result, gpointer user_data);
    static void onConnectionDeactivated(GObject *source, GAsyncResult *result, gpointer user_data);
    static void onConnectionAdded(NMClient *client, NMRemoteConnection *connection, gpointer user_data);
    static void onConnectionRemoved(NMClient *client, NMRemoteConnection *connection, gpointer user_data);
    static void onDeviceStateChanged(GObject *object, GParamSpec *pspec, gpointer user_data);
    static void onWifiEnabledSet(GObject *source, GAsyncResult *result, gpointer user_data);
    
    void updateEthernetStatus();
    void updateKnownNetworks();
    AccessPoint* findAccessPoint(NMAccessPoint *ap);
    NMDeviceWifi* getPrimaryWifiDevice();
    NMRemoteConnection* findConnectionForSsid(const QString &ssid);
    
    NMClient *m_client;
    NMDeviceWifi *m_wifiDevice;
    QList<AccessPoint*> m_networks;
    AccessPoint* m_active;
    QStringList m_knownSsids;
    bool m_wifiEnabled;
    bool m_ethernet;
    bool m_scanning;
    QString m_connectingToSsid;
    QStringList m_failedConnections; // Track SSIDs with authentication failures
    QStringList m_authErrorEmitted; // Track SSIDs that have already emitted auth errors
    
    gulong m_apAddedId;
    gulong m_apRemovedId;
    gulong m_deviceAddedId;
    gulong m_deviceRemovedId;
    gulong m_wirelessEnabledId;
    gulong m_activeConnectionsId;
    gulong m_connectionAddedId;
    gulong m_connectionRemovedId;
    gulong m_deviceStateChangedId;
};

} // namespace sleex::services
