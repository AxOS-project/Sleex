#include "monitors.hpp"

#include <QDir>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QSet>
#include <QStandardPaths>
#include <QTextStream>
#include <algorithm>
#include <cmath>

namespace sleex::services {

Monitors::Monitors(QObject *parent) : QObject(parent)
{
    m_pollTimer = new QTimer(this);
    m_pollTimer->setInterval(10000);
    connect(m_pollTimer, &QTimer::timeout, this, &Monitors::refresh);
    m_pollTimer->start();

    m_reconnectTimer = new QTimer(this);
    m_reconnectTimer->setSingleShot(true);
    connect(m_reconnectTimer, &QTimer::timeout, this, &Monitors::connectEventSocket);

    connectEventSocket();
    refresh();
}

Monitors::~Monitors()
{
    qDeleteAll(m_monitors);
}

QString Monitors::socketPath()
{
    return qEnvironmentVariable("FHTC_SOCKET_PATH");
}

void Monitors::sendRequest(const QByteArray &jsonLine,
                           std::function<void(bool, const QByteArray &)> cb)
{
    const QString path = socketPath();
    if (path.isEmpty()) {
        cb(false, {});
        return;
    }

    auto *sock = new QLocalSocket(this);
    auto buffer = std::make_shared<QByteArray>();
    auto completed = std::make_shared<bool>(false);

    connect(sock, &QLocalSocket::connected, this, [sock, jsonLine]() {
        sock->write(jsonLine + '\n');
        sock->flush();
    });

    connect(sock, &QLocalSocket::readyRead, this, [sock, buffer, completed, cb]() {
        buffer->append(sock->readAll());
        const int nl = buffer->indexOf('\n');
        if (nl >= 0 && !*completed) {
            *completed = true;
            const QByteArray line = buffer->left(nl).trimmed();
            const QJsonDocument doc = QJsonDocument::fromJson(line);
            const bool isError = doc.isObject() && doc.object().contains(QStringLiteral("error"));
            cb(!isError, line);
            sock->disconnectFromServer();
            sock->deleteLater();
        }
    });

    connect(sock, &QLocalSocket::disconnected, this, [sock, buffer, completed, cb]() {
        if (!*completed) {
            *completed = true;
            buffer->append(sock->readAll());
            const QByteArray line = buffer->trimmed();
            const bool ok = !line.isEmpty() && !(QJsonDocument::fromJson(line).isObject() &&
                                                 QJsonDocument::fromJson(line).object().contains(QStringLiteral("error")));
            cb(ok, line);
        }
        sock->deleteLater();
    });

    connect(sock, &QLocalSocket::errorOccurred, this,
            [sock, completed, cb](QLocalSocket::LocalSocketError) {
                if (!*completed) {
                    *completed = true;
                    cb(false, {});
                }
                sock->deleteLater();
            });

    sock->connectToServer(path);
}

void Monitors::connectEventSocket()
{
    if (m_eventSocket) {
        m_eventSocket->deleteLater();
        m_eventSocket = nullptr;
    }

    const QString path = socketPath();
    if (path.isEmpty()) {
        if (!m_reconnectTimer->isActive())
            m_reconnectTimer->start(2000);
        return;
    }

    m_eventSocket = new QLocalSocket(this);

    connect(m_eventSocket, &QLocalSocket::connected, this, [this]() {
        m_eventSocket->write("\"subscribe\"\n");
        m_eventSocket->flush();
    });

    connect(m_eventSocket, &QLocalSocket::readyRead, this, [this]() {
        m_eventBuffer += m_eventSocket->readAll();
        while (true) {
            const int nl = m_eventBuffer.indexOf('\n');
            if (nl < 0)
                break;
            handleEventLine(m_eventBuffer.left(nl).trimmed());
            m_eventBuffer.remove(0, nl + 1);
        }
    });

    connect(m_eventSocket, &QLocalSocket::disconnected, this, [this]() {
        if (!m_reconnectTimer->isActive())
            m_reconnectTimer->start(2000);
    });

    connect(m_eventSocket, &QLocalSocket::errorOccurred, this,
            [this](QLocalSocket::LocalSocketError) {
                if (!m_reconnectTimer->isActive())
                    m_reconnectTimer->start(2000);
            });

    m_eventSocket->connectToServer(path);
}

void Monitors::handleEventLine(const QByteArray &line)
{
    if (line.isEmpty())
        return;

    const QJsonDocument doc = QJsonDocument::fromJson(line);
    if (!doc.isObject())
        return;

    const QJsonObject root = doc.object();
    const QString event = root.value(QStringLiteral("event")).toString();
    if (event == QLatin1String("space")) {
        const QJsonObject spaceObj = root.value(QStringLiteral("data")).toObject();
        m_spaceMonitors = spaceObj.value(QStringLiteral("monitors")).toObject().toVariantMap();
        refresh();
    }
}

void Monitors::refresh()
{
    sendRequest(QByteArrayLiteral("\"space\""),
                [this](bool spaceOk, const QByteArray &spaceRaw) {
                    if (spaceOk) {
                        const QJsonDocument spaceDoc = QJsonDocument::fromJson(spaceRaw);
                        if (spaceDoc.isObject()) {
                            const QJsonObject spaceObj = spaceDoc.object().value(QStringLiteral("space")).toObject();
                            if (!spaceObj.isEmpty()) {
                                m_spaceMonitors = spaceObj.value(QStringLiteral("monitors")).toObject().toVariantMap();
                            }
                        }
                    }

                    sendRequest(QByteArrayLiteral("\"outputs\""),
                                [this](bool ok, const QByteArray &raw) {
                                    if (!ok) {
                                        setError(QStringLiteral("outputs request failed"));
                                        return;
                                    }
                                    parseFhtcOutputs(raw);
                                });
                });
}

void Monitors::applyPosition(const QString &name, int x, int y)
{
    applyRule(name, -1, -1, qQNaN(), qMax(0, x), qMax(0, y), qQNaN());
}

void Monitors::applyAllPositions(const QVariantList &changes)
{
    if (changes.isEmpty())
        return;

    for (const QVariant &v : changes) {
        const QVariantMap m = v.toMap();
        const QString name = m.value(QStringLiteral("name")).toString();
        MonitorInfo *mi = findMonitor(name);
        if (!mi)
            continue;
        mi->setX(qMax(0, m.value(QStringLiteral("x")).toInt()));
        mi->setY(qMax(0, m.value(QStringLiteral("y")).toInt()));
    }

    if (!saveMonitorsConfig()) {
        setError(QStringLiteral("Failed to write ~/.config/fht/monitors.toml"));
        emit applyFailed(m_lastError);
        return;
    }

    reloadCompositorConfig();
}

void Monitors::applyChanges(const QVariantList &changes)
{
    if (changes.isEmpty())
        return;

    for (const QVariant &v : changes) {
        const QVariantMap m = v.toMap();
        const QString name = m.value(QStringLiteral("name")).toString();
        MonitorInfo *mi = findMonitor(name);
        if (!mi)
            continue;

        if (m.contains(QStringLiteral("x")))
            mi->setX(m.value(QStringLiteral("x")).toInt());
        if (m.contains(QStringLiteral("y")))
            mi->setY(m.value(QStringLiteral("y")).toInt());
        if (m.contains(QStringLiteral("scale")))
            mi->setScale(qBound(0.25, m.value(QStringLiteral("scale")).toDouble(), 3.0));
        if (m.contains(QStringLiteral("mirror")))
            mi->setMirrorOf(m.value(QStringLiteral("mirror")).toString());
        if (m.contains(QStringLiteral("mode"))) {
            const QString mode = m.value(QStringLiteral("mode")).toString();
            const QStringList parts = mode.split(QLatin1Char('x'));
            if (parts.size() == 2) {
                mi->setWidth(parts[0].toInt());
                mi->setHeight(parts[1].toInt());
                const double modeRr = m_modeRefreshRates.value(name).value(mode, 0.0);
                if (modeRr > 0.0) {
                    mi->setRefreshRate(modeRr);
                }
            }
        }
    }

    if (!saveMonitorsConfig()) {
        setError(QStringLiteral("Failed to write ~/.config/fht/monitors.toml"));
        emit applyFailed(m_lastError);
        return;
    }

    reloadCompositorConfig();
}

void Monitors::applyScale(const QString &name, double scale)
{
    applyRule(name, -1, -1, qQNaN(), -1, -1, qBound(0.25, scale, 3.0));
}

void Monitors::applyMode(const QString &name, const QString &mode)
{
    const QStringList parts = mode.split(QLatin1Char('x'));
    if (parts.size() != 2) {
        setError(QStringLiteral("Invalid mode string: ") + mode);
        return;
    }
    bool wOk = false, hOk = false;
    const int w = parts[0].toInt(&wOk);
    const int h = parts[1].toInt(&hOk);
    if (!wOk || !hOk || w <= 0 || h <= 0) {
        setError(QStringLiteral("Invalid mode dimensions: ") + mode);
        return;
    }
    const double rr = m_modeRefreshRates.value(name).value(mode, qQNaN());
    applyRule(name, w, h, rr, -1, -1, qQNaN());
}

void Monitors::applyMirror(const QString &name, const QString & /*mirrorTarget*/)
{
    setError(QStringLiteral("Display mirroring is not supported by fht-compositor (") + name + QStringLiteral(")"));
    emit applyFailed(m_lastError);
}

void Monitors::resetPositions()
{
    refresh();
}

void Monitors::applyRule(const QString &name,
                         int            newW,
                         int            newH,
                         double         newRR,
                         int            newX,
                         int            newY,
                         double         newScale)
{
    MonitorInfo *mi = findMonitor(name);
    if (!mi) {
        setError(QStringLiteral("Monitor not found: ") + name);
        return;
    }

    if (newW > 0)
        mi->setWidth(newW);
    if (newH > 0)
        mi->setHeight(newH);
    if (!std::isnan(newRR) && newRR > 0.0)
        mi->setRefreshRate(newRR);
    if (newX >= 0)
        mi->setX(newX);
    if (newY >= 0)
        mi->setY(newY);
    if (!std::isnan(newScale))
        mi->setScale(qBound(0.25, newScale, 3.0));

    if (!saveMonitorsConfig()) {
        setError(QStringLiteral("Failed to write ~/.config/fht/monitors.toml"));
        emit applyFailed(m_lastError);
        return;
    }

    reloadCompositorConfig();
}

void Monitors::reloadCompositorConfig()
{
    setBusy(true);
    sendRequest(QByteArrayLiteral("{\"action\":\"reload-config\"}"),
                [this](bool ok, const QByteArray &) {
                    setBusy(false);
                    if (!ok) {
                        setError(QStringLiteral("Failed to reload fht-compositor configuration"));
                        emit applyFailed(m_lastError);
                    } else {
                        setError(QString());
                        QTimer::singleShot(350, this, &Monitors::refresh);
                        emit applySucceeded();
                    }
                });
}

void Monitors::parseFhtcOutputs(const QByteArray &raw)
{
    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(raw, &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) {
        setError(QStringLiteral("JSON parse error: ") + err.errorString());
        return;
    }

    const QJsonObject root = doc.object();
    const QJsonObject outputsObj = root.contains(QStringLiteral("outputs"))
                                       ? root.value(QStringLiteral("outputs")).toObject()
                                       : root;

    QMap<QString, MonitorInfo*> existing;
    for (QObject *obj : std::as_const(m_monitors)) {
        auto *mi = qobject_cast<MonitorInfo*>(obj);
        if (mi)
            existing.insert(mi->name(), mi);
    }

    QList<QObject*> newList;
    QSet<QString> seen;

    QStringList outputNames = outputsObj.keys();
    outputNames.sort();

    for (const QString &key : outputNames) {
        const QJsonObject o = outputsObj.value(key).toObject();
        const QString name = o.value(QStringLiteral("name")).toString(key);
        if (name.isEmpty())
            continue;
        seen.insert(name);

        const QJsonArray posArr = o.value(QStringLiteral("position")).toArray();
        const int x = posArr.size() >= 1 ? posArr.at(0).toInt(0) : 0;
        const int y = posArr.size() >= 2 ? posArr.at(1).toInt(0) : 0;

        const QJsonArray sizeArr = o.value(QStringLiteral("size")).toArray();
        int w = sizeArr.size() >= 1 ? sizeArr.at(0).toInt(1920) : 1920;
        int h = sizeArr.size() >= 2 ? sizeArr.at(1).toInt(1080) : 1080;

        const double scale = static_cast<double>(qMax(1, o.value(QStringLiteral("scale")).toInt(1)));
        double refreshRate = 60.0;

        const QJsonArray modesArr = o.value(QStringLiteral("modes")).toArray();
        const QJsonValue activeIdxVal = o.value(QStringLiteral("active-mode-idx"));
        const int activeModeIdx = (activeIdxVal.isNull() || activeIdxVal.isUndefined())
                                      ? -1
                                      : activeIdxVal.toInt(-1);

        QStringList modes;
        QHash<QString, double> refreshByRes;

        for (int i = 0; i < modesArr.size(); ++i) {
            const QJsonObject modeObj = modesArr.at(i).toObject();
            const QJsonArray dims = modeObj.value(QStringLiteral("dimensions")).toArray();
            if (dims.size() < 2)
                continue;
            const int mw = dims.at(0).toInt();
            const int mh = dims.at(1).toInt();
            const double mrr = modeObj.value(QStringLiteral("refresh")).toDouble(60.0);
            const bool preferred = modeObj.value(QStringLiteral("preferred")).toBool(false);

            const QString res = QStringLiteral("%1x%2").arg(mw).arg(mh);
            if (!modes.contains(res)) {
                modes.append(res);
            }
            if (!refreshByRes.contains(res) || preferred || mrr > refreshByRes.value(res)) {
                refreshByRes.insert(res, mrr);
            }

            if (i == activeModeIdx) {
                w = mw;
                h = mh;
                refreshRate = mrr;
            }
        }
        m_modeRefreshRates.insert(name, refreshByRes);

        std::sort(modes.begin(), modes.end(), [](const QString &a, const QString &b) {
            auto px = [](const QString &s) {
                const QStringList p = s.split(QLatin1Char('x'));
                return (p.size() == 2) ? p[0].toInt() * p[1].toInt() : 0;
            };
            return px(a) > px(b);
        });

        const QVariantMap spaceMon = m_spaceMonitors.value(name).toMap();
        const bool enabled = true;
        const bool primary = spaceMon.value(QStringLiteral("active")).toBool();
        const QString make = o.value(QStringLiteral("make")).toString();
        const QString model = o.value(QStringLiteral("model")).toString();

        MonitorInfo *mi = existing.value(name, nullptr);
        if (!mi)
            mi = new MonitorInfo(this);

        mi->setAll(name, x, y, w, h, scale, refreshRate,
                   enabled, primary, make, model, modes, QString());
        newList.append(mi);
    }

    for (auto it = existing.begin(); it != existing.end(); ++it) {
        if (!seen.contains(it.key())) {
            it.value()->deleteLater();
        }
    }

    m_monitors = newList;

    // Ensure ~/.config/fht/monitors.toml exists on first discovery without overwriting manual edits on every poll
    QString configDir = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation);
    if (configDir.isEmpty()) {
        configDir = QDir::homePath() + QStringLiteral("/.config");
    }
    const QFileInfo cfgInfo(configDir + QStringLiteral("/fht/monitors.toml"));
    if (!cfgInfo.exists() || cfgInfo.size() == 0) {
        saveMonitorsConfig();
    }

