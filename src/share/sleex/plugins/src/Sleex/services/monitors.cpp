#include "monitors.hpp"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSet>
#include <cmath>

namespace sleex::services {

Monitors::Monitors(QObject *parent) : QObject(parent)
{
    // Periodic safety-net poll (event socket handles most updates)
    m_pollTimer = new QTimer(this);
    m_pollTimer->setInterval(10000);
    connect(m_pollTimer, &QTimer::timeout, this, &Monitors::refresh);
    m_pollTimer->start();

    connectEventSocket();
    refresh();
}

Monitors::~Monitors()
{
    qDeleteAll(m_monitors);
}

QString Monitors::socketPath(int n)
{
    const QString sig = qEnvironmentVariable("HYPRLAND_INSTANCE_SIGNATURE");
    const QString run = qEnvironmentVariable("XDG_RUNTIME_DIR",
                                             QStringLiteral("/run/user/1000"));
    const QString suffix = (n == 2) ? QStringLiteral("2") : QString();

    // Hyprland >= 0.40
    const QString newPath =
        QStringLiteral("%1/hypr/%2/.socket%3.sock").arg(run, sig, suffix);
    if (QFile::exists(newPath)) return newPath;

    // Older Hyprland
    const QString oldPath =
        QStringLiteral("/tmp/hypr/%1/.socket%2.sock").arg(sig, suffix);
    return oldPath;
}

void Monitors::sendRequest(const QString &command,
                             bool           jsonResponse,
                             std::function<void(bool, const QByteArray &)> cb)
{
    auto *sock   = new QLocalSocket(this);
    auto  buffer = std::make_shared<QByteArray>();

    connect(sock, &QLocalSocket::connected, this, [sock, command, jsonResponse]() {
        const QByteArray payload = jsonResponse
            ? QStringLiteral("j/%1").arg(command).toUtf8()
            : command.toUtf8();
        sock->write(payload);
        sock->flush();
    });

    connect(sock, &QLocalSocket::readyRead, this, [sock, buffer]() {
        buffer->append(sock->readAll());
    });

    connect(sock, &QLocalSocket::disconnected, this, [sock, buffer, cb]() {
        buffer->append(sock->readAll()); // flush any remaining bytes
        const bool ok = !buffer->startsWith("err");
        cb(ok, *buffer);
        sock->deleteLater();
    });

    connect(sock, &QLocalSocket::errorOccurred, this,
            [sock, cb](QLocalSocket::LocalSocketError) {
                sock->deleteLater();
                cb(false, {});
            });

    sock->connectToServer(socketPath(1));
}


void Monitors::connectEventSocket()
{
    m_eventSocket = new QLocalSocket(this);

    connect(m_eventSocket, &QLocalSocket::readyRead, this, [this]() {
        m_eventBuffer += m_eventSocket->readAll();
        while (true) {
            const int nl = m_eventBuffer.indexOf('\n');
            if (nl < 0) break;
            handleEventLine(m_eventBuffer.left(nl));
            m_eventBuffer = m_eventBuffer.mid(nl + 1);
        }
    });

    connect(m_eventSocket, &QLocalSocket::disconnected, this, [this]() {
        QTimer::singleShot(2000, this, &Monitors::connectEventSocket);
    });

    connect(m_eventSocket, &QLocalSocket::errorOccurred, this,
            [this](QLocalSocket::LocalSocketError) {
                QTimer::singleShot(2000, this, &Monitors::connectEventSocket);
            });

    m_eventSocket->connectToServer(socketPath(2));
}

void Monitors::handleEventLine(const QByteArray &line)
{
    const int sep = line.indexOf(">>");
    if (sep < 0) return;
    const QByteArray event = line.left(sep);

    static const QSet<QByteArray> monitorEvents = {
        "monitoradded",
        "monitorremoved",
        "monitoraddedv2",
        "monitorremovedv2",
        "configreloaded",
    };

    if (monitorEvents.contains(event))
        refresh();
}

void Monitors::refresh()
{
    sendRequest(QStringLiteral("monitors"), true,
                [this](bool ok, const QByteArray &raw) {
                    if (!ok) {
                        setError(QStringLiteral("monitors request failed"));
                        return;
                    }
                    parseHyprctlOutput(raw);
                });
}

void Monitors::applyPosition(const QString &name, int x, int y)
{
    applyRule(name, -1, -1, qQNaN(), qMax(0, x), qMax(0, y), qQNaN());
}

void Monitors::applyAllPositions(const QVariantList &changes)
{
    if (changes.isEmpty()) return;

    struct Change { QString name; int x; int y; };
    QList<Change> pending;
    for (const QVariant &v : changes) {
        const QVariantMap m = v.toMap();
        pending.append({ m[QStringLiteral("name")].toString(),
                         m[QStringLiteral("x")].toInt(),
                         m[QStringLiteral("y")].toInt() });
    }

    auto idx   = std::make_shared<int>(0);
    auto apply = std::make_shared<std::function<void()>>();

    *apply = [this, pending, idx, apply]() {
        if (*idx >= pending.size()) {
            setBusy(false);
            QTimer::singleShot(400, this, &Monitors::refresh);
            emit applySucceeded();
            return;
        }
        const auto &ch = pending[(*idx)++];
        MonitorInfo *mi = findMonitor(ch.name);
        if (!mi) { (*apply)(); return; }

        const QString rule =
            QStringLiteral("%1,%2x%3@%4,%5x%6,%7")
                .arg(ch.name)
                .arg(mi->width()).arg(mi->height())
                .arg(mi->refreshRate(), 0, 'f', 2)
                .arg(qMax(0, ch.x)).arg(qMax(0, ch.y))
                .arg(mi->scale(), 0, 'f', 2);

        sendRequest(QStringLiteral("keyword monitor %1").arg(rule), false,
                    [this, ch, apply](bool ok, const QByteArray &) {
                        if (!ok) {
                            setBusy(false);
                            setError(QStringLiteral("Failed to apply position for ") + ch.name);
                            emit applyFailed(m_lastError);
                            return;
                        }
                        (*apply)();
                    });
    };

    setBusy(true);
    setError(QString());
    (*apply)();
}

void Monitors::applyScale(const QString &name, double scale)
{
    applyRule(name, -1, -1, qQNaN(), -1, -1, qBound(0.25, scale, 4.0));
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
    applyRule(name, w, h, qQNaN(), -1, -1, qQNaN());
}

void Monitors::applyMirror(const QString &name, const QString &mirrorTarget)
{
    MonitorInfo *mi = findMonitor(name);

    if (mirrorTarget.isEmpty()) {
        // Restore exact pre-mirror state
        if (m_snapshots.contains(name)) {
            const MonitorSnapshot &s = m_snapshots[name];
            applyRule(name, s.w, s.h, s.rr, s.x, s.y, s.scale);
            m_snapshots.remove(name);
        } else {
            // No snapshot — fallback to current known values
            applyRule(name, -1, -1, qQNaN(), -1, -1, qQNaN());
        }
        return;
    }

    // Snapshot current state before mirroring
    if (mi) {
        m_snapshots[name] = { mi->width(), mi->height(),
                               mi->x(),    mi->y(),
                               mi->refreshRate(), mi->scale() };
    }

    const QString rule =
        QStringLiteral("%1,preferred,auto,1,mirror,%2").arg(name, mirrorTarget);

    setBusy(true);
    sendRequest(QStringLiteral("keyword monitor %1").arg(rule), false,
                [this, name](bool ok, const QByteArray &) {
                    setBusy(false);
                    if (!ok) {
                        setError(QStringLiteral("Mirror failed for ") + name);
                        m_snapshots.remove(name);
                        emit applyFailed(m_lastError);
                    } else {
                        setError(QString());
                        QTimer::singleShot(350, this, &Monitors::refresh);
                        emit applySucceeded();
                    }
                });
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

    const int    w     = (newW     > 0)           ? newW     : mi->width();
    const int    h     = (newH     > 0)           ? newH     : mi->height();
    const double rr    = !std::isnan(newRR)       ? newRR    : mi->refreshRate();
    const int    x     = (newX     >= 0)          ? newX     : mi->x();
    const int    y     = (newY     >= 0)          ? newY     : mi->y();
    const double scale = !std::isnan(newScale)    ? newScale : mi->scale();

    const QString rule =
        QStringLiteral("%1,%2x%3@%4,%5x%6,%7")
            .arg(name)
            .arg(w).arg(h)
            .arg(rr,    0, 'f', 2)
            .arg(x).arg(y)
            .arg(scale, 0, 'f', 2);

    setBusy(true);
    sendRequest(QStringLiteral("keyword monitor %1").arg(rule), false,
                [this, name](bool ok, const QByteArray &) {
                    setBusy(false);
                    if (!ok) {
                        setError(QStringLiteral("keyword monitor failed for ") + name);
                        emit applyFailed(m_lastError);
                    } else {
                        setError(QString());
                        QTimer::singleShot(350, this, &Monitors::refresh);
                        emit applySucceeded();
                    }
                });
}


void Monitors::parseHyprctlOutput(const QByteArray &raw)
{
    // The control socket prepends "ok\n" before the JSON payload — strip it
    QByteArray json = raw;
    const int bracket = json.indexOf('[');
    if (bracket < 0) {
        setError(QStringLiteral("No JSON array in hyprctl response"));
        return;
    }
    json = json.mid(bracket);

    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(json, &err);
    if (err.error != QJsonParseError::NoError) {
        setError(QStringLiteral("JSON parse error: ") + err.errorString());
        return;
    }
    if (!doc.isArray()) {
        setError(QStringLiteral("Expected JSON array in hyprctl response"));
        return;
    }

    const QJsonArray arr = doc.array();

    QMap<QString, MonitorInfo*> existing;
    for (QObject *obj : std::as_const(m_monitors)) {
        auto *mi = qobject_cast<MonitorInfo*>(obj);
        if (mi) existing.insert(mi->name(), mi);
    }

    QList<QObject*> newList;
    QSet<QString>   seen;

    for (const QJsonValue &val : arr) {
        const QJsonObject o = val.toObject();

        const QString name = o[QStringLiteral("name")].toString();
        if (name.isEmpty()) continue;
        seen.insert(name);

        const int    x           = o[QStringLiteral("x")].toInt();
        const int    y           = o[QStringLiteral("y")].toInt();
        const int    w           = o[QStringLiteral("width")].toInt();
        const int    h           = o[QStringLiteral("height")].toInt();
        const double scale       = o[QStringLiteral("scale")].toDouble(1.0);
        const double refreshRate = o[QStringLiteral("refreshRate")].toDouble(60.0);
        const bool   enabled     = !o[QStringLiteral("disabled")].toBool(false);
        const bool   focused     = o[QStringLiteral("focused")].toBool(false);
        const QString make       = o[QStringLiteral("make")].toString();
        const QString model      = o[QStringLiteral("model")].toString();

        // mirrorOf is "none" when not mirroring
        const QString rawMirror  = o[QStringLiteral("mirrorOf")].toString();
        const QString mirrorOf   = (rawMirror == QStringLiteral("none"))
                                       ? QString()
                                       : rawMirror;

        // availableModes: "1920x1080@60.01Hz" → strip @RR suffix → "1920x1080"
        QStringList modes;
        for (const QJsonValue &mv : o[QStringLiteral("availableModes")].toArray()) {
            const QString res = mv.toString()
                                  .section(QLatin1Char('@'), 0, 0)
                                  .trimmed();
            if (!res.isEmpty() && !modes.contains(res))
                modes.append(res);
        }
        // Sort largest resolution first
        std::sort(modes.begin(), modes.end(), [](const QString &a, const QString &b) {
            auto px = [](const QString &s) {
                const QStringList p = s.split(QLatin1Char('x'));
                return (p.size() == 2) ? p[0].toInt() * p[1].toInt() : 0;
            };
            return px(a) > px(b);
        });

        MonitorInfo *mi = existing.value(name, nullptr);
        if (!mi) mi = new MonitorInfo(this);

        mi->setAll(name, x, y, w, h, scale, refreshRate,
                   enabled, focused, make, model, modes, mirrorOf);
        newList.append(mi);
    }

    // Clean up disconnected monitors
    for (auto it = existing.begin(); it != existing.end(); ++it) {
    if (!seen.contains(it.key())) {
        MonitorInfo *mi = it.value();
        if (m_snapshots.contains(mi->name())) {
            // Still mirroring, keep ghost with snapshot position so tile shows
            const MonitorSnapshot &s = m_snapshots[mi->name()];
            mi->setAll(mi->name(), s.x, s.y, s.w, s.h,
                       s.scale, s.rr,
                       mi->enabled(), mi->primary(),
                       mi->make(), mi->model(),
                       mi->availableModes(),
                       mi->mirrorOf());   // mirrorOf still set from last known state
            newList.append(mi);
        } else {
            mi->deleteLater();
        }
    }
}

    m_monitors = newList;
    emit monitorsChanged();
    setError(QString());
}

MonitorInfo *Monitors::findMonitor(const QString &name)
{
    for (QObject *obj : std::as_const(m_monitors)) {
        auto *m = qobject_cast<MonitorInfo*>(obj);
        if (m && m->name() == name) return m;
    }
    return nullptr;
}

void Monitors::setBusy(bool b)
{
    if (m_busy != b) { m_busy = b; emit busyChanged(); }
}

void Monitors::setError(const QString &e)
{
    if (m_lastError != e) { m_lastError = e; emit lastErrorChanged(); }
}

} // namespace sleex::services