#pragma once

#include <QByteArray>
#include <QDBusAbstractAdaptor>
#include <QDBusArgument>
#include <QDBusContext>
#include <QDBusObjectPath>
#include <QDBusServiceWatcher>
#include <QDBusVariant>
#include <QHash>
#include <QList>
#include <QLocalSocket>
#include <QObject>
#include <QSet>
#include <QString>
#include <QStringList>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

/**
 * @brief Recursive layout node returned by `com.canonical.dbusmenu.GetLayout`.
 */
struct SleexDBusMenuLayoutItem {
    qint32 id = 0;
    QVariantMap properties;
    QList<SleexDBusMenuLayoutItem> children;
};

/**
 * @brief Updated properties entry emitted by `com.canonical.dbusmenu.ItemsPropertiesUpdated`.
 */
struct SleexDBusMenuItemProperties {
    qint32 id = 0;
    QVariantMap properties;
};
using SleexDBusMenuItemPropertiesList = QList<SleexDBusMenuItemProperties>;

/**
 * @brief Removed property names entry emitted by `com.canonical.dbusmenu.ItemsPropertiesUpdated`.
 */
struct SleexDBusMenuItemPropertyNames {
    qint32 id = 0;
    QStringList properties;
};
using SleexDBusMenuItemPropertyNamesList = QList<SleexDBusMenuItemPropertyNames>;

Q_DECLARE_METATYPE(SleexDBusMenuLayoutItem)
Q_DECLARE_METATYPE(SleexDBusMenuItemProperties)
Q_DECLARE_METATYPE(SleexDBusMenuItemPropertiesList)
Q_DECLARE_METATYPE(SleexDBusMenuItemPropertyNames)
Q_DECLARE_METATYPE(SleexDBusMenuItemPropertyNamesList)

/**
 * @brief Deserializes a `SleexDBusMenuLayoutItem` from a D-Bus argument stream.
 */
const QDBusArgument &operator>>(const QDBusArgument &argument, SleexDBusMenuLayoutItem &layout);

/**
 * @brief Serializes a `SleexDBusMenuLayoutItem` into a D-Bus argument stream.
 */
QDBusArgument &operator<<(QDBusArgument &argument, const SleexDBusMenuLayoutItem &layout);

/**
 * @brief Deserializes a `SleexDBusMenuItemProperties` struct from a D-Bus argument stream.
 */
const QDBusArgument &operator>>(const QDBusArgument &argument, SleexDBusMenuItemProperties &item);

/**
 * @brief Serializes a `SleexDBusMenuItemProperties` struct into a D-Bus argument stream.
 */
QDBusArgument &operator<<(QDBusArgument &argument, const SleexDBusMenuItemProperties &item);

/**
 * @brief Deserializes a `SleexDBusMenuItemPropertyNames` struct from a D-Bus argument stream.
 */
const QDBusArgument &operator>>(const QDBusArgument &argument, SleexDBusMenuItemPropertyNames &names);

/**
 * @brief Serializes a `SleexDBusMenuItemPropertyNames` struct into a D-Bus argument stream.
 */
QDBusArgument &operator<<(QDBusArgument &argument, const SleexDBusMenuItemPropertyNames &names);

namespace sleex::services {

class AppMenu;

/**
 * @brief D-Bus adaptor implementing `com.canonical.AppMenu.Registrar` on `/com/canonical/AppMenu/Registrar`.
 */
class AppMenuRegistrarAdaptor : public QDBusAbstractAdaptor {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "com.canonical.AppMenu.Registrar")

public:
    /**
     * @brief Constructs the registrar D-Bus adaptor attached to `parent`.
     * @param parent Owning `AppMenu` service instance.
     */
    explicit AppMenuRegistrarAdaptor(AppMenu *parent);

public Q_SLOTS:
    /**
     * @brief Registers a `com.canonical.dbusmenu` object path for a given window ID.
     * @param windowId Window identifier reported by the client.
     * @param menuObjectPath D-Bus object path exporting `com.canonical.dbusmenu`.
     */
    void RegisterWindow(uint windowId, const QDBusObjectPath &menuObjectPath);

    /**
     * @brief Unregisters a previously registered window ID.
     * @param windowId Window identifier to remove.
     */
    void UnregisterWindow(uint windowId);

    /**
     * @brief Looks up the D-Bus service name and menu object path registered for a window ID.
     * @param windowId Window identifier to query.
     * @param menuObjectPath Output parameter receiving the menu D-Bus object path.
     * @return D-Bus service name exporting the menu, or empty string if not registered.
     */
    QString GetMenuForWindow(uint windowId, QDBusObjectPath &menuObjectPath);

Q_SIGNALS:
    /**
     * @brief Emitted over D-Bus when a window registers a menu object path.
     */
    void WindowRegistered(uint windowId, const QString &service, const QDBusObjectPath &menuObjectPath);

    /**
     * @brief Emitted over D-Bus when a window unregisters its menu object path.
     */
    void WindowUnregistered(uint windowId);

private:
    AppMenu *m_appMenu;
};

