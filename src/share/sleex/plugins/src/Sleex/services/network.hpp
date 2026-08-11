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
#include <QProcess>
#include <QVariantList>
#include <QVariantMap>

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
    Q_PROPERTY(QString security READ security NOTIFY securityChanged)

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
    QString security() const { return m_security; }
    
    NMAccessPoint* nmAccessPoint() const { return m_ap; }
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
    void securityChanged();

private:
    void connectStrengthSignal();
    void updateProperties();

    NMAccessPoint *m_ap;
    NMDeviceWifi *m_device;
    QString m_ssid;
    QString m_bssid;
    int m_strength;
    int m_frequency;
    bool m_isSecure;
    bool m_isKnown;
    QString m_security;
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
    Q_PROPERTY(QString wifiIcon READ getWifiIcon NOTIFY wifiIconChanged)
    Q_PROPERTY(QString connectingToSsid READ connectingToSsid NOTIFY connectingToSsidChanged)

    // --- Ported from the deprecated Network.qml QML wrapper. This singleton
    // now owns all network-related state and system-process orchestration;
    // QML is left with presentation-only derivations. ---

    Q_PROPERTY(bool hasActiveConnection READ hasActiveConnection NOTIFY hasActiveConnectionChanged)

    Q_PROPERTY(QString lastConnectionError READ lastConnectionError NOTIFY lastConnectionErrorChanged)
    Q_PROPERTY(QString errorSsid READ errorSsid NOTIFY errorSsidChanged)
    Q_PROPERTY(bool showConnectionError READ showConnectionError NOTIFY showConnectionErrorChanged)

    Q_PROPERTY(QString localIp READ localIp NOTIFY localIpChanged)
    Q_PROPERTY(QString gatewayIp READ gatewayIp NOTIFY gatewayIpChanged)
    Q_PROPERTY(QString dnsServers READ dnsServers NOTIFY dnsServersChanged)
    Q_PROPERTY(QString publicIp READ publicIp NOTIFY publicIpChanged)
    Q_PROPERTY(QString netInfoError READ netInfoError NOTIFY netInfoErrorChanged)
    Q_PROPERTY(bool fetchingNetworkInfo READ fetchingNetworkInfo NOTIFY fetchingNetworkInfoChanged)

    Q_PROPERTY(bool dnsApplying READ dnsApplying NOTIFY dnsApplyingChanged)
    Q_PROPERTY(QString dnsApplyError READ dnsApplyError NOTIFY dnsApplyErrorChanged)
    Q_PROPERTY(QVariantList dnsProviders READ dnsProviders CONSTANT)

    Q_PROPERTY(bool speedTestRunning READ speedTestRunning NOTIFY speedTestRunningChanged)
    Q_PROPERTY(QString speedTestStage READ speedTestStage NOTIFY speedTestStageChanged)
    Q_PROPERTY(double speedTestPingMs READ speedTestPingMs NOTIFY speedTestPingMsChanged)
    Q_PROPERTY(double speedTestDownloadMbps READ speedTestDownloadMbps NOTIFY speedTestDownloadMbpsChanged)
    Q_PROPERTY(double speedTestUploadMbps READ speedTestUploadMbps NOTIFY speedTestUploadMbpsChanged)
    Q_PROPERTY(QString speedTestError READ speedTestError NOTIFY speedTestErrorChanged)
    Q_PROPERTY(QString speedTestSsid READ speedTestSsid NOTIFY speedTestSsidChanged)
    Q_PROPERTY(QVariantMap speedTestResults READ speedTestResults NOTIFY speedTestResultsChanged)

    Q_PROPERTY(bool qrGenerating READ qrGenerating NOTIFY qrGeneratingChanged)
    Q_PROPERTY(QString qrImagePath READ qrImagePath NOTIFY qrImagePathChanged)
    Q_PROPERTY(QString qrError READ qrError NOTIFY qrErrorChanged)
    Q_PROPERTY(QString qrActiveSsid READ qrActiveSsid NOTIFY qrActiveSsidChanged)

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
    Q_INVOKABLE QString getWifiIcon(); // Helper to get appropriate WiFi icon for UI
    Q_INVOKABLE void enableWifi(bool enabled);
    Q_INVOKABLE void toggleWifi();
    Q_INVOKABLE void rescanWifi();
    Q_INVOKABLE void connectToNetwork(const QString &ssid, const QString &password);
    Q_INVOKABLE void disconnectFromNetwork();
    Q_INVOKABLE void forgetNetwork(const QString &ssid);
    Q_INVOKABLE void updateNetworks();
    Q_INVOKABLE void updateActiveConnection();

    // --- Ported from Network.qml ---

    bool hasActiveConnection() const;

    QString lastConnectionError() const { return m_lastConnectionError; }
    QString errorSsid() const { return m_errorSsid; }
    bool showConnectionError() const { return m_showConnectionError; }

    QString localIp() const { return m_localIp; }
    QString gatewayIp() const { return m_gatewayIp; }
    QString dnsServers() const { return m_dnsServers; }
    QString publicIp() const { return m_publicIp; }
    QString netInfoError() const { return m_netInfoError; }
    bool fetchingNetworkInfo() const { return m_activeInfoProcesses > 0; }
    Q_INVOKABLE void fetchNetworkInfo();

    bool dnsApplying() const { return m_dnsApplying; }
    QString dnsApplyError() const { return m_dnsApplyError; }
    QVariantList dnsProviders() const;
    Q_INVOKABLE QVariantMap providerById(const QString &id) const;
    Q_INVOKABLE void applyDnsSettings(bool enabled, const QString &providerId);

    bool speedTestRunning() const { return m_speedTestRunning; }
    QString speedTestStage() const { return m_speedTestStage; }
    double speedTestPingMs() const { return m_speedTestPingMs; }
    double speedTestDownloadMbps() const { return m_speedTestDownloadMbps; }
    double speedTestUploadMbps() const { return m_speedTestUploadMbps; }
    QString speedTestError() const { return m_speedTestError; }
    QString speedTestSsid() const { return m_speedTestSsid; }
    QVariantMap speedTestResults() const { return m_speedTestResults; }
    Q_INVOKABLE void startSpeedTest();

    bool qrGenerating() const { return m_qrGenerating; }
    QString qrImagePath() const { return m_qrImagePath; }
    QString qrError() const { return m_qrError; }
    QString qrActiveSsid() const { return m_qrActiveSsid; }
    Q_INVOKABLE void generateQrCode(const QString &ssid, const QString &securityStr);
    Q_INVOKABLE void clearQrCode();

