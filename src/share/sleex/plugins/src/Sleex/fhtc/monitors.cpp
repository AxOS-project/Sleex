#include "monitors.hpp"
#include "ipc.hpp"

namespace sleex::fhtc {

Monitors::Monitors(QObject *parent)
    : QObject(parent)
    , m_ipc(Ipc::instance())
{
    connect(m_ipc, &Ipc::eventReceived, this, &Monitors::handleEvent);
    m_ipc->replayCachedEvents([this](const QString &ev, const QVariant &data) {
        handleEvent(ev, data);
    });
}

QVariantMap Monitors::activeMonitor() const
{
    if (m_activeMonitorName.isEmpty()) {
        return {};
    }
    return m_monitors.value(m_activeMonitorName).toMap();
}

void Monitors::handleEvent(const QString &ev, const QVariant &data)
{
    if (ev != QLatin1String("space")) {
        return;
    }

    const QVariantMap space = data.toMap();
    m_monitors = space.value(QStringLiteral("monitors")).toMap();

    QString newActive;
    for (auto it = m_monitors.constBegin(); it != m_monitors.constEnd(); ++it) {
        if (it.value().toMap().value(QStringLiteral("active")).toBool()) {
            newActive = it.key();
            break;
        }
    }

    emit monitorsChanged();

    if (newActive != m_activeMonitorName) {
        m_activeMonitorName = newActive;
    }
    emit activeMonitorChanged();
}

} // namespace sleex::fhtc
