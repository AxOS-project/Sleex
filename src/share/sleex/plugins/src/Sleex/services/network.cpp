#include "network.hpp"
#include <QDebug>
#include <QMap>
#include <QByteArray>
#include <QTimer>
#include <QProcess>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>

namespace sleex::services {

// nmcli TYPE is "802-3-ethernet" for wired, "802-11-wireless" for WiFi -
// kept here only as a comment for context; icon/label logic now lives in QML
// off of `active`/`ethernet` directly.

static const QVariantList &staticDnsProviders() {
    static const QVariantList providers = {
        QVariantMap{{"id", "cloudflare"},         {"name", "Cloudflare"},            {"servers", "1.1.1.1,1.0.0.1"}},
        QVariantMap{{"id", "google"},             {"name", "Google"},                {"servers", "8.8.8.8,8.8.4.4"}},
        QVariantMap{{"id", "quad9"},              {"name", "Quad9"},                 {"servers", "9.9.9.9,149.112.112.112"}},
        QVariantMap{{"id", "cloudflare-malware"}, {"name", "Cloudflare (Security)"}, {"servers", "1.1.1.2,1.0.0.2"}},
        QVariantMap{{"id", "opendns"},            {"name", "OpenDNS"},               {"servers", "208.67.222.222,208.67.220.220"}},
        QVariantMap{{"id", "cloudflare-family"},  {"name", "Cloudflare (Family)"},   {"servers", "1.1.1.3,1.0.0.3"}},
        QVariantMap{{"id", "opendns-family"},     {"name", "OpenDNS FamilyShield"},  {"servers", "208.67.222.123,208.67.220.123"}}
    };
    return providers;
}

struct ConnectionCallbackData {
    Network *network;
    QString ssid;
};


AccessPoint::AccessPoint(NMAccessPoint *ap, NMDeviceWifi *device, QObject *parent)
    : QObject(parent), m_ap(ap), m_device(device), m_isKnown(false)
{
    g_object_ref(m_ap);
    updateProperties();
    connectStrengthSignal();
}

AccessPoint::~AccessPoint() {
    if (m_strengthChangedId)
        g_signal_handler_disconnect(m_ap, m_strengthChangedId);
    g_object_unref(m_ap);
}

void AccessPoint::connectStrengthSignal() {
    m_strengthChangedId = g_signal_connect(m_ap, "notify::strength",
        G_CALLBACK(+[](GObject*, GParamSpec*, gpointer data) {
            auto *self = static_cast<AccessPoint*>(data);
            int s = nm_access_point_get_strength(self->m_ap);
            if (self->m_strength != s) {
                self->m_strength = s;
                emit self->strengthChanged();
            }
        }), this);
}

bool AccessPoint::active() const {
    if (!m_device) return false;
    NMAccessPoint *activeAp = nm_device_wifi_get_active_access_point(m_device);
    if (!activeAp) return false;

    bool nmActive = g_strcmp0(nm_object_get_path(NM_OBJECT(m_ap)),
                              nm_object_get_path(NM_OBJECT(activeAp))) == 0;
    if (!nmActive) return false;

    Network *network = qobject_cast<Network*>(parent());
    return !(network && network->hasConnectionFailed(m_ssid));
}

void AccessPoint::updateProperties() {
    // SSID
    if (GBytes *b = nm_access_point_get_ssid(m_ap)) {
        gsize sz;
        const auto *d = static_cast<const guint8*>(g_bytes_get_data(b, &sz));
        QString v = QString::fromUtf8(reinterpret_cast<const char*>(d), sz);
        if (m_ssid != v) { m_ssid = v; emit ssidChanged(); }
    }

    // BSSID
    QString bssid = QString::fromUtf8(nm_access_point_get_bssid(m_ap));
    if (m_bssid != bssid) { m_bssid = bssid; emit bssidChanged(); }

    // Strength
    int strength = nm_access_point_get_strength(m_ap);
    if (m_strength != strength) { m_strength = strength; emit strengthChanged(); }

    // Frequency
    int freq = nm_access_point_get_frequency(m_ap);
    if (m_frequency != freq) { m_frequency = freq; emit frequencyChanged(); }

    // Security
    NM80211ApFlags       flags    = nm_access_point_get_flags(m_ap);
    NM80211ApSecurityFlags wpa   = nm_access_point_get_wpa_flags(m_ap);
    NM80211ApSecurityFlags rsn   = nm_access_point_get_rsn_flags(m_ap);

    bool secure = (flags & NM_802_11_AP_FLAGS_PRIVACY)
               || wpa != NM_802_11_AP_SEC_NONE
               || rsn != NM_802_11_AP_SEC_NONE;

    QString secType = "Open";
    if (secure) {
        if      (rsn & NM_802_11_AP_SEC_KEY_MGMT_SAE)  secType = "WPA3";
        else if (rsn & NM_802_11_AP_SEC_KEY_MGMT_PSK)  secType = "WPA2";
        else if (wpa & NM_802_11_AP_SEC_KEY_MGMT_PSK)  secType = "WPA";
        else if (flags & NM_802_11_AP_FLAGS_PRIVACY)    secType = "WEP";
        else                                            secType = "Secured";
    }

    if (m_isSecure != secure) {
        if (Network *svc = qobject_cast<Network*>(parent()); svc && m_isKnown) {
            svc->forgetNetwork(m_ssid);
            m_isKnown = false;
            emit isKnownChanged();
        }
        m_isSecure = secure;
        emit isSecureChanged();
    }
    if (m_security != secType) { m_security = secType; emit securityChanged(); }
}

void AccessPoint::setIsKnown(bool known) {
    if (m_isKnown != known) { m_isKnown = known; emit isKnownChanged(); }
}

void AccessPoint::updateAccessPoint(NMAccessPoint *newAp) {
    if (m_strengthChangedId) {
        g_signal_handler_disconnect(m_ap, m_strengthChangedId);
        m_strengthChangedId = 0;
    }
    g_object_unref(m_ap);
    m_ap = newAp;
    g_object_ref(m_ap);
    connectStrengthSignal();
    updateProperties();
}


Network::Network(QObject *parent)
    : QObject(parent), m_client(nullptr), m_wifiDevice(nullptr),
      m_active(nullptr), m_wifiEnabled(false), m_ethernet(false), m_scanning(false),
      m_connectingToSsid(""),
      m_apAddedId(0), m_apRemovedId(0), m_deviceAddedId(0), m_deviceRemovedId(0),
      m_wirelessEnabledId(0), m_activeConnectionsId(0),
      m_connectionAddedId(0), m_connectionRemovedId(0), m_deviceStateChangedId(0)
{
    GError *error = nullptr;
    m_client = nm_client_new(nullptr, &error);
    if (error) {
        qWarning() << "Failed to create NMClient:" << error->message;
        g_error_free(error);
        return;
    }

    m_wifiDevice = getPrimaryWifiDevice();

    m_deviceAddedId        = g_signal_connect(m_client, "device-added",                  G_CALLBACK(onDeviceAdded),              this);
    m_deviceRemovedId      = g_signal_connect(m_client, "device-removed",                G_CALLBACK(onDeviceRemoved),            this);
    m_wirelessEnabledId    = g_signal_connect(m_client, "notify::wireless-enabled",      G_CALLBACK(onWirelessEnabledChanged),   this);
    m_activeConnectionsId  = g_signal_connect(m_client, "notify::active-connections",    G_CALLBACK(onActiveConnectionsChanged), this);
    m_connectionAddedId    = g_signal_connect(m_client, "connection-added",              G_CALLBACK(onConnectionAdded),          this);
    m_connectionRemovedId  = g_signal_connect(m_client, "connection-removed",            G_CALLBACK(onConnectionRemoved),        this);

    if (m_wifiDevice) {
        m_apAddedId          = g_signal_connect(m_wifiDevice, "access-point-added",   G_CALLBACK(onAccessPointAdded),   this);
        m_apRemovedId        = g_signal_connect(m_wifiDevice, "access-point-removed", G_CALLBACK(onAccessPointRemoved), this);
        m_deviceStateChangedId = g_signal_connect(m_wifiDevice, "notify::state",      G_CALLBACK(onDeviceStateChanged), this);
    }

    m_wifiEnabled = nm_client_wireless_get_enabled(m_client);
    updateNetworks();
    updateEthernetStatus();
    updateActiveConnection();
    updateKnownNetworks();

    // --- Ported from Network.qml ---
    m_cacheDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/sleex/network";
    QDir().mkpath(m_cacheDir);
    loadSpeedTestCache();

    m_errorTimer.setSingleShot(true);
    connect(&m_errorTimer, &QTimer::timeout, this, [this]() { setShowConnectionError(false); });

    connect(this, &Network::connectionFailed, this, &Network::_onConnectionFailedInternal);
    connect(this, &Network::connectionSucceeded, this, &Network::_onConnectionSucceededInternal);

    connect(this, &Network::activeChanged, this, &Network::hasActiveConnectionChanged);
    connect(this, &Network::ethernetChanged, this, &Network::hasActiveConnectionChanged);
    connect(this, &Network::hasActiveConnectionChanged, this, [this]() {
        if (hasActiveConnection()) fetchNetworkInfo();
    });
    if (hasActiveConnection()) fetchNetworkInfo();
}

Network::~Network() {
    if (m_apAddedId)           g_signal_handler_disconnect(m_wifiDevice, m_apAddedId);
    if (m_apRemovedId)         g_signal_handler_disconnect(m_wifiDevice, m_apRemovedId);
    if (m_deviceStateChangedId)g_signal_handler_disconnect(m_wifiDevice, m_deviceStateChangedId);
    if (m_deviceAddedId)       g_signal_handler_disconnect(m_client, m_deviceAddedId);
    if (m_deviceRemovedId)     g_signal_handler_disconnect(m_client, m_deviceRemovedId);
    if (m_wirelessEnabledId)   g_signal_handler_disconnect(m_client, m_wirelessEnabledId);
    if (m_activeConnectionsId) g_signal_handler_disconnect(m_client, m_activeConnectionsId);
    if (m_connectionAddedId)   g_signal_handler_disconnect(m_client, m_connectionAddedId);
    if (m_connectionRemovedId) g_signal_handler_disconnect(m_client, m_connectionRemovedId);

    qDeleteAll(m_networks);
    if (m_client) g_object_unref(m_client);
}


static QString strengthToIcon(int s) {
    if (s >= 80) return "signal_wifi_4_bar";
    if (s >= 60) return "network_wifi_3_bar";
    if (s >= 40) return "network_wifi_2_bar";
    if (s >= 20) return "network_wifi_1_bar";
    return "signal_wifi_0_bar";
}

QString Network::getNetworkIcon(int strength) {
    const GPtrArray *devices = nm_client_get_devices(m_client);

    for (guint i = 0; i < devices->len; ++i) {
        NMDevice *dev = NM_DEVICE(g_ptr_array_index(devices, i));
        if (nm_device_get_state(dev) != NM_DEVICE_STATE_ACTIVATED) continue;

        switch (nm_device_get_device_type(dev)) {
        case NM_DEVICE_TYPE_WIFI:     return strengthToIcon(strength);
        case NM_DEVICE_TYPE_ETHERNET: return "lan";
        case NM_DEVICE_TYPE_BT:       return "bluetooth_connected";
        case NM_DEVICE_TYPE_MODEM:    return "router";
        case NM_DEVICE_TYPE_UNKNOWN:  return "signal_wifi_statusbar_not_connected";
        case NM_DEVICE_TYPE_DUMMY:    return "signal_wifi_bad";
        default: break;
        }
    }

    if (m_wifiEnabled) {
        for (guint i = 0; i < devices->len; ++i) {
            NMDevice *dev = NM_DEVICE(g_ptr_array_index(devices, i));
            if (nm_device_get_device_type(dev) == NM_DEVICE_TYPE_WIFI)
                return strengthToIcon(strength);
        }
    }
    return "signal_wifi_off";
}

QString Network::getWifiIcon() {
    if (!m_wifiEnabled)
        return "signal_wifi_off";

    if (m_active && m_active->active())
        return strengthToIcon(m_active->strength());

    return "signal_wifi_off";
}

void Network::enableWifi(bool enabled) {
    nm_client_dbus_set_property(m_client,
        NM_DBUS_PATH, NM_DBUS_INTERFACE, "WirelessEnabled",
        g_variant_new_boolean(enabled),
        -1, nullptr, onWifiEnabledSet, this);
}

void Network::onWifiEnabledSet(GObject *source, GAsyncResult *result, gpointer) {
    GError *error = nullptr;
    if (!nm_client_dbus_set_property_finish(NM_CLIENT(source), result, &error) || error) {
        qWarning() << "Failed to set wireless enabled:" << (error ? error->message : "no details");
        if (error) g_error_free(error);
    }
}

void Network::toggleWifi()  { enableWifi(!m_wifiEnabled); }

void Network::rescanWifi() {
    if (!m_wifiDevice || m_scanning) return;
    m_scanning = true;
    emit scanningChanged();
    nm_device_wifi_request_scan_async(m_wifiDevice, nullptr, onScanDone, this);
}

void Network::connectToNetwork(const QString &ssid, const QString &password) {
    if (!m_wifiDevice) return;

    clearConnectionFailed(ssid);

    AccessPoint *target = nullptr;
    for (auto *n : m_networks)
        if (n->ssid() == ssid) { target = n; break; }

    if (target && target->isSecure() && password.isEmpty() && !target->isKnown())
        return;

    if (m_connectingToSsid != ssid) {
        m_connectingToSsid = ssid;
        emit connectingToSsidChanged();
    }

    auto *cb = new ConnectionCallbackData{this, ssid};
    NMRemoteConnection *existing = findConnectionForSsid(ssid);

    if (existing && password.isEmpty()) {
        // Security mismatch check
        bool storedHasSec  = nm_connection_get_setting_wireless_security(NM_CONNECTION(existing)) != nullptr;
        bool networkHasSec = target ? target->isSecure() : false;

        if (storedHasSec != networkHasSec) {
            nm_remote_connection_delete_async(existing, nullptr, nullptr, nullptr);
            if (m_connectingToSsid == ssid) { m_connectingToSsid = ""; emit connectingToSsidChanged(); }
            emit passwordRequired(ssid);
            updateKnownNetworks();
            delete cb;
            return;
        }

        nm_client_activate_connection_async(m_client, NM_CONNECTION(existing),
            NM_DEVICE(m_wifiDevice), nullptr, nullptr, onConnectionActivated, cb);
        return;
    }

    // Delete stale stored connection if a new password is provided
    if (existing && !password.isEmpty())
        nm_remote_connection_delete_async(existing, nullptr, nullptr, nullptr);

    if (!target) { delete cb; return; }

    // Build new connection
    NMConnection *conn = nm_simple_connection_new();

    NMSettingConnection *s_con = NM_SETTING_CONNECTION(nm_setting_connection_new());
    g_object_set(s_con,
        NM_SETTING_CONNECTION_ID,          ssid.toUtf8().constData(),
        NM_SETTING_CONNECTION_TYPE,        NM_SETTING_WIRELESS_SETTING_NAME,
        NM_SETTING_CONNECTION_AUTOCONNECT, TRUE,
        nullptr);
    nm_connection_add_setting(conn, NM_SETTING(s_con));

    NMSettingWireless *s_wifi = NM_SETTING_WIRELESS(nm_setting_wireless_new());
    GBytes *ssidBytes = g_bytes_new(ssid.toUtf8().constData(), ssid.toUtf8().length());
    g_object_set(s_wifi,
        NM_SETTING_WIRELESS_SSID, ssidBytes,
        NM_SETTING_WIRELESS_MODE, "infrastructure",
        nullptr);
    g_bytes_unref(ssidBytes);
    nm_connection_add_setting(conn, NM_SETTING(s_wifi));

    if (!password.isEmpty()) {
        NMSettingWirelessSecurity *s_wsec = NM_SETTING_WIRELESS_SECURITY(nm_setting_wireless_security_new());
        g_object_set(s_wsec,
            NM_SETTING_WIRELESS_SECURITY_KEY_MGMT, "wpa-psk",
            NM_SETTING_WIRELESS_SECURITY_PSK,      password.toUtf8().constData(),
            nullptr);
        nm_connection_add_setting(conn, NM_SETTING(s_wsec));
    }

    nm_client_add_and_activate_connection_async(m_client, conn,
        NM_DEVICE(m_wifiDevice),
        nm_object_get_path(NM_OBJECT(target->nmAccessPoint())),
        nullptr, onConnectionAddedAndActivated, cb);
    g_object_unref(conn);
}

void Network::disconnectFromNetwork() {
    if (!m_wifiDevice) return;
    const GPtrArray *acs = nm_client_get_active_connections(m_client);
    for (guint i = 0; i < acs->len; i++) {
        NMActiveConnection *ac = NM_ACTIVE_CONNECTION(g_ptr_array_index(acs, i));
        const GPtrArray *devs = nm_active_connection_get_devices(ac);
        for (guint j = 0; j < devs->len; j++) {
            if (NM_DEVICE(g_ptr_array_index(devs, j)) == NM_DEVICE(m_wifiDevice)) {
                nm_client_deactivate_connection_async(m_client, ac, nullptr, onConnectionDeactivated, this);
                return;
            }
        }
    }
}

void Network::forgetNetwork(const QString &ssid) {
    if (NMRemoteConnection *c = findConnectionForSsid(ssid))
        nm_remote_connection_delete_async(c, nullptr, nullptr, nullptr);
}


// after a successful async initiation. Schedules staged checks.
void Network::scheduleConnectionVerification(const QString &ssid) {
    // Stage 1 – quick check at 1 s (catches immediate failures)
    QTimer::singleShot(1000, this, [this, ssid]() {
        if (!m_wifiDevice) return;

        NMDeviceState       state  = nm_device_get_state(NM_DEVICE(m_wifiDevice));
        NMDeviceStateReason reason = nm_device_get_state_reason(NM_DEVICE(m_wifiDevice));

        bool immediateFailure =
            state == NM_DEVICE_STATE_FAILED       ||
            state == NM_DEVICE_STATE_NEED_AUTH    ||
            state == NM_DEVICE_STATE_DISCONNECTED ||
            reason == NM_DEVICE_STATE_REASON_NO_SECRETS              ||
            reason == NM_DEVICE_STATE_REASON_SUPPLICANT_DISCONNECT    ||
            reason == NM_DEVICE_STATE_REASON_SUPPLICANT_CONFIG_FAILED ||
            reason == NM_DEVICE_STATE_REASON_SUPPLICANT_TIMEOUT;

        if (immediateFailure) {
            QString msg = (reason == NM_DEVICE_STATE_REASON_SUPPLICANT_TIMEOUT)
                        ? "Connection timeout - likely incorrect password"
                        : "Incorrect password";
            markConnectionFailed(ssid);
            emit connectionFailed(ssid, msg);
            updateNetworks();
            updateActiveConnection();
            return;
        }

        // Stage 2 – definitive check at 3 s (1 s + 2 s)
        QTimer::singleShot(2000, this, [this, ssid]() {
            finalizeConnectionResult(ssid);
        });
    });
}

void Network::finalizeConnectionResult(const QString &ssid) {
    bool connected = false;
    QString errorMsg = "Connection failed";

    if (m_wifiDevice) {
        NMDeviceState       state  = nm_device_get_state(NM_DEVICE(m_wifiDevice));
        NMDeviceStateReason reason = nm_device_get_state_reason(NM_DEVICE(m_wifiDevice));

        if (state == NM_DEVICE_STATE_ACTIVATED) {
            if (NMAccessPoint *ap = nm_device_wifi_get_active_access_point(m_wifiDevice)) {
                gsize sz;
                const char *d = (const char*)g_bytes_get_data(nm_access_point_get_ssid(ap), &sz);
                connected = d && QString::fromUtf8(d, sz) == ssid;
            }
        } else {
            bool authRelated =
                reason == NM_DEVICE_STATE_REASON_NO_SECRETS              ||
                reason == NM_DEVICE_STATE_REASON_SUPPLICANT_DISCONNECT    ||
                reason == NM_DEVICE_STATE_REASON_SUPPLICANT_CONFIG_FAILED ||
                reason == NM_DEVICE_STATE_REASON_SUPPLICANT_TIMEOUT;

            switch (state) {
            case NM_DEVICE_STATE_IP_CONFIG:
                errorMsg = "Getting IP address - network may be congested"; break;
            case NM_DEVICE_STATE_DISCONNECTED:
                errorMsg = authRelated ? "Incorrect password" : "Could not connect to network"; break;
            default:
                errorMsg = authRelated ? "Incorrect password"
                                       : "Authentication failed or connection timed out";
            }
        }
    }

    // Fallback: cross-check active connections list
    if (!connected) {
        const GPtrArray *acs = nm_client_get_active_connections(m_client);
        for (guint i = 0; acs && i < acs->len; i++) {
            NMActiveConnection *ac = NM_ACTIVE_CONNECTION(g_ptr_array_index(acs, i));
            const char *id = nm_active_connection_get_id(ac);
            if (id && QString::fromUtf8(id) == ssid &&
                nm_active_connection_get_state(ac) == NM_ACTIVE_CONNECTION_STATE_ACTIVATED &&
                nm_device_get_state(NM_DEVICE(m_wifiDevice)) == NM_DEVICE_STATE_ACTIVATED) {
                connected = true;
                break;
            }
        }
    }

    qDebug() << "Connection result for" << ssid << "- connected:" << connected;

    if (connected) {
        emitConnectionSucceededWithVerification(ssid);
    } else {
        markConnectionFailed(ssid);
        emit connectionFailed(ssid, errorMsg);
    }
    updateNetworks();
    updateActiveConnection();
}


void Network::onAccessPointAdded(NMDeviceWifi*, NMAccessPoint*, gpointer user_data) {
    static_cast<Network*>(user_data)->updateNetworks();
}
void Network::onAccessPointRemoved(NMDeviceWifi*, NMAccessPoint*, gpointer user_data) {
    static_cast<Network*>(user_data)->updateNetworks();
}
void Network::onDeviceAdded(NMClient*, NMDevice*, gpointer user_data) {
    static_cast<Network*>(user_data)->updateEthernetStatus();
}
void Network::onDeviceRemoved(NMClient*, NMDevice*, gpointer user_data) {
    static_cast<Network*>(user_data)->updateEthernetStatus();
}
void Network::onConnectionAdded(NMClient*, NMRemoteConnection*, gpointer user_data) {
    static_cast<Network*>(user_data)->updateKnownNetworks();
}
void Network::onConnectionRemoved(NMClient*, NMRemoteConnection*, gpointer user_data) {
    static_cast<Network*>(user_data)->updateKnownNetworks();
}

void Network::onWirelessEnabledChanged(GObject*, GParamSpec*, gpointer user_data) {
    auto *self = static_cast<Network*>(user_data);
    bool enabled = nm_client_wireless_get_enabled(self->m_client);
    if (self->m_wifiEnabled != enabled) {
        self->m_wifiEnabled = enabled;
        emit self->wifiEnabledChanged();
        emit self->wifiIconChanged();
    }
}

void Network::onActiveConnectionsChanged(GObject*, GParamSpec*, gpointer user_data) {
    static_cast<Network*>(user_data)->updateActiveConnection();
}

void Network::onScanDone(GObject*, GAsyncResult *result, gpointer user_data) {
    auto *self = static_cast<Network*>(user_data);
    GError *error = nullptr;
    nm_device_wifi_request_scan_finish(self->m_wifiDevice, result, &error);
    if (error) {
        qWarning() << "WiFi scan failed:" << error->message;
        g_error_free(error);
    } else {
        self->updateNetworks();
        self->updateKnownNetworks();
        QTimer::singleShot(500, self, [self]() { self->updateNetworks(); });
    }
    self->m_scanning = false;
    emit self->scanningChanged();
}

// Both activate callbacks share identical post-init logic via scheduleConnectionVerification.
void Network::onConnectionActivated(GObject *source, GAsyncResult *result, gpointer user_data) {
    auto *cb = static_cast<ConnectionCallbackData*>(user_data);
    Network *self = cb->network;
    QString  ssid = cb->ssid;
    delete cb;

    if (self->m_connectingToSsid == ssid) { self->m_connectingToSsid = ""; emit self->connectingToSsidChanged(); }

    GError *error = nullptr;
    NMActiveConnection *ac = nm_client_activate_connection_finish(NM_CLIENT(source), result, &error);

    if (error) {
        qWarning() << "Activation failed for" << ssid << ":" << error->message;
        self->markConnectionFailed(ssid);
        emit self->connectionFailed(ssid, QString::fromUtf8(error->message));
        g_error_free(error);
    } else if (ac) {
        self->scheduleConnectionVerification(ssid);
        g_object_unref(ac);
    } else {
        self->markConnectionFailed(ssid);
        emit self->connectionFailed(ssid, "Unknown error");
    }

    self->updateNetworks();
    self->updateActiveConnection();
    QTimer::singleShot(500, self, [self]() { self->updateNetworks(); self->updateActiveConnection(); });
}

void Network::onConnectionAddedAndActivated(GObject *source, GAsyncResult *result, gpointer user_data) {
    auto *cb = static_cast<ConnectionCallbackData*>(user_data);
    Network *self = cb->network;
    QString  ssid = cb->ssid;
    delete cb;

    if (self->m_connectingToSsid == ssid) { self->m_connectingToSsid = ""; emit self->connectingToSsidChanged(); }

    GError *error = nullptr;
    NMActiveConnection *ac = nm_client_add_and_activate_connection_finish(NM_CLIENT(source), result, &error);

    if (error) {
        qWarning() << "Add+activate failed for" << ssid << ":" << error->message;
        self->markConnectionFailed(ssid);
        emit self->connectionFailed(ssid, QString::fromUtf8(error->message));
        g_error_free(error);
    } else if (ac) {
        self->scheduleConnectionVerification(ssid);
        g_object_unref(ac);
    } else {
        self->markConnectionFailed(ssid);
        emit self->connectionFailed(ssid, "Unknown error");
    }

    self->updateNetworks();
    self->updateActiveConnection();
}

void Network::onConnectionDeactivated(GObject *source, GAsyncResult *result, gpointer user_data) {
    auto *self = static_cast<Network*>(user_data);
    GError *error = nullptr;
    nm_client_deactivate_connection_finish(NM_CLIENT(source), result, &error);
    if (error) {
        qWarning() << "Deactivation failed:" << error->message;
        g_error_free(error);
        return;
    }
    self->updateNetworks();
    self->updateActiveConnection();
}


void Network::updateNetworks() {
    if (!m_wifiDevice) return;

    const GPtrArray *aps = nm_device_wifi_get_access_points(m_wifiDevice);
    NMAccessPoint *activeAp = nm_device_wifi_get_active_access_point(m_wifiDevice);

    // Group by SSID, keeping the active or strongest AP per SSID
    QMap<QString, NMAccessPoint*> best;
    for (guint i = 0; i < aps->len; i++) {
        NMAccessPoint *ap = NM_ACCESS_POINT(g_ptr_array_index(aps, i));
        GBytes *b = nm_access_point_get_ssid(ap);
        if (!b) continue;
        gsize sz;
        const auto *d = static_cast<const guint8*>(g_bytes_get_data(b, &sz));
        QString ssid = QString::fromUtf8(reinterpret_cast<const char*>(d), sz);
        if (ssid.isEmpty()) continue;

        auto isActive = [&](NMAccessPoint *p) {
            return activeAp && g_strcmp0(nm_object_get_path(NM_OBJECT(p)),
                                         nm_object_get_path(NM_OBJECT(activeAp))) == 0;
        };

        if (!best.contains(ssid) ||
            (!isActive(best[ssid]) && (isActive(ap) ||
             nm_access_point_get_strength(ap) > nm_access_point_get_strength(best[ssid]))))
        {
            best[ssid] = ap;
        }
    }

    // Remove stale networks
    QList<AccessPoint*> toRemove;
    for (auto *n : m_networks) {
        if (!best.contains(n->ssid())) toRemove.append(n);
        else if (n->nmAccessPoint() != best[n->ssid()]) n->updateAccessPoint(best[n->ssid()]);
    }
    for (auto *n : toRemove) { m_networks.removeAll(n); n->deleteLater(); }

    // Add new networks
    for (auto *ap : best.values()) {
        if (!findAccessPoint(ap)) {
            auto *n = new AccessPoint(ap, m_wifiDevice, this);
            n->setIsKnown(m_knownSsids.contains(n->ssid()));
            m_networks.append(n);
        }
    }

    emit networksChanged();
    updateActiveConnection();
}

void Network::updateEthernetStatus() {
    bool hasEthernet = false;
    const GPtrArray *devs = nm_client_get_devices(m_client);
    for (guint i = 0; i < devs->len && !hasEthernet; i++) {
        NMDevice *dev = NM_DEVICE(g_ptr_array_index(devs, i));
        NMDeviceType type = nm_device_get_device_type(dev);
        hasEthernet = (type == NM_DEVICE_TYPE_ETHERNET || type == NM_DEVICE_TYPE_DUMMY)
                   && nm_device_get_state(dev) == NM_DEVICE_STATE_ACTIVATED;
    }
    if (m_ethernet != hasEthernet) { m_ethernet = hasEthernet; emit ethernetChanged(); }
}

void Network::updateActiveConnection() {
    AccessPoint *newActive = nullptr;
    if (m_wifiDevice) {
        if (NMAccessPoint *ap = nm_device_wifi_get_active_access_point(m_wifiDevice))
            newActive = findAccessPoint(ap);
    }

    if (m_active != newActive) {
        if (m_active) {
            emit m_active->activeChanged();
            disconnect(m_active, &AccessPoint::strengthChanged, this, &Network::wifiIconChanged);
        }
        m_active = newActive;
        if (m_active) {
            emit m_active->activeChanged();
            connect(m_active, &AccessPoint::strengthChanged, this, &Network::wifiIconChanged);
        }
        emit activeChanged();
        emit wifiIconChanged();
    }

    emit wifiIconChanged();
}

void Network::updateKnownNetworks() {
    m_knownSsids.clear();
    const GPtrArray *conns = nm_client_get_connections(m_client);
    for (guint i = 0; i < conns->len; i++) {
        NMConnection *conn = NM_CONNECTION(g_ptr_array_index(conns, i));
        NMSettingConnection *s_con = nm_connection_get_setting_connection(conn);
        if (!s_con) continue;
        if (g_strcmp0(nm_setting_connection_get_connection_type(s_con), NM_SETTING_WIRELESS_SETTING_NAME) != 0) continue;
        NMSettingWireless *s_wifi = nm_connection_get_setting_wireless(conn);
        if (!s_wifi) continue;
        GBytes *b = nm_setting_wireless_get_ssid(s_wifi);
        if (!b) continue;
        gsize sz;
        const auto *d = static_cast<const guint8*>(g_bytes_get_data(b, &sz));
        QString ssid = QString::fromUtf8(reinterpret_cast<const char*>(d), sz);
        if (!ssid.isEmpty()) m_knownSsids.append(ssid);
    }
    for (auto *n : m_networks)
        n->setIsKnown(m_knownSsids.contains(n->ssid()));
}

AccessPoint* Network::findAccessPoint(NMAccessPoint *ap) {
    const char *path = nm_object_get_path(NM_OBJECT(ap));
    for (auto *n : m_networks)
        if (g_strcmp0(nm_object_get_path(NM_OBJECT(n->nmAccessPoint())), path) == 0)
            return n;
    return nullptr;
}

NMDeviceWifi* Network::getPrimaryWifiDevice() {
    const GPtrArray *devs = nm_client_get_devices(m_client);
    for (guint i = 0; i < devs->len; i++) {
        NMDevice *dev = NM_DEVICE(g_ptr_array_index(devs, i));
        if (nm_device_get_device_type(dev) == NM_DEVICE_TYPE_WIFI)
            return NM_DEVICE_WIFI(dev);
    }
    return nullptr;
}

NMRemoteConnection* Network::findConnectionForSsid(const QString &ssid) {
    const GPtrArray *conns = nm_client_get_connections(m_client);
    for (guint i = 0; i < conns->len; i++) {
        NMConnection *conn = NM_CONNECTION(g_ptr_array_index(conns, i));
        NMSettingConnection *s_con = nm_connection_get_setting_connection(conn);
        if (!s_con) continue;
        if (g_strcmp0(nm_setting_connection_get_connection_type(s_con), NM_SETTING_WIRELESS_SETTING_NAME) != 0) continue;
        NMSettingWireless *s_wifi = nm_connection_get_setting_wireless(conn);
        if (!s_wifi) continue;
        GBytes *b = nm_setting_wireless_get_ssid(s_wifi);
        if (!b) continue;
        gsize sz;
        const auto *d = static_cast<const guint8*>(g_bytes_get_data(b, &sz));
        if (QString::fromUtf8(reinterpret_cast<const char*>(d), sz) == ssid)
            return NM_REMOTE_CONNECTION(g_ptr_array_index(conns, i));
    }
    return nullptr;
}

void Network::emitConnectionSucceededWithVerification(const QString &ssid) {
    clearConnectionFailed(ssid);
    m_authErrorEmitted.removeAll(ssid);
    emit connectionSucceeded(ssid);
    emit wifiIconChanged();
    QTimer::singleShot(5000, this, [this, ssid]() { verifyDelayedConnection(ssid); });
}

void Network::verifyDelayedConnection(const QString &ssid) {
    bool ok = false;
    QString errorMsg = "Incorrect password";

    if (m_wifiDevice && nm_device_get_state(NM_DEVICE(m_wifiDevice)) == NM_DEVICE_STATE_ACTIVATED) {
        if (NMAccessPoint *ap = nm_device_wifi_get_active_access_point(m_wifiDevice)) {
            gsize sz;
            const char *d = (const char*)g_bytes_get_data(nm_access_point_get_ssid(ap), &sz);
            ok = d && QString::fromUtf8(d, sz) == ssid;
        }
    }

    qDebug() << "5s verification for" << ssid << "- ok:" << ok;
    if (!ok) {
        emit connectionFailed(ssid, errorMsg);
        emit wifiIconChanged();
        updateNetworks();
        updateActiveConnection();
    }
}

void Network::onDeviceStateChanged(GObject*, GParamSpec*, gpointer user_data) {
    auto *self = static_cast<Network*>(user_data);
    if (!self->m_wifiDevice) return;

    NMDeviceState       state  = nm_device_get_state(NM_DEVICE(self->m_wifiDevice));
    NMDeviceStateReason reason = nm_device_get_state_reason(NM_DEVICE(self->m_wifiDevice));

    bool authFailure =
        (state == NM_DEVICE_STATE_FAILED       ||
         state == NM_DEVICE_STATE_DISCONNECTED ||
         state == NM_DEVICE_STATE_NEED_AUTH)   &&
        (reason == NM_DEVICE_STATE_REASON_NO_SECRETS              ||
         reason == NM_DEVICE_STATE_REASON_SUPPLICANT_DISCONNECT    ||
         reason == NM_DEVICE_STATE_REASON_SUPPLICANT_CONFIG_FAILED ||
         reason == NM_DEVICE_STATE_REASON_SUPPLICANT_TIMEOUT);

    if (!authFailure) return;

    // Determine which SSID failed
    QString failedSsid = self->m_connectingToSsid;
    if (failedSsid.isEmpty()) {
        if (NMAccessPoint *ap = nm_device_wifi_get_active_access_point(self->m_wifiDevice)) {
            gsize sz;
            const char *d = (const char*)g_bytes_get_data(nm_access_point_get_ssid(ap), &sz);
            if (d) failedSsid = QString::fromUtf8(d, sz);
        }
    }
    if (!failedSsid.isEmpty())
        self->emitConnectionFailedOnce(failedSsid, "Incorrect password", true);
}

void Network::markConnectionFailed(const QString &ssid) {
    if (!ssid.isEmpty() && !m_failedConnections.contains(ssid))
        m_failedConnections.append(ssid);
}

void Network::clearConnectionFailed(const QString &ssid) {
    m_failedConnections.removeAll(ssid);
    m_authErrorEmitted.removeAll(ssid);
}

void Network::emitConnectionFailedOnce(const QString &ssid, const QString &message, bool isAuthError) {
    if (m_authErrorEmitted.contains(ssid)) return; // already emitted auth error → suppress all
    markConnectionFailed(ssid);
    emit connectionFailed(ssid, message);
    if (isAuthError) m_authErrorEmitted.append(ssid);
    updateNetworks();
    updateActiveConnection();
}

bool Network::hasConnectionFailed(const QString &ssid) const {
    return m_failedConnections.contains(ssid);
}


// =====================================================================
// Ported from the deprecated Network.qml QML wrapper. Everything below
// this point used to live in QML/JS driving `Process` items; it is now
// owned entirely by this singleton, using QProcess for the same
// nmcli/curl/qrencode shell invocations.
// =====================================================================

bool Network::hasActiveConnection() const {
    return m_active != nullptr || m_ethernet;
}

void Network::setLastConnectionError(const QString &v) {
    if (m_lastConnectionError == v) return;
    m_lastConnectionError = v;
    emit lastConnectionErrorChanged();
}
void Network::setErrorSsid(const QString &v) {
    if (m_errorSsid == v) return;
    m_errorSsid = v;
    emit errorSsidChanged();
}
void Network::setShowConnectionError(bool v) {
    if (m_showConnectionError == v) return;
    m_showConnectionError = v;
    emit showConnectionErrorChanged();
}

void Network::_onConnectionFailedInternal(const QString &ssid, const QString &error) {
    setLastConnectionError(error);
    setErrorSsid(ssid);
    setShowConnectionError(true);
    m_errorTimer.start(5000);
}

void Network::_onConnectionSucceededInternal(const QString &ssid) {
    Q_UNUSED(ssid);
    setShowConnectionError(false);
    setLastConnectionError(QString());
    setErrorSsid(QString());
    fetchNetworkInfo();
}

// --- Connection info (local IP / gateway / DNS / public IP) ---

void Network::setLocalIp(const QString &v)    { if (m_localIp != v)    { m_localIp = v;    emit localIpChanged(); } }
void Network::setGatewayIp(const QString &v)  { if (m_gatewayIp != v)  { m_gatewayIp = v;  emit gatewayIpChanged(); } }
void Network::setDnsServers(const QString &v) { if (m_dnsServers != v) { m_dnsServers = v; emit dnsServersChanged(); } }
void Network::setPublicIp(const QString &v)   { if (m_publicIp != v)   { m_publicIp = v;   emit publicIpChanged(); } }
void Network::setNetInfoError(const QString &v) { if (m_netInfoError != v) { m_netInfoError = v; emit netInfoErrorChanged(); } }

void Network::beginInfoFetch() {
    if (m_activeInfoProcesses == 0) emit fetchingNetworkInfoChanged();
    m_activeInfoProcesses++;
}
void Network::endInfoFetch() {
    m_activeInfoProcesses = qMax(0, m_activeInfoProcesses - 1);
    if (m_activeInfoProcesses == 0) emit fetchingNetworkInfoChanged();
}

void Network::fetchNetworkInfo() {
    if (!hasActiveConnection()) return;
    setNetInfoError(QString());

    beginInfoFetch();
    auto *localProc = new QProcess(this);
    connect(localProc, qOverload<int, QProcess::ExitStatus>(&QProcess::finished), this,
        [this, localProc](int exitCode, QProcess::ExitStatus) {
            const QString out   = QString::fromUtf8(localProc->readAllStandardOutput());
            const auto     parts = out.split("||");
            const QString route = parts.value(0).trimmed();
            const QString dns   = parts.value(1).trimmed();

            static const QRegularExpression srcRe("src\\s+(\\S+)");
            static const QRegularExpression viaRe("via\\s+(\\S+)");
            const auto srcMatch = srcRe.match(route);
            const auto viaMatch = viaRe.match(route);

            setLocalIp(srcMatch.hasMatch() ? srcMatch.captured(1) : QStringLiteral("—"));
            setGatewayIp(viaMatch.hasMatch() ? viaMatch.captured(1) : QStringLiteral("—"));

            // Skip clobbering the display while a DNS apply is in flight; Config's
            // dnsSwitch preference (whether to keep showing the custom value) is a
            // QML/UI concern and is applied on top of this in the settings page.
            if (!m_dnsApplying)
                setDnsServers(dns.isEmpty() ? QStringLiteral("—") : dns);

            if (exitCode != 0) setNetInfoError("Couldn't read local network info");
            localProc->deleteLater();
            endInfoFetch();
        });
    localProc->start("bash", {"-c",
        "ip -4 route get 1.1.1.1 2>/dev/null | head -n1; echo '||'; "
        "awk '/^nameserver/{print $2}' /etc/resolv.conf 2>/dev/null | paste -sd ',' -"});

    beginInfoFetch();
    auto *publicProc = new QProcess(this);
    connect(publicProc, qOverload<int, QProcess::ExitStatus>(&QProcess::finished), this,
        [this, publicProc](int exitCode, QProcess::ExitStatus) {
            const QString v = QString::fromUtf8(publicProc->readAllStandardOutput()).trimmed();
            setPublicIp(exitCode == 0 && !v.isEmpty() ? v : QStringLiteral("—"));
            publicProc->deleteLater();
            endInfoFetch();
        });
    publicProc->start("bash", {"-c", "curl --max-time 6 -s https://api.ipify.org"});
}

// --- Custom DNS ---

void Network::setDnsApplying(bool v)          { if (m_dnsApplying != v)   { m_dnsApplying = v;   emit dnsApplyingChanged(); } }
void Network::setDnsApplyError(const QString &v) { if (m_dnsApplyError != v) { m_dnsApplyError = v; emit dnsApplyErrorChanged(); } }

QVariantList Network::dnsProviders() const {
    return staticDnsProviders();
}

QVariantMap Network::providerById(const QString &id) const {
    for (const QVariant &v : staticDnsProviders()) {
        const QVariantMap m = v.toMap();
        if (m.value("id").toString() == id) return m;
    }
    return staticDnsProviders().first().toMap();
}

void Network::applyDnsSettings(bool enabled, const QString &providerId) {
    if (!m_active) return;
    m_pendingDnsEnabled    = enabled;
    m_pendingDnsProviderId = providerId;

    if (m_dnsApplying) {
        // Re-run once the in-flight apply finishes instead of dropping this change
        m_dnsReapplyQueued = true;
        return;
    }

    setDnsApplyError(QString());
    setDnsServers(enabled ? providerById(providerId).value("servers").toString() : QStringLiteral("—"));
    setDnsApplying(true);

    auto *findProc = new QProcess(this);
    connect(findProc, qOverload<int, QProcess::ExitStatus>(&QProcess::finished), this,
        [this, findProc](int exitCode, QProcess::ExitStatus) {
            const QString out   = QString::fromUtf8(findProc->readAllStandardOutput()).trimmed();
            const auto     parts  = out.split('|');
            const QString name   = parts.value(0);
            const QString device = parts.value(1);
            findProc->deleteLater();

            if (exitCode != 0 || name.isEmpty() || device.isEmpty()) {
                setDnsApplyError("Couldn't find the active connection");
                setDnsApplying(false);
                if (m_dnsReapplyQueued) {
                    m_dnsReapplyQueued = false;
                    applyDnsSettings(m_pendingDnsEnabled, m_pendingDnsProviderId);
                }
                return;
            }

            const QString escName   = QString(name).replace("\"", "\\\"");
            const QString escDevice = QString(device).replace("\"", "\\\"");
            const QString reapply   = QString("(nmcli device reapply \"%1\" || nmcli connection up \"%2\")")
                                           .arg(escDevice, escName);
            const QString cmd = m_pendingDnsEnabled
                ? QString("nmcli connection modify \"%1\" ipv4.ignore-auto-dns yes ipv4.dns \"%2\" && %3")
                      .arg(escName, providerById(m_pendingDnsProviderId).value("servers").toString(), reapply)
                : QString("nmcli connection modify \"%1\" ipv4.ignore-auto-dns no ipv4.dns \"\" && %2")
                      .arg(escName, reapply);

            auto *modProc = new QProcess(this);
            connect(modProc, qOverload<int, QProcess::ExitStatus>(&QProcess::finished), this,
                [this, modProc](int exitCode, QProcess::ExitStatus) {
                    modProc->deleteLater();
                    setDnsApplying(false);
                    if (exitCode != 0) setDnsApplyError("Failed to apply DNS settings");
                    QTimer::singleShot(0, this, [this]() { fetchNetworkInfo(); });
                    if (m_dnsReapplyQueued) {
                        m_dnsReapplyQueued = false;
                        applyDnsSettings(m_pendingDnsEnabled, m_pendingDnsProviderId);
                    }
                });
            modProc->start("bash", {"-c", cmd});
        });
    findProc->start("bash", {"-c",
        "nmcli -t -f NAME,DEVICE,TYPE connection show --active 2>/dev/null | "
        "awk -F: '$3==\"802-11-wireless\"{print $1\"|\"$2; exit}'"});
}

// --- Speed test ---

void Network::setSpeedTestRunning(bool v)        { if (m_speedTestRunning != v)   { m_speedTestRunning = v;   emit speedTestRunningChanged(); } }
void Network::setSpeedTestStage(const QString &v){ if (m_speedTestStage != v)     { m_speedTestStage = v;     emit speedTestStageChanged(); } }
void Network::setSpeedTestPingMs(double v)       { if (m_speedTestPingMs != v)    { m_speedTestPingMs = v;    emit speedTestPingMsChanged(); } }
void Network::setSpeedTestDownloadMbps(double v) { if (m_speedTestDownloadMbps != v) { m_speedTestDownloadMbps = v; emit speedTestDownloadMbpsChanged(); } }
void Network::setSpeedTestUploadMbps(double v)   { if (m_speedTestUploadMbps != v)   { m_speedTestUploadMbps = v;   emit speedTestUploadMbpsChanged(); } }
void Network::setSpeedTestError(const QString &v){ if (m_speedTestError != v)     { m_speedTestError = v;     emit speedTestErrorChanged(); } }
void Network::setSpeedTestSsid(const QString &v) { if (m_speedTestSsid != v)      { m_speedTestSsid = v;      emit speedTestSsidChanged(); } }

void Network::loadSpeedTestCache() {
    QFile f(m_cacheDir + "/network.json");
    if (!f.open(QIODevice::ReadOnly)) { m_speedTestResults = QVariantMap(); return; }
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
    f.close();
    m_speedTestResults = doc.isObject() ? doc.object().toVariantMap() : QVariantMap();
}

void Network::cacheSpeedTestResult(const QString &ssid) {
    if (ssid.isEmpty()) return;
    QVariantMap entry;
    entry["pingMs"]       = m_speedTestPingMs;
    entry["downloadMbps"] = m_speedTestDownloadMbps;
    entry["uploadMbps"]   = m_speedTestUploadMbps;
    m_speedTestResults[ssid] = entry;
    emit speedTestResultsChanged();

    QFile f(m_cacheDir + "/network.json");
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        f.write(QJsonDocument(QJsonObject::fromVariantMap(m_speedTestResults)).toJson(QJsonDocument::Indented));
        f.close();
    }
}

