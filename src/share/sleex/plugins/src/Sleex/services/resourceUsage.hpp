#pragma once
#include <QObject>
#include <QTimer>
#include <QFile>
#include <QtQml/qqmlregistration.h>

#include <sys/sysinfo.h>

namespace sleex::services {

class ResourceMonitor : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(double memoryTotal READ memoryTotal NOTIFY memoryChanged)
    Q_PROPERTY(double memoryFree READ memoryFree NOTIFY memoryChanged)
    Q_PROPERTY(double memoryUsedPercentage READ memoryUsedPercentage NOTIFY memoryChanged)

    Q_PROPERTY(double swapTotal READ swapTotal NOTIFY memoryChanged)
    Q_PROPERTY(double swapFree READ swapFree NOTIFY memoryChanged)
    Q_PROPERTY(double swapUsedPercentage READ swapUsedPercentage NOTIFY memoryChanged)

    Q_PROPERTY(double cpuUsage READ cpuUsage NOTIFY cpuChanged)
    Q_PROPERTY(int cpuTemperature READ cpuTemperature NOTIFY cpuChanged)

    Q_PROPERTY(int updateIntervalMs READ updateIntervalMs WRITE setUpdateIntervalMs NOTIFY intervalChanged)

public:
    explicit ResourceMonitor(QObject* parent = nullptr);
    ~ResourceMonitor() override = default;

    // memory
    double memoryTotal() const { return m_memoryTotal; }
    double memoryFree() const { return m_memoryFree; }
    double memoryUsedPercentage() const { return m_memoryTotal > 0 ? (m_memoryTotal - m_memoryFree) / m_memoryTotal : 0; }

    double swapTotal() const { return m_swapTotal; }
    double swapFree() const { return m_swapFree; }
    double swapUsedPercentage() const { return m_swapTotal > 0 ? (m_swapTotal - m_swapFree) / m_swapTotal : 0; }

    // cpu
    double cpuUsage() const { return m_cpuUsage; }
    int cpuTemperature() const { return m_cpuTemperature; }

    int updateIntervalMs() const { return m_timer.interval(); }
    void setUpdateIntervalMs(int ms);

signals:
    void memoryChanged();
    void cpuChanged();
    void intervalChanged();

private slots:
    void onTimeout();

private:
    void updateMemory();
    void updateCpu();
    void updateTemperature();

    // previous cpu totals for delta computation
    unsigned long long m_prevTotal = 0;
    unsigned long long m_prevIdle = 0;

    // cached values
    double m_memoryTotal = 1;
    double m_memoryFree = 1;
    double m_swapTotal = 1;
    double m_swapFree = 1;
    double m_cpuUsage = 0;
    int m_cpuTemperature = 0;

    QTimer m_timer;
};

} // namespace sleex::services
