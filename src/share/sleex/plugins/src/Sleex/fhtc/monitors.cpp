#include "monitors.hpp"
#include <string>

Monitors::Monitors(QObject *parent) : QObject(parent)
{
    m_ipc = new Ipc(this);

    connect(m_ipc, &Ipc::newEvent, this, &Monitors::handleEvent);

    m_ipc->subscribe();
}

void Monitors::handleEvent(const QVariant &eventVar)
{
    QVariantMap event = eventVar.toMap();
    QString type = event.value("event").toString();
    QVariant data = event.value("data");

    if (type == "space") {
        QVariant data = event.value("data");
        QVariantMap monitorsMap = data.toMap().value("monitors").toMap();

        m_monitors = monitorsMap;
        
        bool activeFound = false;
        QMapIterator<QString, QVariant> i(m_monitors);
        while (i.hasNext()) {
            i.next();
            QVariantMap monitor = i.value().toMap();
            if (monitor.value("active").toBool()) {
                m_activeMonitor = monitor;
                m_activeMonitorName = monitor.value("output").toString();
                activeFound = true;
                break;
            }
        }

        if (!activeFound) {
             m_activeMonitor = QVariant();
        }

        emit monitorsChanged();
        emit activeMonitorChanged();
        emit activeMonitorNameChanged();
    }
}