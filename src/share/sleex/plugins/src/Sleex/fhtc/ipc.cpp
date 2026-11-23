#include "ipc.hpp"

#include <QCoreApplication>
#include <QDebug>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QSet>
#include <QTimer>

namespace sleex::fhtc {

namespace {

/**
 * @brief Checks whether a given action name is a unit variant in `fht_compositor_ipc::Action`.
 * @param name Kebab-case action name.
 * @return `true` if the action serializes as a bare JSON string when called without arguments.
 */
bool isUnitAction(const QString &name)
{
    static const QSet<QString> kUnitActions = {
        QStringLiteral("quit"),
        QStringLiteral("disable-outputs"),
        QStringLiteral("reload-config"),
        QStringLiteral("focus-next-output"),
        QStringLiteral("focus-previous-output"),
    };
    return kUnitActions.contains(name);
}

} // namespace

Ipc *Ipc::instance()
{
    static Ipc *s_instance = new Ipc(QCoreApplication::instance());
    return s_instance;
}

Ipc *Ipc::create(QQmlEngine *qmlEngine, QJSEngine *jsEngine)
{
    Q_UNUSED(qmlEngine);
    Ipc *inst = instance();
    QJSEngine::setObjectOwnership(inst, QJSEngine::CppOwnership);
    Q_UNUSED(jsEngine);
    return inst;
}

Ipc::Ipc(QObject *parent)
    : QObject(parent)
    , m_eventSocket(new QLocalSocket(this))
    , m_reqSocket(new QLocalSocket(this))
{
    // Event stream socket setup
    connect(m_eventSocket, &QLocalSocket::connected, this, [this]() {
        m_connected = true;
        emit connectedChanged();
        writeJson(m_eventSocket, QStringLiteral("subscribe"));
    });

    connect(m_eventSocket, &QLocalSocket::disconnected, this, [this]() {
        m_connected = false;
        emit connectedChanged();
        QTimer::singleShot(1000, this, &Ipc::connectEventSocket);
    });

    connect(m_eventSocket, &QLocalSocket::readyRead, this, &Ipc::onEventReadyRead);

    connect(m_eventSocket, &QLocalSocket::errorOccurred, this, [this](QLocalSocket::LocalSocketError) {
        emit errorOccurred(m_eventSocket->errorString());
        if (m_eventSocket->state() == QLocalSocket::UnconnectedState) {
            QTimer::singleShot(1000, this, &Ipc::connectEventSocket);
        }
    });

    // Request/response socket setup
    connect(m_reqSocket, &QLocalSocket::connected, this, [this]() {
        if (!m_queue.isEmpty()) {
            writeJson(m_reqSocket, m_queue.head().payload);
        }
    });

    connect(m_reqSocket, &QLocalSocket::readyRead, this, &Ipc::onRequestReadyRead);

    connect(m_reqSocket, &QLocalSocket::disconnected, this, [this]() {
        if (m_reqInFlight) {
            m_reqInFlight = false;
            processNextRequest();
        }
    });

    connect(m_reqSocket, &QLocalSocket::errorOccurred, this, [this](QLocalSocket::LocalSocketError) {
        emit errorOccurred(m_reqSocket->errorString());
        if (m_reqInFlight && !m_queue.isEmpty()) {
            m_queue.dequeue();
            m_reqInFlight = false;
            processNextRequest();
        }
    });

    connectEventSocket();
}

Ipc::~Ipc()
{
    m_eventSocket->abort();
    m_reqSocket->abort();
}

QString Ipc::socketPath() const
{
    return qEnvironmentVariable("FHTC_SOCKET_PATH");
}

void Ipc::connectEventSocket()
{
    if (m_eventSocket->state() != QLocalSocket::UnconnectedState) {
        return;
    }

    const QString path = socketPath();
    if (path.isEmpty()) {
        qWarning() << "Sleex.Fhtc: FHTC_SOCKET_PATH is not set";
        QTimer::singleShot(2000, this, &Ipc::connectEventSocket);
        return;
    }
    m_eventSocket->connectToServer(path);
}

void Ipc::onEventReadyRead()
{
    m_eventBuf.append(m_eventSocket->readAll());

    while (true) {
        const int idx = m_eventBuf.indexOf('\n');
        if (idx < 0) {
            break;
        }

        const QByteArray line = m_eventBuf.left(idx).trimmed();
        m_eventBuf.remove(0, idx + 1);

        if (line.isEmpty()) {
            continue;
        }

        const QVariant parsed = parseLine(line);
        if (parsed.typeId() != QMetaType::QVariantMap) {
            continue;
        }

        const QVariantMap map = parsed.toMap();
        const QString ev = map.value(QStringLiteral("event")).toString();
        if (!ev.isEmpty()) {
            const QVariant data = map.value(QStringLiteral("data"));
            updateCachedState(ev, data);
            emit eventReceived(ev, data);
        }
    }
}

void Ipc::updateCachedState(const QString &event, const QVariant &data)
{
    if (event == QLatin1String("windows")) {
        m_cachedWindows = data.toMap();
        m_hasCachedWindows = true;
    } else if (event == QLatin1String("window-changed")) {
        const QVariantMap win = data.toMap();
        const QString id = QString::number(win.value(QStringLiteral("id")).toInt());
        m_cachedWindows.insert(id, win);
        m_hasCachedWindows = true;
    } else if (event == QLatin1String("window-closed")) {
        const QString id = QString::number(data.toMap().value(QStringLiteral("id")).toInt());
        m_cachedWindows.remove(id);
    } else if (event == QLatin1String("workspaces")) {
        m_cachedWorkspaces = data.toMap();
        m_hasCachedWorkspaces = true;
    } else if (event == QLatin1String("workspace-changed")) {
        const QVariantMap ws = data.toMap();
        const QString id = QString::number(ws.value(QStringLiteral("id")).toInt());
        m_cachedWorkspaces.insert(id, ws);
        m_hasCachedWorkspaces = true;
    } else if (event == QLatin1String("workspace-removed")) {
        const QString id = QString::number(data.toMap().value(QStringLiteral("id")).toInt());
        m_cachedWorkspaces.remove(id);
    } else {
        m_lastEvents.insert(event, data);
    }
}

void Ipc::replayCachedEvents(const std::function<void(const QString &event, const QVariant &data)> &handler) const
{
    if (!handler) {
        return;
    }

    if (m_hasCachedWindows) {
        handler(QStringLiteral("windows"), m_cachedWindows);
    }
    if (m_lastEvents.contains(QStringLiteral("focused-window-changed"))) {
        handler(QStringLiteral("focused-window-changed"), m_lastEvents.value(QStringLiteral("focused-window-changed")));
    }
    if (m_hasCachedWorkspaces) {
        handler(QStringLiteral("workspaces"), m_cachedWorkspaces);
    }
    if (m_lastEvents.contains(QStringLiteral("active-workspace-changed"))) {
        handler(QStringLiteral("active-workspace-changed"), m_lastEvents.value(QStringLiteral("active-workspace-changed")));
    }
    if (m_lastEvents.contains(QStringLiteral("space"))) {
        handler(QStringLiteral("space"), m_lastEvents.value(QStringLiteral("space")));
    }
    if (m_lastEvents.contains(QStringLiteral("layer-shells"))) {
        handler(QStringLiteral("layer-shells"), m_lastEvents.value(QStringLiteral("layer-shells")));
    }
}

void Ipc::request(const QVariant &req, const QJSValue &callback)
{
    request(req, [callback](const QVariant &res) mutable {
        if (callback.isCallable()) {
            QJSEngine *engine = qjsEngine(callback.toQObject());
            if (!engine) {
                engine = qjsEngine(Ipc::instance());
            }
            if (engine) {
                callback.call({engine->toScriptValue(res)});
            }
        }
    });
}

void Ipc::request(const QVariant &req, std::function<void(const QVariant &)> cb)
{
    m_queue.enqueue({req, std::move(cb)});
    if (!m_reqInFlight) {
        processNextRequest();
    }
}

void Ipc::dispatch(const QString &name, const QVariantMap &args)
{
    QVariantMap req;
    if (args.isEmpty() && isUnitAction(name)) {
        req.insert(QStringLiteral("action"), name);
    } else {
        QVariantMap actionArgs = args;
        if (name == QLatin1String("close-window") && !actionArgs.contains(QStringLiteral("kill"))) {
            actionArgs.insert(QStringLiteral("kill"), false);
        }
        QVariantMap actionObj;
        actionObj.insert(name, actionArgs);
        req.insert(QStringLiteral("action"), actionObj);
    }
    request(req, std::function<void(const QVariant &)>{});
}

void Ipc::processNextRequest()
{
    if (m_queue.isEmpty() || m_reqInFlight) {
        return;
    }

    const QString path = socketPath();
    if (path.isEmpty()) {
        m_queue.clear();
        return;
    }

    m_reqInFlight = true;

    if (m_reqSocket->state() == QLocalSocket::ConnectedState) {
        writeJson(m_reqSocket, m_queue.head().payload);
    } else if (m_reqSocket->state() == QLocalSocket::UnconnectedState) {
        m_reqSocket->connectToServer(path);
    }
}

void Ipc::onRequestReadyRead()
{
    m_reqBuf.append(m_reqSocket->readAll());

    while (true) {
        const int idx = m_reqBuf.indexOf('\n');
        if (idx < 0) {
            break;
        }

        const QByteArray line = m_reqBuf.left(idx).trimmed();
        m_reqBuf.remove(0, idx + 1);

        if (line.isEmpty()) {
            continue;
        }

        const QVariant res = parseLine(line);
        if (!m_queue.isEmpty()) {
            const PendingRequest done = m_queue.dequeue();
            if (done.callback) {
                done.callback(res);
            }
        }

        m_reqInFlight = false;
        processNextRequest();
    }
}

void Ipc::writeJson(QLocalSocket *sock, const QVariant &v)
{
    QByteArray data;
    if (v.typeId() == QMetaType::QVariantMap) {
        data = QJsonDocument(QJsonObject::fromVariantMap(v.toMap())).toJson(QJsonDocument::Compact);
    } else if (v.typeId() == QMetaType::QVariantList) {
        data = QJsonDocument(QJsonArray::fromVariantList(v.toList())).toJson(QJsonDocument::Compact);
    } else if (v.typeId() == QMetaType::QString) {
        // Serialize top-level string primitive via a single-element JSON array and strip '[' / ']'.
        const QByteArray arrJson = QJsonDocument(QJsonArray{v.toString()}).toJson(QJsonDocument::Compact);
        if (arrJson.size() >= 2 && arrJson.startsWith('[') && arrJson.endsWith(']')) {
            data = arrJson.mid(1, arrJson.size() - 2);
        } else {
            data = "\"" + v.toString().toUtf8() + "\"";
        }
    } else {
        data = QJsonDocument::fromVariant(v).toJson(QJsonDocument::Compact);
    }

    data.append('\n');
    sock->write(data);
    sock->flush();
}

QVariant Ipc::parseLine(const QByteArray &line)
{
    const QByteArray trimmed = line.trimmed();
    if (trimmed.isEmpty()) {
        return {};
    }

    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(trimmed, &err);
    if (err.error == QJsonParseError::NoError) {
        if (doc.isObject()) {
            return doc.object().toVariantMap();
        }
        if (doc.isArray()) {
            return doc.array().toVariantList();
        }
    }

    // Handle top-level JSON string primitives such as `"noop"`.
    if (trimmed.startsWith('"') && trimmed.endsWith('"')) {
        QJsonParseError strErr;
        const QJsonDocument wrapped = QJsonDocument::fromJson("[" + trimmed + "]", &strErr);
        if (strErr.error == QJsonParseError::NoError && wrapped.isArray() && !wrapped.array().isEmpty()) {
            return wrapped.array().at(0).toVariant();
        }
    }

    qWarning() << "Sleex.Fhtc: JSON parse error:" << err.errorString() << "Input:" << line;
    return {};
}

} // namespace sleex::fhtc
