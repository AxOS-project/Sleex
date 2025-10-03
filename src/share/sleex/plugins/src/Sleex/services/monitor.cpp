#include "service.hpp"
#include <QDebug>

namespace sleex::services {

Service::Service(QObject* parent)
    : QObject(parent) {}

void Service::ref(QObject* sender) {
    if (!sender) {
        qWarning() << "Service::ref() called with null sender";
        return;
    }

    if (m_refs.contains(sender)) {
        qWarning() << "Service::ref() called multiple times for same sender";
        return;
    }

    if (m_refs.isEmpty()) {
        start();
    }

    // Connect to destroyed signal to auto-cleanup
    connect(sender, &QObject::destroyed, this, &Service::onRefDestroyed);
    m_refs.insert(sender);
}

void Service::unref(QObject* sender) {
    if (!sender) {
        qWarning() << "Service::unref() called with null sender";
        return;
    }

    if (!m_refs.contains(sender)) {
        qWarning() << "Service::unref() called for non-referenced sender";
        return;
    }

    // Disconnect to avoid double-unreferencing
    disconnect(sender, &QObject::destroyed, this, &Service::onRefDestroyed);
    
    m_refs.remove(sender);
    
    if (m_refs.isEmpty()) {
        stop();
    }
}

void Service::onRefDestroyed() {
    QObject* sender = QObject::sender();
    if (!sender) return;

    // Don't call unref() here to avoid recursion/disconnect issues
    // Just remove from set and check if empty
    if (m_refs.remove(sender) && m_refs.isEmpty()) {
        stop();
    }
}

} // namespace sleex::services