void Network::startSpeedTest() {
    if (m_speedTestRunning) return;
    setSpeedTestSsid(m_active ? m_active->ssid() : QString());
    setSpeedTestRunning(true);
    setSpeedTestStage("ping");
    setSpeedTestPingMs(-1);
    setSpeedTestDownloadMbps(-1);
    setSpeedTestUploadMbps(-1);
    setSpeedTestError(QString());

    auto *proc = new QProcess(this);
    connect(proc, qOverload<int, QProcess::ExitStatus>(&QProcess::finished), this,
        [this, proc](int exitCode, QProcess::ExitStatus) {
            const QString out = QString::fromUtf8(proc->readAllStandardOutput());
            proc->deleteLater();
            bool ok = false;
            const double v = out.toDouble(&ok);
            if (exitCode != 0 || !ok) {
                setSpeedTestError("Couldn't reach the network (ping failed)");
                setSpeedTestStage("error");
                setSpeedTestRunning(false);
                cacheSpeedTestResult(m_speedTestSsid);
                return;
            }
            setSpeedTestPingMs(v * 1000.0);
            setSpeedTestStage("download");
            runSpeedTestDownload();
        });
    proc->start("bash", {"-c",
        "LC_ALL=C curl --max-time 10 -o /dev/null -s -w '%{time_connect}' "
        "'https://speed.cloudflare.com/__down?bytes=0'"});
}

