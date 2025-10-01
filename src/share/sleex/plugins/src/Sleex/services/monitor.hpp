#pragma once
#include "service.hpp"
#include <QObject>
#include <QString>
#include <QList>
#include <qqmlintegration.h>

namespace sleex::services {

struct Monitor {
    Q_GADGET
    Q_PROPERTY(int id MEMBER id)
    Q_PROPERTY(QString name MEMBER name)
    Q_PROPERTY(bool connected MEMBER connected)
    
public:
    int id;
    QString name;
    bool connected;
};

class MonitorService : public Service {
    Q_OBJECT
    QML_ELEMENT
    
    Q_PROPERTY(QList<Monitor> monitors READ monitors NOTIFY monitorsChanged)

public:
    explicit MonitorService(QObject* parent = nullptr);
    
    QList<Monitor> monitors() const;
    Q_INVOKABLE void refresh();

signals:
    void monitorsChanged();
    void error(const QString& message);

private:
    QList<Monitor> m_monitors;
    void scanMonitors();
};

}