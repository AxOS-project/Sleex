#pragma once

#include <QObject>
#include <QDBusAbstractAdaptor>
#include <QDBusContext>
#include <QDBusObjectPath>
#include <QDBusArgument>
#include <QDBusVariant>
#include <QDBusServiceWatcher>
#include <QVariantList>
#include <QVariantMap>
#include <QHash>
#include <QList>
#include <QString>
#include <QStringList>
#include <QLocalSocket>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

struct SleexDBusMenuLayoutItem {
    qint32 id = 0;
    QVariantMap properties;
    QList<SleexDBusMenuLayoutItem> children;
};

struct SleexDBusMenuItemProperties {
    qint32 id = 0;
    QVariantMap properties;
};
using SleexDBusMenuItemPropertiesList = QList<SleexDBusMenuItemProperties>;

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

const QDBusArgument &operator>>(const QDBusArgument &argument, SleexDBusMenuLayoutItem &layout);
QDBusArgument &operator<<(QDBusArgument &argument, const SleexDBusMenuLayoutItem &layout);
const QDBusArgument &operator>>(const QDBusArgument &argument, SleexDBusMenuItemProperties &item);
QDBusArgument &operator<<(QDBusArgument &argument, const SleexDBusMenuItemProperties &item);
const QDBusArgument &operator>>(const QDBusArgument &argument, SleexDBusMenuItemPropertyNames &names);
QDBusArgument &operator<<(QDBusArgument &argument, const SleexDBusMenuItemPropertyNames &names);

namespace sleex::services {

class AppMenu;

class AppMenuRegistrarAdaptor : public QDBusAbstractAdaptor {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "com.canonical.AppMenu.Registrar")

public:
    explicit AppMenuRegistrarAdaptor(AppMenu *parent);

public Q_SLOTS:
    void RegisterWindow(uint windowId, const QDBusObjectPath &menuObjectPath);
    void UnregisterWindow(uint windowId);
    QString GetMenuForWindow(uint windowId, QDBusObjectPath &menuObjectPath);

Q_SIGNALS:
    void WindowRegistered(uint windowId, const QString &service, const QDBusObjectPath &menuObjectPath);
    void WindowUnregistered(uint windowId);

private:
    AppMenu *m_appMenu;
};

class AppMenu : public QObject, public QDBusContext {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QVariantList menus READ menus NOTIFY menusChanged)
    Q_PROPERTY(bool hasNativeMenu READ hasNativeMenu NOTIFY hasNativeMenuChanged)
    Q_PROPERTY(QString currentService READ currentService NOTIFY currentMenuChanged)
    Q_PROPERTY(QString currentPath READ currentPath NOTIFY currentMenuChanged)

public:
    explicit AppMenu(QObject *parent = nullptr);
    ~AppMenu() override = default;

    QVariantList menus() const { return m_menus; }
    bool hasNativeMenu() const { return !m_currentService.isEmpty() && !m_currentPath.isEmpty() && !m_menus.isEmpty(); }
    QString currentService() const { return m_currentService; }
    QString currentPath() const { return m_currentPath; }

    // Called from QML when the active window changes
    Q_INVOKABLE void setActiveWindow(int pid, const QString &appId, uint windowId = 0);
    // Called from QML when a top-level menu or submenu is about to open
    Q_INVOKABLE void prepareMenu(int itemId);
    // Called from QML when a menu item is clicked
    Q_INVOKABLE void trigger(int itemId);
    // Force refresh current layout
    Q_INVOKABLE void refreshLayout(int parentId = 0);

    // Internal methods used by AppMenuRegistrarAdaptor
    void registerWindowInternal(uint windowId, const QString &senderService, const QDBusObjectPath &menuObjectPath);
    void unregisterWindowInternal(uint windowId);
    QString getMenuForWindowInternal(uint windowId, QDBusObjectPath &menuObjectPath) const;

Q_SIGNALS:
    void menusChanged();
    void hasNativeMenuChanged();
    void currentMenuChanged();
    void windowRegistered(uint windowId, const QString &service, const QString &menuObjectPath);
    void windowUnregistered(uint windowId);

private Q_SLOTS:
    void onServiceUnregistered(const QString &service);
    void onLayoutUpdated(uint revision, int parent);
    void onItemsPropertiesUpdated(const SleexDBusMenuItemPropertiesList &updatedProps,
                                  const SleexDBusMenuItemPropertyNamesList &removedProps);

private:
    struct MenuTarget {
        QString service;
        QString path;
        uint pid = 0;
    };

    void discoverMenuForPid(uint pid, uint windowId);
    void probeServiceMenuPaths(const QString &service, uint pid);
    void introspectForDbusMenu(const QString &service, const QString &path, uint pid, int depth = 0);
    void setCurrentTarget(const QString &service, const QString &path);
    void clearCurrentTarget();
    QVariantMap layoutToVariantMap(const SleexDBusMenuLayoutItem &item) const;
    static QString cleanMnemonicLabel(const QString &raw);
    static QString formatShortcut(const QVariant &shortcutVar);

    QTimer *m_hyprPollTimer = nullptr;
    QLocalSocket *m_hyprEventSocket = nullptr;
    QByteArray m_hyprEventBuffer;

    void connectHyprlandEvents();
    void handleHyprlandEvent(const QByteArray &line);
    void queryHyprlandActiveWindow();
    static QString hyprSocketPath(int n = 1);

    AppMenuRegistrarAdaptor *m_adaptor = nullptr;
    QDBusServiceWatcher m_serviceWatcher;

    QHash<uint, MenuTarget> m_windowMenus;     // windowId -> MenuTarget
    QHash<uint, MenuTarget> m_pidMenus;        // pid -> MenuTarget
    QHash<QString, uint> m_servicePids;        // service -> pid

    uint m_activePid = 0;
    uint m_activeWindowId = 0;
    QString m_activeAppId;

    QString m_currentService;
    QString m_currentPath;
    QVariantList m_menus;
};

} // namespace sleex::services
