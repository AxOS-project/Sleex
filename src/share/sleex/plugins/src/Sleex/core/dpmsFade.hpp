#pragma once

#include <QObject>
#include <qqmlintegration.h>
#include <memory>
#include <sdbus-c++/sdbus-c++.h>

class SuspendFader : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    
public:
    explicit SuspendFader(QObject* parent = nullptr);
    ~SuspendFader() override;

    SuspendFader(const SuspendFader&) = delete;
    SuspendFader& operator=(const SuspendFader&) = delete;
    SuspendFader(SuspendFader&&) = delete;
    SuspendFader& operator=(SuspendFader&&) = delete;

    Q_INVOKABLE void start();
    Q_INVOKABLE void stop();

private:
    void acquireLock();
    void releaseLock();
    void onPrepareForSleep(bool sleeping);

    std::unique_ptr<sdbus::IConnection> bus_;
    std::unique_ptr<sdbus::IProxy> proxy_;
    sdbus::ServiceName destination;
    sdbus::ObjectPath objectPath;
    int lock_fd_{-1};
};