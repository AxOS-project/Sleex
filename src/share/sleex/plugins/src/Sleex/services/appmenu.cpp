#include "appmenu.hpp"

#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusPendingCall>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusReply>
#include <QDBusMetaType>
#include <QDateTime>
#include <QXmlStreamReader>
#include <QJsonDocument>
#include <QJsonObject>
#include <QFile>
#include <QDebug>

const QDBusArgument &operator>>(const QDBusArgument &argument, SleexDBusMenuLayoutItem &layout)
{
    layout.children.clear();
    argument.beginStructure();
    argument >> layout.id;
    argument >> layout.properties;

    argument.beginArray();
    while (!argument.atEnd()) {
        QDBusVariant dbusVar;
        argument >> dbusVar;
        const QDBusArgument childArg = dbusVar.variant().value<QDBusArgument>();
        SleexDBusMenuLayoutItem child;
        childArg >> child;
        layout.children.append(child);
    }
    argument.endArray();
    argument.endStructure();
    return argument;
}

QDBusArgument &operator<<(QDBusArgument &argument, const SleexDBusMenuLayoutItem &layout)
{
    argument.beginStructure();
    argument << layout.id;
    argument << layout.properties;
    argument.beginArray(qMetaTypeId<QDBusVariant>());
    for (const auto &child : layout.children) {
        argument << QDBusVariant(QVariant::fromValue(child));
    }
    argument.endArray();
    argument.endStructure();
    return argument;
}

const QDBusArgument &operator>>(const QDBusArgument &argument, SleexDBusMenuItemProperties &item)
{
    argument.beginStructure();
    argument >> item.id;
    argument >> item.properties;
    argument.endStructure();
    return argument;
}

QDBusArgument &operator<<(QDBusArgument &argument, const SleexDBusMenuItemProperties &item)
{
    argument.beginStructure();
    argument << item.id;
    argument << item.properties;
    argument.endStructure();
    return argument;
}

const QDBusArgument &operator>>(const QDBusArgument &argument, SleexDBusMenuItemPropertyNames &names)
{
    argument.beginStructure();
    argument >> names.id;
    argument >> names.properties;
    argument.endStructure();
    return argument;
}

QDBusArgument &operator<<(QDBusArgument &argument, const SleexDBusMenuItemPropertyNames &names)
{
    argument.beginStructure();
    argument << names.id;
    argument << names.properties;
    argument.endStructure();
    return argument;
}