void Network::runSpeedTestDownload() {
    auto *proc = new QProcess(this);
    connect(proc, qOverload<int, QProcess::ExitStatus>(&QProcess::finished), this,
        [this, proc](int exitCode, QProcess::ExitStatus) {
            const QString out = QString::fromUtf8(proc->readAllStandardOutput());
            proc->deleteLater();
            bool ok = false;
            const double v = out.toDouble(&ok);
            if (exitCode != 0 || !ok) {
                setSpeedTestError("Download test failed");
                setSpeedTestStage("error");
                setSpeedTestRunning(false);
                cacheSpeedTestResult(m_speedTestSsid);
                return;
            }
            setSpeedTestDownloadMbps((v * 8) / 1000000.0);
            setSpeedTestStage("upload");
            runSpeedTestUpload();
        });
    proc->start("bash", {"-c",
        "LC_ALL=C curl --max-time 20 -o /dev/null -s -w '%{speed_download}' "
        "'https://speed.cloudflare.com/__down?bytes=25000000'"});
}

void Network::runSpeedTestUpload() {
    auto *proc = new QProcess(this);
    connect(proc, qOverload<int, QProcess::ExitStatus>(&QProcess::finished), this,
        [this, proc](int exitCode, QProcess::ExitStatus) {
            const QString out = QString::fromUtf8(proc->readAllStandardOutput());
            proc->deleteLater();
            bool ok = false;
            const double v = out.toDouble(&ok);
            setSpeedTestStage(exitCode != 0 ? "error" : "done");
            setSpeedTestRunning(false);
            if (exitCode != 0 || !ok) setSpeedTestError("Upload test failed");
            else setSpeedTestUploadMbps((v * 8) / 1000000.0);
            cacheSpeedTestResult(m_speedTestSsid);
        });
    proc->start("bash", {"-c",
        "LC_ALL=C curl --max-time 20 -X POST -s -o /dev/null -w '%{speed_upload}' "
        "--data-binary @<(head -c 8000000 /dev/urandom) 'https://speed.cloudflare.com/__up'"});
}