/**
 * @brief QML singleton service providing global application menu (`com.canonical.dbusmenu`) integration.
 *
 * Tracks the currently focused window via `fht-compositor` IPC (`FHTC_SOCKET_PATH`) and QML updates,
 * matches the focused window's PID or `app-id` against registered or introspected D-Bus menu
 * endpoints, and exposes the menu hierarchy to `AppMenuBar.qml`.
 */
class AppMenu : public QObject, public QDBusContext {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QVariantList menus READ menus NOTIFY menusChanged)
    Q_PROPERTY(bool hasNativeMenu READ hasNativeMenu NOTIFY hasNativeMenuChanged)
    Q_PROPERTY(QString currentService READ currentService NOTIFY currentMenuChanged)
    Q_PROPERTY(QString currentPath READ currentPath NOTIFY currentMenuChanged)

public:
    /**
     * @brief Constructs the `AppMenu` singleton, registers the D-Bus registrar, and connects to `fht-compositor` IPC.
     * @param parent Optional parent `QObject`.
     */
    explicit AppMenu(QObject *parent = nullptr);

    /**
     * @brief Destroys the `AppMenu` service.
     */
    ~AppMenu() override = default;

    /**
     * @brief Returns the top-level menu list for the currently active window.
     * @return `QVariantList` of top-level menu maps (`itemId`, `name`, `items`, `hasChildren`, etc.).
     */
    QVariantList menus() const { return m_menus; }

    /**
     * @brief Returns whether the focused window exports a valid non-empty native D-Bus menu.
     * @return `true` if a native menu is active and populated, `false` otherwise.
     */
    bool hasNativeMenu() const { return !m_currentService.isEmpty() && !m_currentPath.isEmpty() && !m_menus.isEmpty(); }

    /**
     * @brief Returns the D-Bus service name of the currently bound menu target.
     * @return D-Bus service name string.
     */
    QString currentService() const { return m_currentService; }

    /**
     * @brief Returns the D-Bus object path of the currently bound menu target.
     * @return D-Bus object path string.
     */
    QString currentPath() const { return m_currentPath; }

    /**
     * @brief Updates the active window context and discovers or binds its D-Bus menu.
     * @param pid Process ID of the focused window (or `0` if unknown, triggering `appId` fallback).
     * @param appId Wayland `app-id` of the focused window.
     * @param windowId Compositor or X11/Wayland numeric window identifier.
     */
    Q_INVOKABLE void setActiveWindow(int pid, const QString &appId, uint windowId = 0);

    /**
     * @brief Sends `Event("opened")` and `AboutToShow` to a menu item before displaying its submenu.
     * @param itemId D-Bus menu item identifier (`0` for root menu bar).
     */
    Q_INVOKABLE void prepareMenu(int itemId);

    /**
     * @brief Sends `Event("clicked")` to activate a menu item.
     * @param itemId D-Bus menu item identifier to trigger.
     */
    Q_INVOKABLE void trigger(int itemId);

    /**
     * @brief Queries `GetLayout` from the active D-Bus menu endpoint and refreshes `menus`.
     * @param parentId Root node ID to query (`0` for full menu bar).
     */
    Q_INVOKABLE void refreshLayout(int parentId = 0);

    /**
     * @brief Records a window menu registration received by `AppMenuRegistrarAdaptor`.
     * @param windowId Registered window identifier.
     * @param senderService D-Bus unique or well-known service name of the caller.
     * @param menuObjectPath D-Bus object path of the exported menu.
     */
    void registerWindowInternal(uint windowId, const QString &senderService, const QDBusObjectPath &menuObjectPath);

    /**
     * @brief Removes a window menu registration when requested by `AppMenuRegistrarAdaptor`.
     * @param windowId Window identifier to unregister.
     */
    void unregisterWindowInternal(uint windowId);

    /**
     * @brief Retrieves the registered D-Bus service and object path for `windowId`.
     * @param windowId Window identifier to look up.
     * @param menuObjectPath Output parameter receiving the registered object path.
     * @return Registered D-Bus service name, or empty string if none.
     */
    QString getMenuForWindowInternal(uint windowId, QDBusObjectPath &menuObjectPath) const;

Q_SIGNALS:
    /**
     * @brief Emitted when the top-level or nested menu items change.
     */
    void menusChanged();

    /**
     * @brief Emitted when `hasNativeMenu` transitions between `true` and `false`.
     */
    void hasNativeMenuChanged();

    /**
     * @brief Emitted when `currentService` or `currentPath` changes.
     */
    void currentMenuChanged();

    /**
     * @brief Emitted when a window registers a menu with the registrar.
     */
    void windowRegistered(uint windowId, const QString &service, const QString &menuObjectPath);

    /**
     * @brief Emitted when a window unregisters its menu from the registrar.
     */
    void windowUnregistered(uint windowId);