namespace sleex::services {

static uint getParentPid(uint pid)
{
    if (pid == 0) return 0;
    QFile statFile(QStringLiteral("/proc/%1/stat").arg(pid));
    if (!statFile.open(QIODevice::ReadOnly | QIODevice::Text))
        return 0;
    const QByteArray data = statFile.readAll();
    const int rparen = data.lastIndexOf(')');
    if (rparen < 0 || rparen + 2 >= data.size())
        return 0;
    const QList<QByteArray> fields = data.mid(rparen + 2).trimmed().split(' ');
    // fields[0] is state, fields[1] is ppid
    if (fields.size() >= 2)
        return fields[1].toUInt();
    return 0;
}

static bool pidMatchesOrSharesTree(uint servicePid, uint windowPid)
{
    if (servicePid == 0 || windowPid == 0) return false;
    if (servicePid == windowPid) return true;

    // Walk up from servicePid to see if windowPid is an ancestor
    uint cur = servicePid;
    for (int i = 0; i < 6 && cur > 1; ++i) {
        cur = getParentPid(cur);
        if (cur == windowPid) return true;
    }

    // Walk up from windowPid to see if servicePid is an ancestor
    cur = windowPid;
    for (int i = 0; i < 6 && cur > 1; ++i) {
        cur = getParentPid(cur);
        if (cur == servicePid) return true;
    }

    // Check if both share the same immediate parent (e.g. Electron helper + main)
    const uint p1 = getParentPid(servicePid);
    const uint p2 = getParentPid(windowPid);
    if (p1 > 1 && p1 == p2) return true;

    return false;
}

AppMenuRegistrarAdaptor::AppMenuRegistrarAdaptor(AppMenu *parent)
    : QDBusAbstractAdaptor(parent)
    , m_appMenu(parent)
{
    setAutoRelaySignals(true);
}

void AppMenuRegistrarAdaptor::RegisterWindow(uint windowId, const QDBusObjectPath &menuObjectPath)
{
    QString senderService;
    if (m_appMenu->calledFromDBus()) {
        senderService = m_appMenu->message().service();
    }
    m_appMenu->registerWindowInternal(windowId, senderService, menuObjectPath);
    Q_EMIT WindowRegistered(windowId, senderService, menuObjectPath);
}

void AppMenuRegistrarAdaptor::UnregisterWindow(uint windowId)
{
    m_appMenu->unregisterWindowInternal(windowId);
    Q_EMIT WindowUnregistered(windowId);
}

QString AppMenuRegistrarAdaptor::GetMenuForWindow(uint windowId, QDBusObjectPath &menuObjectPath)
{
    return m_appMenu->getMenuForWindowInternal(windowId, menuObjectPath);
}

AppMenu::AppMenu(QObject *parent)
    : QObject(parent)
{
    qDBusRegisterMetaType<SleexDBusMenuLayoutItem>();
    qDBusRegisterMetaType<SleexDBusMenuItemProperties>();
    qDBusRegisterMetaType<SleexDBusMenuItemPropertiesList>();
    qDBusRegisterMetaType<SleexDBusMenuItemPropertyNames>();
    qDBusRegisterMetaType<SleexDBusMenuItemPropertyNamesList>();

    m_adaptor = new AppMenuRegistrarAdaptor(this);

    auto bus = QDBusConnection::sessionBus();
    if (bus.isConnected()) {
        bus.registerObject(QStringLiteral("/com/canonical/AppMenu/Registrar"), this);
        bus.registerService(QStringLiteral("com.canonical.AppMenu.Registrar"));

        m_serviceWatcher.setConnection(bus);
        m_serviceWatcher.setWatchMode(QDBusServiceWatcher::WatchForUnregistration);
        connect(&m_serviceWatcher, &QDBusServiceWatcher::serviceUnregistered,
                this, &AppMenu::onServiceUnregistered);
    }

    connectHyprlandEvents();
    queryHyprlandActiveWindow();
}

QString AppMenu::hyprSocketPath(int n)
{
    const QString sig = qEnvironmentVariable("HYPRLAND_INSTANCE_SIGNATURE");
    const QString run = qEnvironmentVariable("XDG_RUNTIME_DIR", QStringLiteral("/run/user/1000"));
    const QString suffix = (n == 2) ? QStringLiteral("2") : QString();

    const QString newPath = QStringLiteral("%1/hypr/%2/.socket%3.sock").arg(run, sig, suffix);
    if (QFile::exists(newPath))
        return newPath;

    return QStringLiteral("/tmp/hypr/%1/.socket%2.sock").arg(sig, suffix);
}

void AppMenu::connectHyprlandEvents()
{
    if (m_hyprEventSocket) {
        m_hyprEventSocket->deleteLater();
    }
    m_hyprEventSocket = new QLocalSocket(this);

    connect(m_hyprEventSocket, &QLocalSocket::readyRead, this, [this]() {
        m_hyprEventBuffer += m_hyprEventSocket->readAll();
        while (true) {
            const int nl = m_hyprEventBuffer.indexOf('\n');
            if (nl < 0) break;
            handleHyprlandEvent(m_hyprEventBuffer.left(nl));
            m_hyprEventBuffer = m_hyprEventBuffer.mid(nl + 1);
        }
    });

    connect(m_hyprEventSocket, &QLocalSocket::disconnected, this, [this]() {
        QTimer::singleShot(2000, this, &AppMenu::connectHyprlandEvents);
    });

    connect(m_hyprEventSocket, &QLocalSocket::errorOccurred, this, [this](QLocalSocket::LocalSocketError) {
        QTimer::singleShot(2000, this, &AppMenu::connectHyprlandEvents);
    });

    m_hyprEventSocket->connectToServer(hyprSocketPath(2), QLocalSocket::ReadOnly);
}

void AppMenu::handleHyprlandEvent(const QByteArray &line)
{
    const int sep = line.indexOf(">>");
    if (sep < 0) return;
    const QByteArray event = line.left(sep);

    if (event == "activewindow" || event == "activewindowv2" || event == "closewindow") {
        queryHyprlandActiveWindow();
    }
}

void AppMenu::queryHyprlandActiveWindow()
{
    auto *sock = new QLocalSocket(this);
    auto buffer = std::make_shared<QByteArray>();

    connect(sock, &QLocalSocket::connected, this, [sock]() {
        sock->write("j/activewindow");
        sock->flush();
    });

    connect(sock, &QLocalSocket::readyRead, this, [sock, buffer]() {
        buffer->append(sock->readAll());
    });

    connect(sock, &QLocalSocket::disconnected, this, [this, sock, buffer]() {
        buffer->append(sock->readAll());
        sock->deleteLater();

        const int brace = buffer->indexOf('{');
        if (brace < 0) {
            setActiveWindow(0, QString(), 0);
            return;
        }

        const QJsonDocument doc = QJsonDocument::fromJson(buffer->mid(brace));
        if (!doc.isObject()) {
            setActiveWindow(0, QString(), 0);
            return;
        }

        const QJsonObject obj = doc.object();
        const int pid = obj.value(QStringLiteral("pid")).toInt(0);
        const QString cls = obj.value(QStringLiteral("class")).toString();
        setActiveWindow(pid, cls, 0);
    });

    connect(sock, &QLocalSocket::errorOccurred, this, [sock](QLocalSocket::LocalSocketError) {
        sock->deleteLater();
    });

    sock->connectToServer(hyprSocketPath(1));
}

void AppMenu::registerWindowInternal(uint windowId, const QString &senderService, const QDBusObjectPath &menuObjectPath)
{
    if (senderService.isEmpty() || menuObjectPath.path().isEmpty())
        return;

    auto bus = QDBusConnection::sessionBus();
    uint pid = 0;
    if (bus.interface()) {
        QDBusReply<uint> pidReply = bus.interface()->servicePid(senderService);
        if (pidReply.isValid())
            pid = pidReply.value();
    }

    MenuTarget target{senderService, menuObjectPath.path(), pid};
    m_windowMenus.insert(windowId, target);
    if (pid > 0) {
        m_pidMenus.insert(pid, target);
    }
    m_servicePids.insert(senderService, pid);
    m_serviceWatcher.addWatchedService(senderService);

    Q_EMIT windowRegistered(windowId, senderService, menuObjectPath.path());

    // If this matches the currently focused window, activate it immediately
    if ((m_activeWindowId != 0 && m_activeWindowId == windowId) ||
        (m_activePid != 0 && pidMatchesOrSharesTree(pid, m_activePid))) {
        setCurrentTarget(target.service, target.path);
    }
}

void AppMenu::unregisterWindowInternal(uint windowId)
{
    if (!m_windowMenus.contains(windowId))
        return;

    const MenuTarget target = m_windowMenus.take(windowId);
    Q_EMIT windowUnregistered(windowId);

    if (m_currentService == target.service && m_currentPath == target.path) {
        clearCurrentTarget();
    }
}

QString AppMenu::getMenuForWindowInternal(uint windowId, QDBusObjectPath &menuObjectPath) const
{
    if (m_windowMenus.contains(windowId)) {
        const auto &t = m_windowMenus.value(windowId);
        menuObjectPath = QDBusObjectPath(t.path);
        return t.service;
    }
    menuObjectPath = QDBusObjectPath(QStringLiteral("/"));
    return QString();
}

void AppMenu::onServiceUnregistered(const QString &service)
{
    m_serviceWatcher.removeWatchedService(service);
    m_servicePids.remove(service);

    for (auto it = m_windowMenus.begin(); it != m_windowMenus.end();) {
        if (it.value().service == service)
            it = m_windowMenus.erase(it);
        else
            ++it;
    }

    for (auto it = m_pidMenus.begin(); it != m_pidMenus.end();) {
        if (it.value().service == service)
            it = m_pidMenus.erase(it);
        else
            ++it;
    }

    if (m_currentService == service) {
        clearCurrentTarget();
    }
}

void AppMenu::setActiveWindow(int pid, const QString &appId, uint windowId)
{
    const uint uPid = pid > 0 ? static_cast<uint>(pid) : 0;
    if (m_activePid == uPid && m_activeAppId == appId && m_activeWindowId == windowId)
        return;

    m_activePid = uPid;
    m_activeAppId = appId;
    m_activeWindowId = windowId;

    if (uPid == 0 && windowId == 0) {
        clearCurrentTarget();
        return;
    }

    // 1. Check exact windowId match from Registrar
    if (windowId != 0 && m_windowMenus.contains(windowId)) {
        const auto &t = m_windowMenus.value(windowId);
        setCurrentTarget(t.service, t.path);
        return;
    }

    // 2. Check exact or related PID match from Registrar/cache
    if (uPid != 0) {
        if (m_pidMenus.contains(uPid)) {
            const auto &t = m_pidMenus.value(uPid);
            setCurrentTarget(t.service, t.path);
            return;
        }
        for (auto it = m_pidMenus.constBegin(); it != m_pidMenus.constEnd(); ++it) {
            if (pidMatchesOrSharesTree(it.key(), uPid)) {
                setCurrentTarget(it.value().service, it.value().path);
                return;
            }
        }
    }

    // 3. Clear old menu and actively discover D-Bus services owned by this PID
    clearCurrentTarget();
    if (uPid != 0) {
        discoverMenuForPid(uPid, windowId);
    }
}

void AppMenu::discoverMenuForPid(uint pid, uint /*windowId*/)
{
    auto bus = QDBusConnection::sessionBus();
    if (!bus.isConnected() || !bus.interface())
        return;

    const QDBusReply<QStringList> namesReply = bus.interface()->registeredServiceNames();
    if (!namesReply.isValid())
        return;

    const QStringList services = namesReply.value();
    QStringList matchingServices;

    for (const QString &service : services) {
        // Skip well-known system/desktop services to keep discovery fast
        if (service.startsWith(QLatin1String("org.freedesktop.")) ||
            service.startsWith(QLatin1String("org.kde.StatusNotifier")) ||
            service.startsWith(QLatin1String("org.gtk.vfs")) ||
            service.startsWith(QLatin1String("ca.desrt."))) {
            continue;
        }

        uint sPid = m_servicePids.value(service, 0);
        if (sPid == 0) {
            QDBusReply<uint> pidReply = bus.interface()->servicePid(service);
            if (pidReply.isValid()) {
                sPid = pidReply.value();
                if (service.startsWith(QLatin1Char(':'))) {
                    m_servicePids.insert(service, sPid);
                }
            }
        }

        if (sPid > 0 && pidMatchesOrSharesTree(sPid, pid)) {
            matchingServices.append(service);
        }
    }

    for (const QString &service : matchingServices) {
        probeServiceMenuPaths(service, pid);
    }
}

void AppMenu::probeServiceMenuPaths(const QString &service, uint pid)
{
    // Probe common object paths first (/MenuBar, /MenuBar/1, /MenuBar/2, /com/canonical/menu/...)
    static const QStringList commonPaths = {
        QStringLiteral("/MenuBar"),
        QStringLiteral("/MenuBar/1"),
        QStringLiteral("/MenuBar/2"),
        QStringLiteral("/org/chromium/DbusMenu/1"),
        QStringLiteral("/com/canonical/menu/1")
    };

    introspectForDbusMenu(service, QStringLiteral("/"), pid, 0);

    for (const QString &path : commonPaths) {
        QDBusMessage msg = QDBusMessage::createMethodCall(
            service, path,
            QStringLiteral("com.canonical.dbusmenu"),
            QStringLiteral("GetLayout"));
        msg << 0 << 1 << QStringList();

        auto pending = QDBusConnection::sessionBus().asyncCall(msg, 300);
        auto *watcher = new QDBusPendingCallWatcher(pending, this);
        connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, service, path, pid](QDBusPendingCallWatcher *w) {
            w->deleteLater();
            if (w->isError())
                return;

            MenuTarget target{service, path, pid};
            m_pidMenus.insert(pid, target);
            m_serviceWatcher.addWatchedService(service);

            if (m_activePid == pid && m_currentService.isEmpty()) {
                setCurrentTarget(service, path);
            }
        });
    }
}