private slots:
    void verifyDelayedConnection(const QString &ssid);

private:
    void scheduleConnectionVerification(const QString &ssid);
    void finalizeConnectionResult(const QString &ssid);
    void emitConnectionSucceededWithVerification(const QString &ssid);

    // --- Ported from Network.qml ---
    void _onConnectionFailedInternal(const QString &ssid, const QString &error);
    void _onConnectionSucceededInternal(const QString &ssid);

    void setLastConnectionError(const QString &v);
    void setErrorSsid(const QString &v);
    void setShowConnectionError(bool v);

    void setLocalIp(const QString &v);
    void setGatewayIp(const QString &v);
    void setDnsServers(const QString &v);
    void setPublicIp(const QString &v);
    void setNetInfoError(const QString &v);
    void beginInfoFetch();
    void endInfoFetch();

    void setDnsApplying(bool v);
    void setDnsApplyError(const QString &v);

    void setSpeedTestRunning(bool v);
    void setSpeedTestStage(const QString &v);
    void setSpeedTestPingMs(double v);
    void setSpeedTestDownloadMbps(double v);
    void setSpeedTestUploadMbps(double v);
    void setSpeedTestError(const QString &v);
    void setSpeedTestSsid(const QString &v);
    void loadSpeedTestCache();
    void cacheSpeedTestResult(const QString &ssid);
    void runSpeedTestDownload();
    void runSpeedTestUpload();

    void setQrGenerating(bool v);
    void setQrImagePath(const QString &v);
    void setQrError(const QString &v);
    void setQrActiveSsid(const QString &v);
    void encodeQr(const QString &ssid, const QString &password, const QString &authType);

signals:
    void networksChanged();
    void activeChanged();
    void wifiEnabledChanged();
    void wifiIconChanged();
    void ethernetChanged();
    void scanningChanged();
    void connectingToSsidChanged();
    void connectionSucceeded(const QString &ssid);
    void connectionFailed(const QString &ssid, const QString &error);
    void passwordRequired(const QString &ssid);

    // --- Ported from Network.qml ---
    void hasActiveConnectionChanged();
    void lastConnectionErrorChanged();
    void errorSsidChanged();
    void showConnectionErrorChanged();

    void localIpChanged();
    void gatewayIpChanged();
    void dnsServersChanged();
    void publicIpChanged();
    void netInfoErrorChanged();
    void fetchingNetworkInfoChanged();

    void dnsApplyingChanged();
    void dnsApplyErrorChanged();

    void speedTestRunningChanged();
    void speedTestStageChanged();
    void speedTestPingMsChanged();
    void speedTestDownloadMbpsChanged();
    void speedTestUploadMbpsChanged();
    void speedTestErrorChanged();
    void speedTestSsidChanged();
    void speedTestResultsChanged();

    void qrGeneratingChanged();
    void qrImagePathChanged();
    void qrErrorChanged();
    void qrActiveSsidChanged();

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

    // --- Ported from Network.qml ---
    QTimer m_errorTimer;
    QString m_lastConnectionError;
    QString m_errorSsid;
    bool m_showConnectionError = false;

    QString m_cacheDir;
    QString m_localIp = QStringLiteral("—");
    QString m_gatewayIp = QStringLiteral("—");
    QString m_dnsServers = QStringLiteral("—");
    QString m_publicIp = QStringLiteral("—");
    QString m_netInfoError;
    int m_activeInfoProcesses = 0;

    bool m_dnsApplying = false;
    bool m_dnsReapplyQueued = false;
    QString m_dnsApplyError;
    bool m_pendingDnsEnabled = false;
    QString m_pendingDnsProviderId = QStringLiteral("cloudflare");

    bool m_speedTestRunning = false;
    QString m_speedTestStage = QStringLiteral("idle");
    double m_speedTestPingMs = -1;
    double m_speedTestDownloadMbps = -1;
    double m_speedTestUploadMbps = -1;
    QString m_speedTestError;
    QString m_speedTestSsid;
    QVariantMap m_speedTestResults;

    bool m_qrGenerating = false;
    QString m_qrImagePath;
    QString m_qrError;
    QString m_qrActiveSsid;
};

} // namespace sleex::services
