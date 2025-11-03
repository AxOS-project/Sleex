#include "network.hpp"
#include <QDebug>
#include <QByteArray>

namespace sleex::services {

// AccessPoint implementation
AccessPoint::AccessPoint(NMAccessPoint *ap, NMDeviceWifi *device, QObject *parent)
    : QObject(parent), m_ap(ap), m_device(device), m_isKnown(false) {
    
    g_object_ref(m_ap);
    
    updateProperties();
    
    // Connect to strength changes
    m_strengthChangedId = g_signal_connect(m_ap, "notify::strength",
                                          G_CALLBACK(+[](GObject*, GParamSpec*, gpointer data) {
        auto *self = static_cast<AccessPoint*>(data);
        int newStrength = nm_access_point_get_strength(self->m_ap);
        if (self->m_strength != newStrength) {
            self->m_strength = newStrength;
            emit self->strengthChanged();
        }
    }), this);
}

AccessPoint::~AccessPoint() {
    if (m_strengthChangedId) {
        g_signal_handler_disconnect(m_ap, m_strengthChangedId);
    }
    g_object_unref(m_ap);
}

bool AccessPoint::active() const {
    if (!m_device) return false;
    
    NMAccessPoint *activeAp = nm_device_wifi_get_active_access_point(m_device);
    if (!activeAp) return false;
    
    return g_strcmp0(nm_object_get_path(NM_OBJECT(m_ap)), 
                     nm_object_get_path(NM_OBJECT(activeAp))) == 0;
}

void AccessPoint::updateProperties() {
    // SSID
    GBytes *ssidBytes = nm_access_point_get_ssid(m_ap);
    if (ssidBytes) {
        gsize size;
        const guint8 *data = static_cast<const guint8*>(g_bytes_get_data(ssidBytes, &size));
        QString newSsid = QString::fromUtf8(reinterpret_cast<const char*>(data), size);
        if (m_ssid != newSsid) {
            m_ssid = newSsid;
            emit ssidChanged();
        }
    }
    
    // BSSID
    QString newBssid = QString::fromUtf8(nm_access_point_get_bssid(m_ap));
    if (m_bssid != newBssid) {
        m_bssid = newBssid;
        emit bssidChanged();
    }
    
    // Strength
    int newStrength = nm_access_point_get_strength(m_ap);
    if (m_strength != newStrength) {
        m_strength = newStrength;
        emit strengthChanged();
    }
    
    // Frequency
    int newFrequency = nm_access_point_get_frequency(m_ap);
    if (m_frequency != newFrequency) {
        m_frequency = newFrequency;
        emit frequencyChanged();
    }
    
    // Security
    NM80211ApFlags flags = nm_access_point_get_flags(m_ap);
    NM80211ApSecurityFlags wpaFlags = nm_access_point_get_wpa_flags(m_ap);
    NM80211ApSecurityFlags rsnFlags = nm_access_point_get_rsn_flags(m_ap);
    
    bool newIsSecure = (flags & NM_802_11_AP_FLAGS_PRIVACY) || 
                       wpaFlags != NM_802_11_AP_SEC_NONE || 
                       rsnFlags != NM_802_11_AP_SEC_NONE;
    
    if (m_isSecure != newIsSecure) {
        m_isSecure = newIsSecure;
        emit isSecureChanged();
    }
}

void AccessPoint::setIsKnown(bool known) {
    if (m_isKnown != known) {
        m_isKnown = known;
        emit isKnownChanged();
    }
}

// Network implementation
Network::Network(QObject *parent) 
    : QObject(parent), m_client(nullptr), m_wifiDevice(nullptr), 
      m_active(nullptr), m_wifiEnabled(false), m_ethernet(false), m_scanning(false),
      m_apAddedId(0), m_apRemovedId(0), m_deviceAddedId(0), m_deviceRemovedId(0),
      m_wirelessEnabledId(0), m_activeConnectionsId(0), 
      m_connectionAddedId(0), m_connectionRemovedId(0) {
    
    // Initialize NetworkManager client
    GError *error = nullptr;
    m_client = nm_client_new(nullptr, &error);
    
    if (error) {
        qWarning() << "Failed to create NMClient:" << error->message;
        g_error_free(error);
        return;
    }
    
    // Get primary wifi device
    m_wifiDevice = getPrimaryWifiDevice();
    
    // Connect signals
    m_deviceAddedId = g_signal_connect(m_client, "device-added",
                                      G_CALLBACK(onDeviceAdded), this);
    m_deviceRemovedId = g_signal_connect(m_client, "device-removed",
                                        G_CALLBACK(onDeviceRemoved), this);
    m_wirelessEnabledId = g_signal_connect(m_client, "notify::wireless-enabled",
                                          G_CALLBACK(onWirelessEnabledChanged), this);
    m_activeConnectionsId = g_signal_connect(m_client, "notify::active-connections",
                                            G_CALLBACK(onActiveConnectionsChanged), this);
    m_connectionAddedId = g_signal_connect(m_client, "connection-added",
                                          G_CALLBACK(onConnectionAdded), this);
    m_connectionRemovedId = g_signal_connect(m_client, "connection-removed",
                                            G_CALLBACK(onConnectionRemoved), this);
    
    if (m_wifiDevice) {
        m_apAddedId = g_signal_connect(m_wifiDevice, "access-point-added",
                                       G_CALLBACK(onAccessPointAdded), this);
        m_apRemovedId = g_signal_connect(m_wifiDevice, "access-point-removed",
                                        G_CALLBACK(onAccessPointRemoved), this);
    }
    
    // Initial state
    m_wifiEnabled = nm_client_wireless_get_enabled(m_client);
    updateNetworks();
    updateEthernetStatus();
    updateActiveConnection();
    updateKnownNetworks();
}

Network::~Network() {
    // Disconnect all signals
    if (m_apAddedId) g_signal_handler_disconnect(m_wifiDevice, m_apAddedId);
    if (m_apRemovedId) g_signal_handler_disconnect(m_wifiDevice, m_apRemovedId);
    if (m_deviceAddedId) g_signal_handler_disconnect(m_client, m_deviceAddedId);
    if (m_deviceRemovedId) g_signal_handler_disconnect(m_client, m_deviceRemovedId);
    if (m_wirelessEnabledId) g_signal_handler_disconnect(m_client, m_wirelessEnabledId);
    if (m_activeConnectionsId) g_signal_handler_disconnect(m_client, m_activeConnectionsId);
    if (m_connectionAddedId) g_signal_handler_disconnect(m_client, m_connectionAddedId);
    if (m_connectionRemovedId) g_signal_handler_disconnect(m_client, m_connectionRemovedId);
    
    // Clean up
    qDeleteAll(m_networks);
    if (m_client) g_object_unref(m_client);
}

QString Network::getNetworkIcon(int strength) {
    if (m_ethernet) {
        return "lan";
    }
    
    if (strength >= 80) return "signal_wifi_4_bar";
    else if (strength >= 60) return "network_wifi_3_bar";
    else if (strength >= 40) return "network_wifi_2_bar";
    else if (strength >= 20) return "network_wifi_1_bar";
    else if (strength >= 0) return "signal_wifi_0_bar";
    else return "settings_ethernet";
}

void Network::enableWifi(bool enabled) {
    nm_client_wireless_set_enabled(m_client, enabled);
}

void Network::toggleWifi() {
    enableWifi(!m_wifiEnabled);
}

void Network::rescanWifi() {
    if (!m_wifiDevice || m_scanning) return;
    
    m_scanning = true;
    emit scanningChanged();
    
    nm_device_wifi_request_scan_async(m_wifiDevice, nullptr, onScanDone, this);
}

void Network::connectToNetwork(const QString &ssid, const QString &password) {
    if (!m_wifiDevice) return;
    
    // Check if it's a known connection
    NMRemoteConnection *connection = findConnectionForSsid(ssid);
    
    if (connection) {
        // Activate existing connection
        nm_client_activate_connection_async(
            m_client,
            NM_CONNECTION(connection),
            NM_DEVICE(m_wifiDevice),
            nullptr,
            nullptr,
            onConnectionActivated,
            this
        );
    } else {
        // Find the access point
        AccessPoint *ap = nullptr;
        for (auto *network : m_networks) {
            if (network->ssid() == ssid) {
                ap = network;
                break;
            }
        }
        
        if (!ap) return;
        
        // Create new connection settings
        NMConnection *newConnection = nm_simple_connection_new();
        
        // Connection settings
        NMSettingConnection *s_con = (NMSettingConnection*)nm_setting_connection_new();
        g_object_set(s_con,
                    NM_SETTING_CONNECTION_ID, ssid.toUtf8().constData(),
                    NM_SETTING_CONNECTION_TYPE, NM_SETTING_WIRELESS_SETTING_NAME,
                    NM_SETTING_CONNECTION_AUTOCONNECT, TRUE,
                    nullptr);
        nm_connection_add_setting(newConnection, NM_SETTING(s_con));
        
        // Wireless settings
        NMSettingWireless *s_wifi = (NMSettingWireless*)nm_setting_wireless_new();
        GBytes *ssidBytes = g_bytes_new(ssid.toUtf8().constData(), ssid.toUtf8().length());
        g_object_set(s_wifi,
                    NM_SETTING_WIRELESS_SSID, ssidBytes,
                    NM_SETTING_WIRELESS_MODE, "infrastructure",
                    nullptr);
        g_bytes_unref(ssidBytes);
        nm_connection_add_setting(newConnection, NM_SETTING(s_wifi));
        
        // Security settings if password provided
        if (!password.isEmpty()) {
            NMSettingWirelessSecurity *s_wsec = (NMSettingWirelessSecurity*)nm_setting_wireless_security_new();
            g_object_set(s_wsec,
                        NM_SETTING_WIRELESS_SECURITY_KEY_MGMT, "wpa-psk",
                        NM_SETTING_WIRELESS_SECURITY_PSK, password.toUtf8().constData(),
                        nullptr);
            nm_connection_add_setting(newConnection, NM_SETTING(s_wsec));
        }
        
        // Add and activate
        nm_client_add_and_activate_connection_async(
            m_client,
            NM_CONNECTION(newConnection),
            NM_DEVICE(m_wifiDevice),
            nm_object_get_path(NM_OBJECT(ap->nmAccessPoint())),
            nullptr,
            onConnectionActivated,
            this
        );
        g_object_unref(newConnection);
    }
}

void Network::disconnectFromNetwork() {
    if (!m_wifiDevice) return;
    
    const GPtrArray *activeConnections = nm_client_get_active_connections(m_client);
    for (guint i = 0; i < activeConnections->len; i++) {
        NMActiveConnection *ac = NM_ACTIVE_CONNECTION(g_ptr_array_index(activeConnections, i));
        const GPtrArray *devices = nm_active_connection_get_devices(ac);
        
        for (guint j = 0; j < devices->len; j++) {
            if (NM_DEVICE(g_ptr_array_index(devices, j)) == NM_DEVICE(m_wifiDevice)) {
                nm_client_deactivate_connection_async(m_client, ac, nullptr,
                                                     onConnectionDeactivated, this);
                return;
            }
        }
    }
}

void Network::forgetNetwork(const QString &ssid) {
    NMRemoteConnection *connection = findConnectionForSsid(ssid);
    if (connection) {
        nm_remote_connection_delete_async(connection, nullptr, nullptr, nullptr);
    }
}

// Static callbacks
void Network::onAccessPointAdded(NMDeviceWifi *device, NMAccessPoint *ap, gpointer user_data) {
    Q_UNUSED(device);
    Q_UNUSED(ap);
    auto *self = static_cast<Network*>(user_data);
    self->updateNetworks();
}

void Network::onAccessPointRemoved(NMDeviceWifi *device, NMAccessPoint *ap, gpointer user_data) {
    Q_UNUSED(device);
    Q_UNUSED(ap);
    auto *self = static_cast<Network*>(user_data);
    self->updateNetworks();
}

void Network::onDeviceAdded(NMClient *client, NMDevice *device, gpointer user_data) {
    Q_UNUSED(client);
    Q_UNUSED(device);
    auto *self = static_cast<Network*>(user_data);
    self->updateEthernetStatus();
}

void Network::onDeviceRemoved(NMClient *client, NMDevice *device, gpointer user_data) {
    Q_UNUSED(client);
    Q_UNUSED(device);
    auto *self = static_cast<Network*>(user_data);
    self->updateEthernetStatus();
}

void Network::onWirelessEnabledChanged(GObject *object, GParamSpec *pspec, gpointer user_data) {
    Q_UNUSED(object);
    Q_UNUSED(pspec);
    auto *self = static_cast<Network*>(user_data);
    bool enabled = nm_client_wireless_get_enabled(self->m_client);
    if (self->m_wifiEnabled != enabled) {
        self->m_wifiEnabled = enabled;
        emit self->wifiEnabledChanged();
    }
}

void Network::onActiveConnectionsChanged(GObject *object, GParamSpec *pspec, gpointer user_data) {
    Q_UNUSED(object);
    Q_UNUSED(pspec);
    auto *self = static_cast<Network*>(user_data);
    self->updateActiveConnection();
}

void Network::onScanDone(GObject *source, GAsyncResult *result, gpointer user_data) {
    Q_UNUSED(source);
    auto *self = static_cast<Network*>(user_data);
    
    GError *error = nullptr;
    nm_device_wifi_request_scan_finish(self->m_wifiDevice, result, &error);
    
    if (error) {
        qWarning() << "WiFi scan failed:" << error->message;
        g_error_free(error);
    }
    
    self->m_scanning = false;
    emit self->scanningChanged();
}

void Network::onConnectionActivated(GObject *source, GAsyncResult *result, gpointer user_data) {
    Q_UNUSED(user_data);
    auto *client = NM_CLIENT(source);
    
    GError *error = nullptr;
    NMActiveConnection *ac = nm_client_activate_connection_finish(client, result, &error);
    
    if (error) {
        qWarning() << "Connection activation failed:" << error->message;
        g_error_free(error);
    } else if (ac) {
        g_object_unref(ac);
    }
}

void Network::onConnectionDeactivated(GObject *source, GAsyncResult *result, gpointer user_data) {
    Q_UNUSED(user_data);
    auto *client = NM_CLIENT(source);
    
    GError *error = nullptr;
    nm_client_deactivate_connection_finish(client, result, &error);
    
    if (error) {
        qWarning() << "Connection deactivation failed:" << error->message;
        g_error_free(error);
    }
}

void Network::onConnectionAdded(NMClient *client, NMRemoteConnection *connection, gpointer user_data) {
    Q_UNUSED(client);
    Q_UNUSED(connection);
    auto *self = static_cast<Network*>(user_data);
    self->updateKnownNetworks();
}

void Network::onConnectionRemoved(NMClient *client, NMRemoteConnection *connection, gpointer user_data) {
    Q_UNUSED(client);
    Q_UNUSED(connection);
    auto *self = static_cast<Network*>(user_data);
    self->updateKnownNetworks();
}

// Private methods
void Network::updateNetworks() {
    if (!m_wifiDevice) return;
    
    const GPtrArray *accessPoints = nm_device_wifi_get_access_points(m_wifiDevice);
    
    // Group by SSID
    QMap<QString, NMAccessPoint*> bestAPs;
    
    for (guint i = 0; i < accessPoints->len; i++) {
        NMAccessPoint *ap = NM_ACCESS_POINT(g_ptr_array_index(accessPoints, i));
        
        GBytes *ssidBytes = nm_access_point_get_ssid(ap);
        if (!ssidBytes) continue;
        
        gsize size;
        const guint8 *data = static_cast<const guint8*>(g_bytes_get_data(ssidBytes, &size));
        QString ssid = QString::fromUtf8(reinterpret_cast<const char*>(data), size);
        
        if (ssid.isEmpty()) continue;
        
        if (!bestAPs.contains(ssid)) {
            bestAPs[ssid] = ap;
        } else {
            // Keep stronger signal or active one
            NMAccessPoint *activeAp = nm_device_wifi_get_active_access_point(m_wifiDevice);
            bool isActive = activeAp && (g_strcmp0(nm_object_get_path(NM_OBJECT(ap)),
                                                   nm_object_get_path(NM_OBJECT(activeAp))) == 0);
            bool existingActive = activeAp && (g_strcmp0(nm_object_get_path(NM_OBJECT(bestAPs[ssid])),
                                                         nm_object_get_path(NM_OBJECT(activeAp))) == 0);
            
            if (isActive && !existingActive) {
                bestAPs[ssid] = ap;
            } else if (!existingActive && 
                      nm_access_point_get_strength(ap) > nm_access_point_get_strength(bestAPs[ssid])) {
                bestAPs[ssid] = ap;
            }
        }
    }
    
    // Remove old networks
    QList<AccessPoint*> toRemove;
    for (auto *network : m_networks) {
        bool found = false;
        for (auto *ap : bestAPs.values()) {
            if (g_strcmp0(nm_object_get_path(NM_OBJECT(network->nmAccessPoint())),
                         nm_object_get_path(NM_OBJECT(ap))) == 0) {
                found = true;
                break;
            }
        }
        if (!found) {
            toRemove.append(network);
        }
    }
    
    for (auto *network : toRemove) {
        m_networks.removeAll(network);
        network->deleteLater();
    }
    
    // Add new networks
    for (auto *ap : bestAPs.values()) {
        if (!findAccessPoint(ap)) {
            auto *network = new AccessPoint(ap, m_wifiDevice, this);
            network->setIsKnown(m_knownSsids.contains(network->ssid()));
            m_networks.append(network);
        }
    }
    
    emit networksChanged();
    updateActiveConnection();
}

void Network::updateEthernetStatus() {
    bool hasEthernet = false;

    const GPtrArray *devices = nm_client_get_devices(m_client);
    for (guint i = 0; i < devices->len; i++) {
        NMDevice *device = NM_DEVICE(g_ptr_array_index(devices, i));
        NMDeviceType type = nm_device_get_device_type(device);
        NMDeviceState state = nm_device_get_state(device);

        // Debug output to help diagnose what's present on the machine
        // qDebug() << "NM device:" << (nm_device_get_iface(device) ? nm_device_get_iface(device) : "(no iface)")
        //          << "type=" << type << "state=" << state;

        // Treat several device types as "ethernet-like"
        bool isEtherLike = type == NM_DEVICE_TYPE_ETHERNET;

        if (isEtherLike && state == NM_DEVICE_STATE_ACTIVATED) {
            hasEthernet = true;
            break;
        }
    }

    if (m_ethernet != hasEthernet) {
        m_ethernet = hasEthernet;
        emit ethernetChanged();
    }
}

void Network::updateActiveConnection() {
    AccessPoint *newActive = nullptr;
    
    if (m_wifiDevice) {
        NMAccessPoint *activeAp = nm_device_wifi_get_active_access_point(m_wifiDevice);
        if (activeAp) {
            newActive = findAccessPoint(activeAp);
        }
    }
    
    if (m_active != newActive) {
        m_active = newActive;
        emit activeChanged();
    }
    
    // Also update active status for all networks
    for (auto *network : m_networks) {
        emit network->activeChanged();
    }
}

void Network::updateKnownNetworks() {
    m_knownSsids.clear();
    
    const GPtrArray *connections = nm_client_get_connections(m_client);
    for (guint i = 0; i < connections->len; i++) {
        NMRemoteConnection *connection = NM_REMOTE_CONNECTION(g_ptr_array_index(connections, i));
        NMConnection *conn = NM_CONNECTION(connection);
        
        NMSettingConnection *s_con = nm_connection_get_setting_connection(conn);
        if (!s_con) continue;
        
        const char *type = nm_setting_connection_get_connection_type(s_con);
        if (g_strcmp0(type, NM_SETTING_WIRELESS_SETTING_NAME) != 0) continue;
        
        NMSettingWireless *s_wifi = nm_connection_get_setting_wireless(conn);
        if (!s_wifi) continue;
        
        GBytes *ssidBytes = nm_setting_wireless_get_ssid(s_wifi);
        if (!ssidBytes) continue;
        
        gsize size;
        const guint8 *data = static_cast<const guint8*>(g_bytes_get_data(ssidBytes, &size));
        QString ssid = QString::fromUtf8(reinterpret_cast<const char*>(data), size);
        
        if (!ssid.isEmpty()) {
            m_knownSsids.append(ssid);
        }
    }
    
    // Update known status for all networks
    for (auto *network : m_networks) {
        network->setIsKnown(m_knownSsids.contains(network->ssid()));
    }
}

AccessPoint* Network::findAccessPoint(NMAccessPoint *ap) {
    const char *path = nm_object_get_path(NM_OBJECT(ap));
    for (auto *network : m_networks) {
        const char *otherPath = nm_object_get_path(NM_OBJECT(network->nmAccessPoint()));
        if (g_strcmp0(otherPath, path) == 0) {
            return network;
        }
    }
    return nullptr;
}

NMDeviceWifi* Network::getPrimaryWifiDevice() {
    const GPtrArray *devices = nm_client_get_devices(m_client);
    for (guint i = 0; i < devices->len; i++) {
        NMDevice *device = NM_DEVICE(g_ptr_array_index(devices, i));
        if (nm_device_get_device_type(device) == NM_DEVICE_TYPE_WIFI) {
            return NM_DEVICE_WIFI(device);
        }
    }
    return nullptr;
}

NMRemoteConnection* Network::findConnectionForSsid(const QString &ssid) {
    const GPtrArray *connections = nm_client_get_connections(m_client);
    for (guint i = 0; i < connections->len; i++) {
        NMRemoteConnection *connection = NM_REMOTE_CONNECTION(g_ptr_array_index(connections, i));
        NMConnection *conn = NM_CONNECTION(connection);
        
        NMSettingConnection *s_con = nm_connection_get_setting_connection(conn);
        if (!s_con) continue;
        
        const char *type = nm_setting_connection_get_connection_type(s_con);
        if (g_strcmp0(type, NM_SETTING_WIRELESS_SETTING_NAME) != 0) continue;
        
        NMSettingWireless *s_wifi = nm_connection_get_setting_wireless(conn);
        if (!s_wifi) continue;
        
        GBytes *ssidBytes = nm_setting_wireless_get_ssid(s_wifi);
        if (!ssidBytes) continue;
        
        gsize size;
        const guint8 *data = static_cast<const guint8*>(g_bytes_get_data(ssidBytes, &size));
        QString connSsid = QString::fromUtf8(reinterpret_cast<const char*>(data), size);
        
        if (connSsid == ssid) {
            return connection;
        }
    }
    return nullptr;
}

} // namespace sleex::services