void AppMenu::introspectForDbusMenu(const QString &service, const QString &path, uint pid, int depth)
{
    if (depth > 4)
        return;

    QDBusMessage msg = QDBusMessage::createMethodCall(
        service, path,
        QStringLiteral("org.freedesktop.DBus.Introspectable"),
        QStringLiteral("Introspect"));

    auto pending = QDBusConnection::sessionBus().asyncCall(msg, 300);
    auto *watcher = new QDBusPendingCallWatcher(pending, this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, service, path, pid, depth](QDBusPendingCallWatcher *w) {
        w->deleteLater();
        QDBusPendingReply<QString> reply = *w;
        if (reply.isError())
            return;

        const QString xml = reply.value();
        QXmlStreamReader reader(xml);
        bool hasDbusMenu = false;
        QStringList childNodes;

        while (!reader.atEnd()) {
            reader.readNext();
            if (reader.isStartElement()) {
                if (reader.name() == QLatin1String("interface")) {
                    const auto ifaceName = reader.attributes().value(QLatin1String("name"));
                    if (ifaceName == QLatin1String("com.canonical.dbusmenu")) {
                        hasDbusMenu = true;
                    }
                } else if (reader.name() == QLatin1String("node")) {
                    const auto nodeName = reader.attributes().value(QLatin1String("name")).toString();
                    if (!nodeName.isEmpty() && !nodeName.startsWith(QLatin1Char('/'))) {
                        // Avoid StatusNotifierItem tray context menus when looking for main MenuBar,
                        // unless it's the only menu exported
                        childNodes.append(nodeName);
                    }
                }
            }
        }

        if (hasDbusMenu && path != QLatin1String("/")) {
            MenuTarget target{service, path, pid};
            // Prefer /MenuBar over tray menus
            if (!m_pidMenus.contains(pid) || path.contains(QLatin1String("MenuBar"), Qt::CaseInsensitive)) {
                m_pidMenus.insert(pid, target);
                m_serviceWatcher.addWatchedService(service);
                if (m_activePid == pid && (m_currentService.isEmpty() || path.contains(QLatin1String("MenuBar"), Qt::CaseInsensitive))) {
                    setCurrentTarget(service, path);
                }
            }
            return;
        }

        for (const QString &child : childNodes) {
            if (child == QLatin1String("StatusNotifierItem"))
                continue;
            const QString nextPath = (path == QLatin1String("/")) ? (QLatin1Char('/') + child) : (path + QLatin1Char('/') + child);
            introspectForDbusMenu(service, nextPath, pid, depth + 1);
        }
    });
}

