#pragma once

#include <QObject>
#include <QVariant>
#include <QVariantMap>
#include <QtQml>
#include "ipc.hpp"

class Monitors : public QObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(FhtcMonitors)
    QML_SINGLETON

    Q_PROPERTY(QVariantMap monitors READ monitors NOTIFY monitorsChanged)
    Q_PROPERTY(QVariant activeMonitor READ activeMonitor NOTIFY activeMonitorChanged)
    Q_PROPERTY(QString activeMonitorName READ activeMonitorName NOTIFY activeMonitorNameChanged)

public:
    explicit Monitors(QObject *parent = nullptr);

    QVariantMap monitors() const { return m_monitors; }
    QVariant activeMonitor() const { return m_activeMonitor; }
    QString activeMonitorName() const { return m_activeMonitorName; }

signals:
    void monitorsChanged();
    void activeMonitorChanged();
    void activeMonitorNameChanged();

private slots:
    void handleEvent(const QVariant &eventVar);

private:
    Ipc *m_ipc;

    QVariantMap m_monitors;
    QVariant m_activeMonitor;
    QString m_activeMonitorName;
};