    emit monitorsChanged();
    setError(QString());
}

MonitorInfo *Monitors::findMonitor(const QString &name)
{
    for (QObject *obj : std::as_const(m_monitors)) {
        auto *m = qobject_cast<MonitorInfo*>(obj);
        if (m && m->name() == name)
            return m;
    }
    return nullptr;
}

bool Monitors::saveMonitorsConfig() const
{
    QString configDir = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation);
    if (configDir.isEmpty()) {
        configDir = QDir::homePath() + QStringLiteral("/.config");
    }

    QDir dir(configDir);
    if (!dir.exists(QStringLiteral("fht"))) {
        dir.mkpath(QStringLiteral("fht"));
    }

    const QString filePath = configDir + QStringLiteral("/fht/monitors.toml");
    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        return false;
    }

    static const QRegularExpression kBareKeyRe(QStringLiteral("^[A-Za-z0-9_-]+$"));

    QTextStream out(&file);
    out << "# This file is generated by sleex monitor settings\n";

    for (QObject *obj : m_monitors) {
        auto *mi = qobject_cast<MonitorInfo*>(obj);
        if (!mi)
            continue;

        const QString key = kBareKeyRe.match(mi->name()).hasMatch()
                                ? mi->name()
                                : QStringLiteral("\"%1\"").arg(mi->name());

        out << QStringLiteral("\n[outputs.%1]\n").arg(key);
        if (!mi->enabled()) {
            out << QStringLiteral("disable = true\n");
            continue;
        }

        out << QStringLiteral("mode = \"%1x%2@%3\"\n")
                   .arg(mi->width())
                   .arg(mi->height())
                   .arg(mi->refreshRate(), 0, 'f', 2);
        out << QStringLiteral("position = { x = %1, y = %2 }\n")
                   .arg(mi->x())
                   .arg(mi->y());
        const double s = mi->scale();
        if (std::abs(s - std::round(s)) < 0.001) {
            out << QStringLiteral("scale = %1\n").arg(static_cast<int>(std::round(s)));
        } else {
            out << QStringLiteral("scale = %1\n").arg(s, 0, 'f', 2);
        }
    }

    return true;
}

void Monitors::setBusy(bool b)
{
    if (m_busy != b) {
        m_busy = b;
        emit busyChanged();
    }
}

void Monitors::setError(const QString &e)
{
    if (m_lastError != e) {
        m_lastError = e;
        emit lastErrorChanged();
    }
}

} // namespace sleex::services