void AppMenu::setCurrentTarget(const QString &service, const QString &path)
{
    if (m_currentService == service && m_currentPath == path && !m_menus.isEmpty())
        return;

    auto bus = QDBusConnection::sessionBus();
    if (!m_currentService.isEmpty() && !m_currentPath.isEmpty()) {
        bus.disconnect(m_currentService, m_currentPath,
                       QStringLiteral("com.canonical.dbusmenu"),
                       QStringLiteral("LayoutUpdated"),
                       this, SLOT(onLayoutUpdated(uint,int)));
        bus.disconnect(m_currentService, m_currentPath,
                       QStringLiteral("com.canonical.dbusmenu"),
                       QStringLiteral("ItemsPropertiesUpdated"),
                       this, SLOT(onItemsPropertiesUpdated(SleexDBusMenuItemPropertiesList,SleexDBusMenuItemPropertyNamesList)));
    }

    m_currentService = service;
    m_currentPath = path;
    Q_EMIT currentMenuChanged();

    if (service.isEmpty() || path.isEmpty()) {
        if (!m_menus.isEmpty()) {
            m_menus.clear();
            Q_EMIT menusChanged();
            Q_EMIT hasNativeMenuChanged();
        }
        return;
    }

    bus.connect(m_currentService, m_currentPath,
                QStringLiteral("com.canonical.dbusmenu"),
                QStringLiteral("LayoutUpdated"),
                this, SLOT(onLayoutUpdated(uint,int)));
    bus.connect(m_currentService, m_currentPath,
                QStringLiteral("com.canonical.dbusmenu"),
                QStringLiteral("ItemsPropertiesUpdated"),
                this, SLOT(onItemsPropertiesUpdated(SleexDBusMenuItemPropertiesList,SleexDBusMenuItemPropertyNamesList)));

    prepareMenu(0);
}

