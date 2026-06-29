#include "resourceUsage.hpp"
#include <QDebug>
#include <QDir>
#include <QTextStream>
#include <fcntl.h>
#include <unistd.h>

namespace sleex::services {

ResourceMonitor::ResourceMonitor(QObject* parent)
    : QObject(parent)
{
    // default 1000 ms (1s) update
    m_timer.setInterval(1000);
    connect(&m_timer, &QTimer::timeout, this, &ResourceMonitor::onTimeout);
    m_timer.start();

    // initial read
    updateMemory();
    updateCpu();
    // discover sensor path before attempting to read temperature
    discoverTemperaturePath();
    updateTemperature();
}

void ResourceMonitor::setUpdateIntervalMs(int ms) {
    if (ms <= 0) ms = 1000;
    if (m_timer.interval() == ms) return;
    m_timer.setInterval(ms);
    emit intervalChanged();
}

void ResourceMonitor::onTimeout() {
    updateMemory();
    updateCpu();
    updateTemperature();
}

void ResourceMonitor::updateMemory() {
    // use sysinfo(2) — very cheap
    struct sysinfo info;
    if (sysinfo(&info) == 0) {
        unsigned long long mem_unit = info.mem_unit ? info.mem_unit : 1;

        unsigned long long total = info.totalram * mem_unit;
        unsigned long long free  = info.freeram * mem_unit;
        unsigned long long buffers = info.bufferram * mem_unit;
        unsigned long long shared  = info.sharedram * mem_unit;

        unsigned long long available = qMin(free + buffers + shared, total);

        m_memoryTotal = static_cast<double>(total) / 1024.0;
        m_memoryFree = static_cast<double>(available) / 1024.0;

        m_swapTotal = static_cast<double>(info.totalswap * mem_unit) / 1024.0;
        m_swapFree = static_cast<double>(info.freeswap  * mem_unit) / 1024.0;

        emit memoryChanged();
        return;
    }


    // fallback: read /proc/meminfo (rare)
    QFile f("/proc/meminfo");
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return;
    const QByteArray all = f.readAll();
    auto getVal = [&](const char* key) -> unsigned long long {
        int idx = all.indexOf(key);
        if (idx < 0) return 0;
        // read following number
        const char* start = all.constData() + idx + strlen(key);
        unsigned long long v = 0;
        sscanf(start, "%llu", &v);
        return v;
    };
    unsigned long long total = getVal("MemTotal:");
    unsigned long long avail = getVal("MemAvailable:");
    unsigned long long swapTot = getVal("SwapTotal:");
    unsigned long long swapFree = getVal("SwapFree:");

    m_memoryTotal = total > 0 ? static_cast<double>(total) : 1.0;
    m_memoryFree = avail;
    m_swapTotal = swapTot > 0 ? static_cast<double>(swapTot) : 1.0;
    m_swapFree = swapFree;
    emit memoryChanged();
}

void ResourceMonitor::updateCpu() {
    // Read /proc/stat in one shot with ::open/read for speed
    int fd = ::open("/proc/stat", O_RDONLY | O_CLOEXEC);
    if (fd < 0) return;

    char buf[1024];
    ssize_t n = ::read(fd, buf, sizeof(buf) - 1);
    ::close(fd);
    if (n <= 0) return;
    buf[n] = '\0';

    // find line starting with "cpu "
    const char* p = strstr(buf, "cpu ");
    if (!p) return;

    // parse first 7-8 fields: user nice system idle iowait irq softirq steal
    unsigned long long user=0, nice=0, system=0, idle=0, iowait=0, irq=0, softirq=0, steal=0;
    // Use sscanf — fast enough for small string
    int parsed = sscanf(p + 4, "%llu %llu %llu %llu %llu %llu %llu %llu",
                        &user, &nice, &system, &idle, &iowait, &irq, &softirq, &steal);
    unsigned long long idleAll = idle + iowait;
    unsigned long long nonIdle = user + nice + system + irq + softirq + steal;
    unsigned long long total = idleAll + nonIdle;

    if (m_prevTotal != 0) {
        unsigned long long totalDiff = total - m_prevTotal;
        unsigned long long idleDiff = idleAll - m_prevIdle;
        if (totalDiff > 0) {
            m_cpuUsage = static_cast<double>(totalDiff - idleDiff) / static_cast<double>(totalDiff);
        } else {
            m_cpuUsage = 0.0;
        }
        emit cpuChanged();
    }

    m_prevTotal = total;
    m_prevIdle = idleAll;
}

void ResourceMonitor::discoverTemperaturePath() {
    for (int i = 0; i < 16; ++i) {
        QString p = QString("/sys/class/thermal/thermal_zone%1/temp").arg(i);
        QFile f(p);
        if (f.open(QIODevice::ReadOnly)) { m_temperaturePath = p; return; }
    }

    // fallback
    QDir d("/sys/class/hwmon");
    for (const QFileInfo &fi : d.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot)) {
        QString p = fi.filePath() + "/temp1_input";
        if (QFileInfo::exists(p)) { m_temperaturePath = p; return; }
    }
}


void ResourceMonitor::updateTemperature() {
    if (m_temperaturePath.isEmpty()) return;
    QFile f(m_temperaturePath);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return;
    bool ok = false;
    long long val = f.readAll().trimmed().toLongLong(&ok);
    if (!ok) return;
    if (val == 0) return;
    m_cpuTemperature = (val > 1000) ? int(val / 1000) : int(val);
    emit cpuChanged();
}

} // namespace sleex::services