// --- WiFi QR code sharing ---

void Network::setQrGenerating(bool v)         { if (m_qrGenerating != v) { m_qrGenerating = v; emit qrGeneratingChanged(); } }
void Network::setQrImagePath(const QString &v){ if (m_qrImagePath != v)  { m_qrImagePath = v;  emit qrImagePathChanged(); } }
void Network::setQrError(const QString &v)    { if (m_qrError != v)      { m_qrError = v;      emit qrErrorChanged(); } }
void Network::setQrActiveSsid(const QString &v){ if (m_qrActiveSsid != v){ m_qrActiveSsid = v;  emit qrActiveSsidChanged(); } }

void Network::clearQrCode() {
    setQrActiveSsid(QString());
    setQrImagePath(QString());
    setQrError(QString());
}

void Network::generateQrCode(const QString &ssid, const QString &securityStr) {
    setQrActiveSsid(ssid);
    setQrGenerating(true);
    setQrImagePath(QString());
    setQrError(QString());

    const QString sec = securityStr.toLower();
    if (sec.isEmpty() || sec == "none" || sec == "--") {
        encodeQr(ssid, QString(), "nopass");
        return;
    }

    auto *proc = new QProcess(this);
    connect(proc, qOverload<int, QProcess::ExitStatus>(&QProcess::finished), this,
        [this, proc](int exitCode, QProcess::ExitStatus) {
            const QString pw = QString::fromUtf8(proc->readAllStandardOutput()).trimmed();
            proc->deleteLater();
            if (exitCode != 0 || pw.isEmpty()) {
                setQrError("Couldn't retrieve the stored WiFi password.\n"
                           "Ensure NetworkManager has this connection saved with a password.");
                setQrGenerating(false);
                return;
            }
            const QString sec2     = m_active ? m_active->security().toLower() : QString();
            const QString authType = sec2.contains("wep") ? "WEP" : "WPA";
            encodeQr(m_qrActiveSsid, pw, authType);
        });
    proc->start("bash", {"-c",
        "nmcli -s -g 802-11-wireless-security.psk connection show "
        "\"$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | "
        "awk -F: '$2==\"802-11-wireless\"{print $1; exit}')\" 2>/dev/null"});
}