void AppMenu::clearCurrentTarget()
{
    setCurrentTarget(QString(), QString());
}

void AppMenu::onLayoutUpdated(uint /*revision*/, int /*parent*/)
{
    refreshLayout(0);
}

void AppMenu::onItemsPropertiesUpdated(const SleexDBusMenuItemPropertiesList & /*updatedProps*/,
                                       const SleexDBusMenuItemPropertyNamesList & /*removedProps*/)
{
    refreshLayout(0);
}

void AppMenu::prepareMenu(int itemId)
{
    if (m_currentService.isEmpty() || m_currentPath.isEmpty())
        return;

    if (itemId != 0) {
        QDBusMessage openEvent = QDBusMessage::createMethodCall(
            m_currentService, m_currentPath,
            QStringLiteral("com.canonical.dbusmenu"),
            QStringLiteral("Event"));
        openEvent << itemId
                  << QStringLiteral("opened")
                  << QVariant::fromValue(QDBusVariant(0))
                  << static_cast<uint>(QDateTime::currentSecsSinceEpoch());
        QDBusConnection::sessionBus().asyncCall(openEvent);
    }

    QDBusMessage msg = QDBusMessage::createMethodCall(
        m_currentService, m_currentPath,
        QStringLiteral("com.canonical.dbusmenu"),
        QStringLiteral("AboutToShow"));
    msg << itemId;

    const QString expectedService = m_currentService;
    const QString expectedPath = m_currentPath;

    auto pending = QDBusConnection::sessionBus().asyncCall(msg, 500);
    auto *watcher = new QDBusPendingCallWatcher(pending, this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, expectedService, expectedPath](QDBusPendingCallWatcher *w) {
        w->deleteLater();
        if (m_currentService != expectedService || m_currentPath != expectedPath)
            return;
        refreshLayout(0);
    });
}