private Q_SLOTS:
    /**
     * @brief Cleans up cached menu mappings when a watched D-Bus service disconnects.
     * @param service Unregistered D-Bus service name.
     */
    void onServiceUnregistered(const QString &service);

    /**
     * @brief Refreshes the menu layout in response to `com.canonical.dbusmenu.LayoutUpdated`.
     * @param revision Layout revision counter from the service.
     * @param parent Parent menu item ID that changed.
     */
    void onLayoutUpdated(uint revision, int parent);

    /**
     * @brief Refreshes the menu layout in response to `com.canonical.dbusmenu.ItemsPropertiesUpdated`.
     * @param updatedProps List of updated item property maps.
     * @param removedProps List of removed item property names.
     */
    void onItemsPropertiesUpdated(const SleexDBusMenuItemPropertiesList &updatedProps,
                                  const SleexDBusMenuItemPropertyNamesList &removedProps);

private:
    struct MenuTarget {
        QString service;
        QString path;
        uint pid = 0;
    };

    /**
     * @brief Searches session D-Bus services owned by `pid` (or its process tree) for exported menus.
     * @param pid Target process ID.
     * @param windowId Target window ID.
     */
    void discoverMenuForPid(uint pid, uint windowId);

    /**
     * @brief Resolves a candidate process ID from `/proc` or D-Bus service names matching `appId`.
     * @param appId Wayland `app-id` string (e.g. `"org.kde.kate"` or `"firefox"`).
     * @return Matching process ID, or `0` if no matching process is found.
     */
    uint resolvePidForAppId(const QString &appId);

    /**
     * @brief Probes common menu object paths and triggers XML introspection on `service`.
     * @param service D-Bus service name to probe.
     * @param pid Process ID owning `service`.
     */
    void probeServiceMenuPaths(const QString &service, uint pid);

    /**
     * @brief Recursively introspects D-Bus object paths on `service` to locate `com.canonical.dbusmenu`.
     * @param service D-Bus service name.
     * @param path Current object path being introspected.
     * @param pid Process ID owning `service`.
     * @param depth Current recursion depth (capped at 4).
     */
    void introspectForDbusMenu(const QString &service, const QString &path, uint pid, int depth = 0);

    /**
     * @brief Binds the active menu target to `(service, path)`, subscribes to change signals, and loads the layout.
     * @param service Target D-Bus service name.
     * @param path Target D-Bus object path.
     */
    void setCurrentTarget(const QString &service, const QString &path);

    /**
     * @brief Disconnects signals and clears the currently active menu target and menu list.
     */
    void clearCurrentTarget();

    /**
     * @brief Converts a `SleexDBusMenuLayoutItem` tree into a QML-friendly `QVariantMap`.
     * @param item Source D-Bus menu layout node.
     * @return Map containing `itemId`, `name`, `isSeparator`, `enabled`, `visible`, `iconName`,
     *         `toggleType`, `toggleState`, `shortcut`, `items`, and `hasChildren`.
     */
    QVariantMap layoutToVariantMap(const SleexDBusMenuLayoutItem &item) const;

    /**
     * @brief Strips single underscore mnemonics (`_File` -> `File`) while preserving escaped underscores (`__` -> `_`).
     * @param raw Raw label string from `com.canonical.dbusmenu`.
     * @return Cleaned human-readable label.
     */
    static QString cleanMnemonicLabel(const QString &raw);

    /**
     * @brief Formats a `com.canonical.dbusmenu` `aas` shortcut array into a display string (e.g. `"Ctrl+Shift+S"`).
     * @param shortcutVar Raw D-Bus shortcut property value.
     * @return Formatted shortcut string, or empty string if none.
     */
    static QString formatShortcut(const QVariant &shortcutVar);

    /**
     * @brief Connects to the `fht-compositor` IPC socket and subscribes to window focus events.
     */
    void connectFhtcEvents();

    /**
     * @brief Processes a single JSON event line from the `fht-compositor` subscription stream.
     * @param line Raw UTF-8 JSON line.
     */
    void handleFhtcEventLine(const QByteArray &line);

    /**
     * @brief Queries `"focused-window"` from the `fht-compositor` IPC socket.
     */
    void queryFhtcFocusedWindow();

    /**
     * @brief Returns the `fht-compositor` IPC socket path from `FHTC_SOCKET_PATH`.
     * @return Path to the Unix domain socket, or empty string if unset.
     */
    static QString fhtcSocketPath();

    QTimer *m_queryDebounceTimer = nullptr;
    QTimer *m_reconnectTimer = nullptr;
    bool m_queryInFlight = false;
    QLocalSocket *m_fhtcEventSocket = nullptr;
    QByteArray m_fhtcEventBuffer;
    QHash<uint, QVariantMap> m_fhtcWindows;
    int m_focusedFhtcWindowId = -1;

    AppMenuRegistrarAdaptor *m_adaptor = nullptr;
    QDBusServiceWatcher m_serviceWatcher;

    QHash<uint, MenuTarget> m_windowMenus;     // windowId -> MenuTarget
    QHash<uint, MenuTarget> m_pidMenus;        // pid -> MenuTarget
    QSet<uint> m_noMenuPids;                   // pids probed or verified to have no dbus menu
    QHash<QString, uint> m_servicePids;        // service -> pid

    uint m_activePid = 0;
    uint m_activeWindowId = 0;
    QString m_activeAppId;

    QString m_currentService;
    QString m_currentPath;
    QVariantList m_menus;
};

} // namespace sleex::services