void Network::encodeQr(const QString &ssid, const QString &password, const QString &authType) {
    auto esc = [](QString s) {
        return s.replace("\\", "\\\\")
                .replace(";", "\\;")
                .replace(",", "\\,")
                .replace("\"", "\\\"")
                .replace(":", "\\:");
    };
    const QString content = "WIFI:T:" + authType + ";S:" + esc(ssid) + ";P:" + esc(password) + ";;";
    QString shellArg = content;
    shellArg.replace("'", "'\\''");
    // QString::arg() only substitutes %1-%99 (digit-prefixed placeholders), so
    // plain '%s' here is untouched by .arg() - no need to (wrongly) escape it
    // to '%%s', which made bash's own printf swallow the '%' and print a
    // literal "%s" instead of the QR content.
    const QString cmd = QString("printf '%s' '%1' | qrencode -o /tmp/sleex_wifi_qr.png -s 8 -m 4").arg(shellArg);

    auto *proc = new QProcess(this);
    connect(proc, qOverload<int, QProcess::ExitStatus>(&QProcess::finished), this,
        [this, proc](int exitCode, QProcess::ExitStatus) {
            proc->deleteLater();
            setQrGenerating(false);
            if (exitCode != 0) {
                setQrError("QR generation failed. Is 'qrencode' installed?\n(sudo pacman -S qrencode)");
                return;
            }
            setQrImagePath(QString());
            QTimer::singleShot(0, this, [this]() { setQrImagePath("file:///tmp/sleex_wifi_qr.png"); });
        });
    proc->start("bash", {"-c", cmd});
}

} // namespace sleex::services