void AppMenu::refreshLayout(int parentId)
{
    if (m_currentService.isEmpty() || m_currentPath.isEmpty())
        return;

    QDBusMessage msg = QDBusMessage::createMethodCall(
        m_currentService, m_currentPath,
        QStringLiteral("com.canonical.dbusmenu"),
        QStringLiteral("GetLayout"));
    msg << parentId << -1 << QStringList();

    const QString expectedService = m_currentService;
    const QString expectedPath = m_currentPath;

    auto pending = QDBusConnection::sessionBus().asyncCall(msg, 1000);
    auto *watcher = new QDBusPendingCallWatcher(pending, this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, expectedService, expectedPath](QDBusPendingCallWatcher *w) {
        w->deleteLater();
        if (m_currentService != expectedService || m_currentPath != expectedPath)
            return;

        QDBusPendingReply<uint, SleexDBusMenuLayoutItem> reply = *w;
        if (reply.isError()) {
            return;
        }

        const SleexDBusMenuLayoutItem rootLayout = reply.argumentAt<1>();
        QVariantList newMenus;

        for (const auto &topChild : rootLayout.children) {
            const bool visible = topChild.properties.value(QStringLiteral("visible"), true).toBool();
            const bool enabled = topChild.properties.value(QStringLiteral("enabled"), true).toBool();
            const bool isSep = topChild.properties.value(QStringLiteral("type")).toString() == QLatin1String("separator");
            if (!visible || !enabled || isSep)
                continue;

            QVariantMap menuMap = layoutToVariantMap(topChild);
            const QString menuName = menuMap.value(QStringLiteral("name")).toString();
            const QVariantList items = menuMap.value(QStringLiteral("items")).toList();
            if (!menuName.isEmpty() && !items.isEmpty()) {
                newMenus.append(menuMap);
            }
        }

        const bool hadNative = hasNativeMenu();
        m_menus = newMenus;
        Q_EMIT menusChanged();
        if (hadNative != hasNativeMenu()) {
            Q_EMIT hasNativeMenuChanged();
        }
    });
}

