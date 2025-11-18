#include "network.hpp"
#include <QDebug>
#include <QMap>
#include <QByteArray>
#include <QTimer>

namespace sleex::services {

// Helper struct to pass data to async callbacks
struct ConnectionCallbackData {
    Network *network;
    QString ssid;
    
    ConnectionCallbackData(Network *net, const QString &s) : network(net), ssid(s) {}
};

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
    
    // Check if NetworkManager considers this AP active
    bool nmActive = g_strcmp0(nm_object_get_path(NM_OBJECT(m_ap)), 
                              nm_object_get_path(NM_OBJECT(activeAp))) == 0;
    
    if (!nmActive) return false;
    
    // If NetworkManager thinks it's active, also check if we've detected an authentication failure
    // Get the Network instance to check for failed connections
    Network *network = qobject_cast<Network*>(parent());
    if (network && network->hasConnectionFailed(m_ssid)) {
        return false; // Don't show as active if authentication failed
    }
    
    return true;
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
        // Handle security changes by removing incompatible connection profiles
        Network* networkService = qobject_cast<Network*>(parent());
        if (networkService && m_isKnown) {
            // Remove existing connection profile to prevent authentication issues
            networkService->forgetNetwork(m_ssid);
            
            // Mark as unknown to force credential re-entry
            m_isKnown = false;
            emit isKnownChanged();
        }
        
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

void AccessPoint::updateAccessPoint(NMAccessPoint *newAp) {
    // Disconnect from old access point signals
    if (m_strengthChangedId) {
        g_signal_handler_disconnect(m_ap, m_strengthChangedId);
        m_strengthChangedId = 0;
    }
    
    // Release old access point and acquire new one
    if (m_ap) {
        g_object_unref(m_ap);
    }
    
    m_ap = newAp;
    g_object_ref(m_ap);
    
    // Connect to new access point signals
    m_strengthChangedId = g_signal_connect(m_ap, "notify::strength",
                                          G_CALLBACK(+[](GObject*, GParamSpec*, gpointer data) {
        auto *self = static_cast<AccessPoint*>(data);
        int newStrength = nm_access_point_get_strength(self->m_ap);
        if (self->m_strength != newStrength) {
            self->m_strength = newStrength;
            emit self->strengthChanged();
        }
    }), this);
    
    // Update all properties with new access point data
    updateProperties();
}

// Network implementation
Network::Network(QObject *parent) 
    : QObject(parent), m_client(nullptr), m_wifiDevice(nullptr), 
      m_active(nullptr), m_wifiEnabled(false), m_ethernet(false), m_scanning(false),
      m_connectingToSsid(""), m_apAddedId(0), m_apRemovedId(0), m_deviceAddedId(0), m_deviceRemovedId(0),
      m_wirelessEnabledId(0), m_activeConnectionsId(0), 
      m_connectionAddedId(0), m_connectionRemovedId(0), m_deviceStateChangedId(0) {
    
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
        m_deviceStateChangedId = g_signal_connect(m_wifiDevice, "notify::state",
                                                 G_CALLBACK(onDeviceStateChanged), this);
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
    if (m_deviceStateChangedId) g_signal_handler_disconnect(m_wifiDevice, m_deviceStateChangedId);
    
    // Clean up
    qDeleteAll(m_networks);
    if (m_client) g_object_unref(m_client);
}

QString Network::getNetworkIcon(int strength) {
    const GPtrArray *devices = nm_client_get_devices(m_client);

    for (guint i = 0; i < devices->len; ++i) {
        NMDevice *device = NM_DEVICE(g_ptr_array_index(devices, i));
        NMDeviceType type = nm_device_get_device_type(device);
        NMDeviceState state = nm_device_get_state(device);

        if (state != NM_DEVICE_STATE_ACTIVATED)
            continue;

        switch (type) {
        case NM_DEVICE_TYPE_WIFI: {
            switch (strength) {
                case 80 ... 100:
                    return "signal_wifi_4_bar";
                case 60 ... 79:
                    return "network_wifi_3_bar";
                case 40 ... 59:
                    return "network_wifi_2_bar";
                case 20 ... 39:
                    return "network_wifi_1_bar";
                default:
                    return "signal_wifi_0_bar";
            }
        }
        case NM_DEVICE_TYPE_ETHERNET:
            return "lan";
        case NM_DEVICE_TYPE_UNKNOWN:
            return "signal_wifi_statusbar_not_connected";
        case NM_DEVICE_TYPE_DUMMY:
            return "signal_wifi_bad";
        case NM_DEVICE_TYPE_BT:
            return "bluetooth_connected";
        case NM_DEVICE_TYPE_MODEM:
            return "router";
        default:
            break;
        }
    }

    // Fallback if no active device found
    return "signal_wifi_off";
}

void Network::enableWifi(bool enabled) {
    GVariant *value = g_variant_new_boolean(enabled);
    
    nm_client_dbus_set_property(
        m_client,
        NM_DBUS_PATH,
        NM_DBUS_INTERFACE,
        "WirelessEnabled",
        value,
        -1,  // timeout (-1 for default)
        nullptr,  // cancellable
        onWifiEnabledSet,
        this
    );
}


void Network::onWifiEnabledSet(GObject *source, GAsyncResult *result, gpointer user_data) {
    Q_UNUSED(user_data);
    auto *client = NM_CLIENT(source);
    
    GError *error = nullptr;
    gboolean success = nm_client_dbus_set_property_finish(client, result, &error);
    
    if (error) {
        qWarning() << "Failed to set wireless enabled:" << error->message;
        g_error_free(error);
    } else if (!success) {
        qWarning() << "Failed to set wireless enabled (no error details)";
    }
}

void Network::toggleWifi() {
    enableWifi(!m_wifiEnabled);
}

void Network::rescanWifi() {
    if (!m_wifiDevice || m_scanning) {
        return;
    }
    m_scanning = true;
    emit scanningChanged();
    
    nm_device_wifi_request_scan_async(m_wifiDevice, nullptr, onScanDone, this);
}

void Network::connectToNetwork(const QString &ssid, const QString &password) {
    if (!m_wifiDevice) return;
    
    // Clear any previous failed connection status for retry attempts
    clearConnectionFailed(ssid);
    
    // Find the target network to check security requirements
    AccessPoint *targetNetwork = nullptr;
    for (auto *network : m_networks) {
        if (network->ssid() == ssid) {
            targetNetwork = network;
            break;
        }
    }
    
    // Prevent connection attempts to unknown secure networks without passwords
    if (targetNetwork && targetNetwork->isSecure() && password.isEmpty() && !targetNetwork->isKnown()) {
        return;
    }
    
    // Set connecting state
    if (m_connectingToSsid != ssid) {
        m_connectingToSsid = ssid;
        emit connectingToSsidChanged();
    }
    
    // Create callback data
    ConnectionCallbackData *callbackData = new ConnectionCallbackData(this, ssid);
    
    // Check if it's a known connection
    NMRemoteConnection *connection = findConnectionForSsid(ssid);
    
    if (connection && password.isEmpty()) {
        // Check if stored connection security matches current network security
        bool connectionHasSecurity = false;
        NMConnection *conn = NM_CONNECTION(connection);
        NMSettingWirelessSecurity *s_wsec = nm_connection_get_setting_wireless_security(conn);
        connectionHasSecurity = (s_wsec != nullptr);
        
        bool networkHasSecurity = targetNetwork ? targetNetwork->isSecure() : false;
        
        if (connectionHasSecurity == networkHasSecurity) {
            // Security types match - use existing connection
            nm_client_activate_connection_async(
                m_client,
                NM_CONNECTION(connection),
                NM_DEVICE(m_wifiDevice),
                nullptr,
                nullptr,
                onConnectionActivated,
                callbackData
            );
        } else {
            // Security mismatch - delete old connection and signal that password is needed
            nm_remote_connection_delete_async(connection, nullptr, nullptr, nullptr);
            
            // Clear connecting state
            if (m_connectingToSsid == ssid) {
                m_connectingToSsid = "";
                emit connectingToSsidChanged();
            }
            
            // Signal that password is required due to security change
            emit passwordRequired(ssid);
            
            // Update known networks to reflect the deletion
            updateKnownNetworks();
            
            delete callbackData;
            return;
        }
    } else if (connection && !password.isEmpty()) {
        // Password provided - this means we want to update/recreate the connection
        // This handles cases like changing password or security type changes
        
        nm_remote_connection_delete_async(connection, nullptr, nullptr, nullptr);
        
        // Create new connection with new password
        connection = nullptr;
    }
    
    if (!connection) {
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
            onConnectionAddedAndActivated,
            callbackData
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
    } else {
        // Force network list update to refresh security states and other properties
        self->updateNetworks();
        
        // Also clear known networks cache to force fresh security detection
        self->updateKnownNetworks();
        
        // Force another update after a brief delay to catch any delayed AP changes
        QTimer::singleShot(500, self, [self]() {
            self->updateNetworks();
        });
    }
    
    self->m_scanning = false;
    emit self->scanningChanged();
}

void Network::onConnectionActivated(GObject *source, GAsyncResult *result, gpointer user_data) {
    auto *callbackData = static_cast<ConnectionCallbackData*>(user_data);
    auto *network = callbackData->network;
    QString ssid = callbackData->ssid;
    
    auto *client = NM_CLIENT(source);
    
    GError *error = nullptr;
    NMActiveConnection *ac = nm_client_activate_connection_finish(client, result, &error);
    
    // Clear connecting state regardless of result
    if (network->m_connectingToSsid == ssid) {
        network->m_connectingToSsid = "";
        emit network->connectingToSsidChanged();
    }
    
    if (error) {
        qWarning() << "Connection activation failed for" << ssid << ":" << error->message;
        network->markConnectionFailed(ssid);
        emit network->connectionFailed(ssid, QString::fromUtf8(error->message));
        g_error_free(error);
    } else if (ac) {
        // Use multiple verification checks to catch authentication failures quickly
        // First check after 1 second to catch immediate auth failures
        QTimer::singleShot(1000, [network, ssid]() {
            if (network->m_wifiDevice) {
                NMDeviceState state = nm_device_get_state(NM_DEVICE(network->m_wifiDevice));
                NMDeviceStateReason reason = nm_device_get_state_reason(NM_DEVICE(network->m_wifiDevice));
                
                // Check for immediate auth failures - expanded detection
                if (state == NM_DEVICE_STATE_FAILED || state == NM_DEVICE_STATE_NEED_AUTH ||
                    state == NM_DEVICE_STATE_DISCONNECTED ||
                    reason == NM_DEVICE_STATE_REASON_NO_SECRETS ||
                    reason == NM_DEVICE_STATE_REASON_SUPPLICANT_DISCONNECT ||
                    reason == NM_DEVICE_STATE_REASON_SUPPLICANT_CONFIG_FAILED ||
                    reason == NM_DEVICE_STATE_REASON_SUPPLICANT_TIMEOUT) {
                    
                    QString errorMessage = "Configuring connection - please wait";
                    network->markConnectionFailed(ssid);
        emit network->connectionFailed(ssid, errorMessage);
                    network->updateNetworks();
                    network->updateActiveConnection();
                    return;
                }
                
                // If still in progress, check again after 2 more seconds
                QTimer::singleShot(2000, [network, ssid]() {
            // Verify actual connection status and determine specific error
            bool actuallyConnected = false;
            QString errorMessage = "Connection failed";
            
            // Primary check: device state and active access point
            if (network->m_wifiDevice) {
                NMDeviceState state = nm_device_get_state(NM_DEVICE(network->m_wifiDevice));
                
                if (state == NM_DEVICE_STATE_ACTIVATED) {
                    NMAccessPoint *activeAp = nm_device_wifi_get_active_access_point(network->m_wifiDevice);
                    if (activeAp) {
                        GBytes *ssidBytes = nm_access_point_get_ssid(activeAp);
                        if (ssidBytes) {
                            gsize size;
                            const char *ssidData = (const char *)g_bytes_get_data(ssidBytes, &size);
                            QString activeSsid = QString::fromUtf8(ssidData, size);
                            actuallyConnected = (activeSsid == ssid);
                        }
                    }
                } else {
                    // Get device state reason for more specific error detection
                    NMDeviceStateReason reason = nm_device_get_state_reason(NM_DEVICE(network->m_wifiDevice));
                    
                    // Determine error based on device state and reason
                    switch (state) {
                        case NM_DEVICE_STATE_FAILED:
                            // Check specific failure reasons
                            if (reason == NM_DEVICE_STATE_REASON_NO_SECRETS ||
                                reason == NM_DEVICE_STATE_REASON_SUPPLICANT_DISCONNECT ||
                                reason == NM_DEVICE_STATE_REASON_SUPPLICANT_CONFIG_FAILED) {
                                errorMessage = "Configuring connection - please wait";
                            } else {
                                errorMessage = "Connection failed - network or device error";
                            }
                            break;
                        case NM_DEVICE_STATE_NEED_AUTH:
                            errorMessage = "Configuring connection - please wait";
                            break;
                        case NM_DEVICE_STATE_CONFIG:
                            if (reason == NM_DEVICE_STATE_REASON_SUPPLICANT_TIMEOUT ||
                                reason == NM_DEVICE_STATE_REASON_SUPPLICANT_DISCONNECT ||
                                reason == NM_DEVICE_STATE_REASON_SUPPLICANT_CONFIG_FAILED ||
                                reason == NM_DEVICE_STATE_REASON_NO_SECRETS) {
                                errorMessage = "Configuring connection - please wait";
                            } else {
                                errorMessage = "Configuring connection - please wait";
                            }
                            break;
                        case NM_DEVICE_STATE_IP_CONFIG:
                            errorMessage = "Getting IP address - network may be congested";
                            break;
                        case NM_DEVICE_STATE_DISCONNECTED:
                            if (reason == NM_DEVICE_STATE_REASON_NO_SECRETS ||
                                reason == NM_DEVICE_STATE_REASON_SUPPLICANT_DISCONNECT) {
                                errorMessage = "Configuring connection - please wait";
                            } else {
                                errorMessage = "Could not connect to network";
                            }
                            break;
                        default:
                            // For unknown states, check if it's auth-related
                            if (reason == NM_DEVICE_STATE_REASON_NO_SECRETS ||
                                reason == NM_DEVICE_STATE_REASON_SUPPLICANT_DISCONNECT ||
                                reason == NM_DEVICE_STATE_REASON_SUPPLICANT_CONFIG_FAILED ||
                                reason == NM_DEVICE_STATE_REASON_SUPPLICANT_TIMEOUT) {
                                errorMessage = "Configuring connection - please wait";
                            } else {
                                errorMessage = "Authentication failed or connection timed out";
                            }
                    }
                }
            }
            
            // Fallback check: active connections list (only if primary check failed)
            if (!actuallyConnected) {
                const GPtrArray *activeConnections = nm_client_get_active_connections(network->m_client);
                if (activeConnections) {
                    for (guint i = 0; i < activeConnections->len; i++) {
                        NMActiveConnection *activeConn = (NMActiveConnection *)g_ptr_array_index(activeConnections, i);
                        const char *connSsid = nm_active_connection_get_id(activeConn);
                        if (connSsid && QString::fromUtf8(connSsid) == ssid) {
                            NMActiveConnectionState connState = nm_active_connection_get_state(activeConn);
                            // Only consider it connected if both the active connection AND device are in good state
                            if (connState == NM_ACTIVE_CONNECTION_STATE_ACTIVATED) {
                                // Double-check that device is also in activated state
                                if (network->m_wifiDevice) {
                                    NMDeviceState deviceState = nm_device_get_state(NM_DEVICE(network->m_wifiDevice));
                                    actuallyConnected = (deviceState == NM_DEVICE_STATE_ACTIVATED);
                                }
                            }
                            break;
                        }
                    }
                }
            }
            
            qWarning() << "Final check - SSID:" << ssid << "ActuallyConnected:" << actuallyConnected;
            
            if (actuallyConnected) {
                qWarning() << "Emitting success for" << ssid << "- will verify in 5s";
                network->emitConnectionSucceededWithVerification(ssid);
                network->updateNetworks();
                network->updateActiveConnection();
            } else {
                // Override generic CONFIG messages for likely authentication failures
                if (errorMessage == "Configuring connection - please wait") {
                    errorMessage = "Incorrect password";
                }
                qWarning() << "Emitting connectionFailed for" << ssid << "with message:" << errorMessage;
                network->markConnectionFailed(ssid);
        emit network->connectionFailed(ssid, errorMessage);
                network->updateNetworks();
                network->updateActiveConnection();
            }
                }); // Close nested 2-second timer
            }
        }); // Close first 1-second timer
        
        g_object_unref(ac);
    } else {
        qWarning() << "Connection activation returned null for" << ssid;
        network->markConnectionFailed(ssid);
        emit network->connectionFailed(ssid, "Unknown error");
    }
    
    // Refresh network state after connection attempt
    network->updateNetworks();
    network->updateActiveConnection();
    
    // Additional refresh to ensure NetworkManager state has settled
    QTimer::singleShot(500, [network]() {
        network->updateNetworks();
        network->updateActiveConnection();
    });

    delete callbackData;
}

void Network::onConnectionAddedAndActivated(GObject *source, GAsyncResult *result, gpointer user_data) {
    auto *callbackData = static_cast<ConnectionCallbackData*>(user_data);
    auto *network = callbackData->network;
    QString ssid = callbackData->ssid;
    
    auto *client = NM_CLIENT(source);
    
    // Clear connecting state regardless of result
    if (network->m_connectingToSsid == ssid) {
        network->m_connectingToSsid = "";
        emit network->connectingToSsidChanged();
    }
    
    GError *error = nullptr;
    NMActiveConnection *ac = nm_client_add_and_activate_connection_finish(client, result, &error);
    
    if (error) {
        qWarning() << "Connection add and activation failed for" << ssid << ":" << error->message;
        network->markConnectionFailed(ssid);
        emit network->connectionFailed(ssid, QString::fromUtf8(error->message));
        g_error_free(error);
    } else if (ac) {
        // Use multiple verification checks to catch authentication failures quickly
        // First check after 1 second to catch immediate auth failures
        QTimer::singleShot(1000, [network, ssid]() {
            if (network->m_wifiDevice) {
                NMDeviceState state = nm_device_get_state(NM_DEVICE(network->m_wifiDevice));
                NMDeviceStateReason reason = nm_device_get_state_reason(NM_DEVICE(network->m_wifiDevice));
                
                // Check for immediate auth failures - expanded detection including timeout
                if (state == NM_DEVICE_STATE_FAILED || state == NM_DEVICE_STATE_NEED_AUTH ||
                    state == NM_DEVICE_STATE_DISCONNECTED ||
                    reason == NM_DEVICE_STATE_REASON_NO_SECRETS ||
                    reason == NM_DEVICE_STATE_REASON_SUPPLICANT_DISCONNECT ||
                    reason == NM_DEVICE_STATE_REASON_SUPPLICANT_CONFIG_FAILED ||
                    reason == NM_DEVICE_STATE_REASON_SUPPLICANT_TIMEOUT) {
                    
                    QString errorMessage = "Configuring connection - please wait";
                    if (reason == NM_DEVICE_STATE_REASON_SUPPLICANT_TIMEOUT) {
                        errorMessage = "Connection timeout - likely incorrect password";
                    }
                    
                qWarning() << "Emitting connectionFailed for" << ssid << "with message:" << errorMessage;
                    network->markConnectionFailed(ssid);
        emit network->connectionFailed(ssid, errorMessage);
                    network->updateNetworks();
                    network->updateActiveConnection();
                    return;
                }
                
                // Check for immediate auth failures
                if (state == NM_DEVICE_STATE_FAILED || state == NM_DEVICE_STATE_NEED_AUTH ||
                    (state == NM_DEVICE_STATE_DISCONNECTED && 
                     (reason == NM_DEVICE_STATE_REASON_NO_SECRETS ||
                      reason == NM_DEVICE_STATE_REASON_SUPPLICANT_DISCONNECT))) {
                    
                    QString errorMessage = "Configuring connection - please wait";
                qWarning() << "Emitting connectionFailed for" << ssid << "with message:" << errorMessage;
                    network->markConnectionFailed(ssid);
        emit network->connectionFailed(ssid, errorMessage);
                    network->updateNetworks();
                    network->updateActiveConnection();
                    return;
                }
                
                // If still in progress, check again after 2 more seconds
                QTimer::singleShot(2000, [network, ssid]() {
            // Verify actual connection status and determine specific error
            bool actuallyConnected = false;
            QString errorMessage = "Connection failed";
            
            // Check device state and active access point
            if (network->m_wifiDevice) {
                NMDeviceState state = nm_device_get_state(NM_DEVICE(network->m_wifiDevice));
                
                if (state == NM_DEVICE_STATE_ACTIVATED) {
                    NMAccessPoint *activeAp = nm_device_wifi_get_active_access_point(network->m_wifiDevice);
                    if (activeAp) {
                        GBytes *ssidBytes = nm_access_point_get_ssid(activeAp);
                        if (ssidBytes) {
                            gsize size;
                            const char *ssidData = (const char *)g_bytes_get_data(ssidBytes, &size);
                            QString activeSsid = QString::fromUtf8(ssidData, size);
                            actuallyConnected = (activeSsid == ssid);
                        }
                    }
                } else {
                    // Get device state reason for more specific error detection
                    NMDeviceStateReason reason = nm_device_get_state_reason(NM_DEVICE(network->m_wifiDevice));
                    
                    // Determine error based on device state and reason
                    switch (state) {
                        case NM_DEVICE_STATE_FAILED:
                            // Check specific failure reasons
                            if (reason == NM_DEVICE_STATE_REASON_NO_SECRETS ||
                                reason == NM_DEVICE_STATE_REASON_SUPPLICANT_DISCONNECT ||
                                reason == NM_DEVICE_STATE_REASON_SUPPLICANT_CONFIG_FAILED) {
                                errorMessage = "Configuring connection - please wait";
                            } else {
                                errorMessage = "Connection failed - network or device error";
                            }
                            break;
                        case NM_DEVICE_STATE_NEED_AUTH:
                            errorMessage = "Configuring connection - please wait";
                            break;
                        case NM_DEVICE_STATE_CONFIG:
                            if (reason == NM_DEVICE_STATE_REASON_SUPPLICANT_TIMEOUT ||
                                reason == NM_DEVICE_STATE_REASON_SUPPLICANT_DISCONNECT ||
                                reason == NM_DEVICE_STATE_REASON_SUPPLICANT_CONFIG_FAILED ||
                                reason == NM_DEVICE_STATE_REASON_NO_SECRETS) {
                                errorMessage = "Configuring connection - please wait";
                            } else {
                                errorMessage = "Configuring connection - please wait";
                            }
                            break;
                        case NM_DEVICE_STATE_IP_CONFIG:
                            errorMessage = "Getting IP address - network may be congested";
                            break;
                        case NM_DEVICE_STATE_DISCONNECTED:
                            if (reason == NM_DEVICE_STATE_REASON_NO_SECRETS ||
                                reason == NM_DEVICE_STATE_REASON_SUPPLICANT_DISCONNECT) {
                                errorMessage = "Configuring connection - please wait";
                            } else {
                                errorMessage = "Could not connect to network";
                            }
                            break;
                        default:
                            // For unknown states, check if it's auth-related
                            if (reason == NM_DEVICE_STATE_REASON_NO_SECRETS ||
                                reason == NM_DEVICE_STATE_REASON_SUPPLICANT_DISCONNECT ||
                                reason == NM_DEVICE_STATE_REASON_SUPPLICANT_CONFIG_FAILED ||
                                reason == NM_DEVICE_STATE_REASON_SUPPLICANT_TIMEOUT) {
                                errorMessage = "Configuring connection - please wait";
                            } else {
                                errorMessage = "Authentication failed or connection timed out";
                            }
                    }
                }
            }
            
            // Fallback: check active connections (only if primary check failed)
            if (!actuallyConnected) {
                const GPtrArray *activeConnections = nm_client_get_active_connections(network->m_client);
                if (activeConnections) {
                    for (guint i = 0; i < activeConnections->len; i++) {
                        NMActiveConnection *activeConn = (NMActiveConnection *)g_ptr_array_index(activeConnections, i);
                        const char *connSsid = nm_active_connection_get_id(activeConn);
                        if (connSsid && QString::fromUtf8(connSsid) == ssid) {
                            NMActiveConnectionState connState = nm_active_connection_get_state(activeConn);
                            // Only consider it connected if both the active connection AND device are in good state
                            if (connState == NM_ACTIVE_CONNECTION_STATE_ACTIVATED) {
                                // Double-check that device is also in activated state
                                if (network->m_wifiDevice) {
                                    NMDeviceState deviceState = nm_device_get_state(NM_DEVICE(network->m_wifiDevice));
                                    actuallyConnected = (deviceState == NM_DEVICE_STATE_ACTIVATED);
                                }
                            }
                            break;
                        }
                    }
                }
            }
            
            qWarning() << "Final check - SSID:" << ssid << "ActuallyConnected:" << actuallyConnected;
            
            if (actuallyConnected) {
                qWarning() << "Emitting success for" << ssid << "- will verify in 5s";
                network->emitConnectionSucceededWithVerification(ssid);
                network->updateNetworks();
                network->updateActiveConnection();
            } else {
                // Override generic CONFIG messages for likely authentication failures
                if (errorMessage == "Configuring connection - please wait") {
                    errorMessage = "Incorrect password";
                }
                qWarning() << "Emitting connectionFailed for" << ssid << "with message:" << errorMessage;
                network->markConnectionFailed(ssid);
        emit network->connectionFailed(ssid, errorMessage);
                network->updateNetworks();
                network->updateActiveConnection();
            }
                }); // Close nested 2-second timer
            }
        }); // Close first 1-second timer
        
        g_object_unref(ac);
    } else {
        qWarning() << "Connection add and activation returned null for" << ssid;
        network->markConnectionFailed(ssid);
        emit network->connectionFailed(ssid, "Unknown error");
    }
    
    // Ensure UI model is refreshed immediately after add+activate attempt
    network->updateNetworks();
    network->updateActiveConnection();

    delete callbackData;
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
    
    // Update existing networks and remove old ones
    QList<AccessPoint*> toRemove;
    for (auto *network : m_networks) {
        bool found = false;
        for (auto it = bestAPs.begin(); it != bestAPs.end(); ++it) {
            if (network->ssid() == it.key()) {
                // Network with same SSID found - check if it's the same AP or needs updating
                NMAccessPoint *currentAp = network->nmAccessPoint();
                NMAccessPoint *newAp = it.value();
                
                // Always update the network to use the newest access point data
                // This ensures security and other properties are refreshed
                if (currentAp != newAp) {
                    network->updateAccessPoint(newAp);
                }
                
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
        if (nm_device_get_device_type(device) == NM_DEVICE_TYPE_ETHERNET || nm_device_get_device_type(device) == NM_DEVICE_TYPE_DUMMY) {
            if (nm_device_get_state(device) == NM_DEVICE_STATE_ACTIVATED) {
                hasEthernet = true;
                break;
            }
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
    
    // Also update active status for all networks, but only if their active state actually changed
    for (auto *network : m_networks) {
        bool currentActive = network->active();
        bool wasActive = (network == m_active);  // This is approximate, but better than always emitting
        // Force a property check to ensure UI binding updates
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

void Network::emitConnectionSucceededWithVerification(const QString &ssid) {
    // Clear any previous failed connection status
    clearConnectionFailed(ssid);
    
    // Schedule delayed verification to catch authentication failures that occur after initial connection
    QTimer::singleShot(5000, this, [this, ssid]() {
        verifyDelayedConnection(ssid);
    });
    
    // Emit immediate success for UI responsiveness
    emit connectionSucceeded(ssid);
}

void Network::verifyDelayedConnection(const QString &ssid) {
    // Verify if the connection is still active after authentication has had time to complete
    bool stillConnected = false;
    QString errorMsg = "Authentication failed - incorrect password";
    
    if (m_wifiDevice) {
        NMDeviceState state = nm_device_get_state(NM_DEVICE(m_wifiDevice));
        
        if (state == NM_DEVICE_STATE_ACTIVATED) {
            NMAccessPoint *activeAp = nm_device_wifi_get_active_access_point(m_wifiDevice);
            if (activeAp) {
                GBytes *ssidBytes = nm_access_point_get_ssid(activeAp);
                if (ssidBytes) {
                    gsize size;
                    const char *ssidData = (const char *)g_bytes_get_data(ssidBytes, &size);
                    QString activeSsid = QString::fromUtf8(ssidData, size);
                    stillConnected = (activeSsid == ssid);
                }
            }
        } else {
            // Check the state reason to provide a better error message
            NMDeviceStateReason reason = nm_device_get_state_reason(NM_DEVICE(m_wifiDevice));
            if (reason == NM_DEVICE_STATE_REASON_NO_SECRETS ||
                reason == NM_DEVICE_STATE_REASON_SUPPLICANT_DISCONNECT ||
                reason == NM_DEVICE_STATE_REASON_SUPPLICANT_CONFIG_FAILED ||
                reason == NM_DEVICE_STATE_REASON_SUPPLICANT_TIMEOUT) {
                errorMsg = "Incorrect password";
            }
        }
    }
    
    qWarning() << "5s verification result for" << ssid << "- StillConnected:" << stillConnected << "State:" << (m_wifiDevice ? nm_device_get_state(NM_DEVICE(m_wifiDevice)) : -1);
    
    if (!stillConnected) {
        // Connection that was initially reported as successful has actually failed
        qWarning() << "Delayed failure detected for" << ssid << ":" << errorMsg;
        emit connectionFailed(ssid, errorMsg);
        updateNetworks();
        updateActiveConnection();
    } else {
        qWarning() << "5s verification passed for" << ssid;
    }
}

void Network::onDeviceStateChanged(GObject *object, GParamSpec *pspec, gpointer user_data) {
    Q_UNUSED(object);
    Q_UNUSED(pspec);
    auto *self = static_cast<Network*>(user_data);
    
    if (!self->m_wifiDevice) return;
    
    NMDeviceState newState = nm_device_get_state(NM_DEVICE(self->m_wifiDevice));
    
    // Detect unexpected disconnections (failed authentication after appearing connected)
    if (newState == NM_DEVICE_STATE_FAILED || 
        newState == NM_DEVICE_STATE_DISCONNECTED ||
        newState == NM_DEVICE_STATE_NEED_AUTH) {
        
        NMDeviceStateReason reason = nm_device_get_state_reason(NM_DEVICE(self->m_wifiDevice));
        
        // Only trigger if it's an auth-related failure after we thought we were connected
        if (reason == NM_DEVICE_STATE_REASON_NO_SECRETS ||
            reason == NM_DEVICE_STATE_REASON_SUPPLICANT_DISCONNECT ||
            reason == NM_DEVICE_STATE_REASON_SUPPLICANT_CONFIG_FAILED ||
            reason == NM_DEVICE_STATE_REASON_SUPPLICANT_TIMEOUT) {
            
            // Find which network was being connected to
            QString failedSsid = self->m_connectingToSsid;
            if (failedSsid.isEmpty()) {
                // Try to get it from the last active connection
                NMAccessPoint *activeAp = nm_device_wifi_get_active_access_point(self->m_wifiDevice);
                if (activeAp) {
                    GBytes *ssidBytes = nm_access_point_get_ssid(activeAp);
                    if (ssidBytes) {
                        gsize size;
                        const char *ssidData = (const char *)g_bytes_get_data(ssidBytes, &size);
                        failedSsid = QString::fromUtf8(ssidData, size);
                    }
                }
            }
            
            if (!failedSsid.isEmpty()) {
                emit self->connectionFailed(failedSsid, "Incorrect password");
                self->updateNetworks();
                self->updateActiveConnection();
            }
        }
    }
}

void Network::markConnectionFailed(const QString &ssid) {
    if (!ssid.isEmpty() && !m_failedConnections.contains(ssid)) {
        m_failedConnections.append(ssid);
        qWarning() << "Marked connection as failed for SSID:" << ssid;
    }
}

void Network::clearConnectionFailed(const QString &ssid) {
    m_failedConnections.removeAll(ssid);
}

bool Network::hasConnectionFailed(const QString &ssid) const {
    return m_failedConnections.contains(ssid);
}

} // namespace sleex::services