void AppMenu::trigger(int itemId)
{
    if (m_currentService.isEmpty() || m_currentPath.isEmpty())
        return;

    QDBusMessage msg = QDBusMessage::createMethodCall(
        m_currentService, m_currentPath,
        QStringLiteral("com.canonical.dbusmenu"),
        QStringLiteral("Event"));
    msg << itemId
        << QStringLiteral("clicked")
        << QVariant::fromValue(QDBusVariant(0))
        << static_cast<uint>(QDateTime::currentSecsSinceEpoch());

    QDBusConnection::sessionBus().asyncCall(msg);
}

QVariantMap AppMenu::layoutToVariantMap(const SleexDBusMenuLayoutItem &item) const
{
    QVariantMap map;
    map[QStringLiteral("itemId")] = item.id;

    const QString rawLabel = item.properties.value(QStringLiteral("label")).toString();
    map[QStringLiteral("name")] = cleanMnemonicLabel(rawLabel);

    const bool isSep = item.properties.value(QStringLiteral("type")).toString() == QLatin1String("separator");
    map[QStringLiteral("isSeparator")] = isSep;

    const bool enabled = item.properties.value(QStringLiteral("enabled"), true).toBool();
    map[QStringLiteral("enabled")] = enabled;

    const bool visible = item.properties.value(QStringLiteral("visible"), true).toBool();
    map[QStringLiteral("visible")] = visible;

    const QString iconName = item.properties.value(QStringLiteral("icon-name")).toString();
    map[QStringLiteral("iconName")] = iconName;

    const QString toggleType = item.properties.value(QStringLiteral("toggle-type")).toString();
    map[QStringLiteral("toggleType")] = toggleType; // "checkmark", "radio", or ""

    const int toggleState = item.properties.value(QStringLiteral("toggle-state"), 0).toInt();
    map[QStringLiteral("toggleState")] = toggleState; // 1 = checked

    map[QStringLiteral("shortcut")] = formatShortcut(item.properties.value(QStringLiteral("shortcut")));

    QVariantList childItems;
    for (const auto &child : item.children) {
        const bool childVisible = child.properties.value(QStringLiteral("visible"), true).toBool();
        const bool childEnabled = child.properties.value(QStringLiteral("enabled"), true).toBool();
        const bool childIsSep = child.properties.value(QStringLiteral("type")).toString() == QLatin1String("separator");
        if (!childVisible || (!childIsSep && !childEnabled))
            continue;

        QVariantMap childMap = layoutToVariantMap(child);
        if (childIsSep) {
            if (!childItems.isEmpty() && !childItems.last().toMap().value(QStringLiteral("isSeparator")).toBool()) {
                childItems.append(childMap);
            }
            continue;
        }

        const QString childName = childMap.value(QStringLiteral("name")).toString().trimmed();
        if (childName.isEmpty())
            continue;

        const bool isSubmenuContainer = child.properties.value(QStringLiteral("children-display")).toString() == QLatin1String("submenu");
        if (isSubmenuContainer && childMap.value(QStringLiteral("items")).toList().isEmpty())
            continue;

        childItems.append(childMap);
    }

    while (!childItems.isEmpty() && childItems.last().toMap().value(QStringLiteral("isSeparator")).toBool()) {
        childItems.removeLast();
    }

    map[QStringLiteral("items")] = childItems;
    map[QStringLiteral("hasChildren")] = !childItems.isEmpty();

    return map;
}

QString AppMenu::cleanMnemonicLabel(const QString &raw)
{
    QString out;
    out.reserve(raw.size());
    for (int i = 0; i < raw.size(); ++i) {
        if (raw[i] == QLatin1Char('_')) {
            if (i + 1 < raw.size() && raw[i + 1] == QLatin1Char('_')) {
                out.append(QLatin1Char('_'));
                ++i;
            }
            continue;
        }
        out.append(raw[i]);
    }
    return out;
}

QString AppMenu::formatShortcut(const QVariant &shortcutVar)
{
    if (!shortcutVar.isValid())
        return QString();

    // DBusMenu shortcut is aas (array of array of strings), e.g. [["Control", "Shift", "S"]]
    QStringList tokens;
    if (shortcutVar.canConvert<QDBusArgument>()) {
        const QDBusArgument arg = shortcutVar.value<QDBusArgument>();
        if (arg.currentType() == QDBusArgument::ArrayType) {
            arg.beginArray();
            if (!arg.atEnd()) {
                QStringList combo;
                arg >> combo;
                tokens = combo;
            }
            arg.endArray();
        }
    } else if (shortcutVar.typeId() == QMetaType::QVariantList) {
        const QVariantList outer = shortcutVar.toList();
        if (!outer.isEmpty()) {
            tokens = outer.first().toStringList();
        }
    }

    if (tokens.isEmpty())
        return QString();

    QStringList formatted;
    for (QString tok : tokens) {
        if (tok.compare(QLatin1String("Control"), Qt::CaseInsensitive) == 0 ||
            tok.compare(QLatin1String("Primary"), Qt::CaseInsensitive) == 0) {
            formatted.append(QStringLiteral("Ctrl"));
        } else if (tok.compare(QLatin1String("Mod1"), Qt::CaseInsensitive) == 0) {
            formatted.append(QStringLiteral("Alt"));
        } else if (tok.compare(QLatin1String("Super"), Qt::CaseInsensitive) == 0 ||
                   tok.compare(QLatin1String("Meta"), Qt::CaseInsensitive) == 0) {
            formatted.append(QStringLiteral("Super"));
        } else if (tok.compare(QLatin1String("plus"), Qt::CaseInsensitive) == 0) {
            formatted.append(QStringLiteral("+"));
        } else if (tok.compare(QLatin1String("minus"), Qt::CaseInsensitive) == 0) {
            formatted.append(QStringLiteral("-"));
        } else if (tok.length() == 1) {
            formatted.append(tok.toUpper());
        } else {
            formatted.append(tok);
        }
    }
    return formatted.join(QLatin1Char('+'));
}

} // namespace sleex::services
