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
        // sysinfo returns values in kibibytes multiples of mem_unit
        unsigned long long mem_unit = info.mem_unit ? info.mem_unit : 1;
        unsigned long long totalBytes = info.totalram * mem_unit;
        unsigned long long freeBytes = info.freeram * mem_unit;
        // Use available-like metric where possible: estimate with freeram + buff/cache
        unsigned long long available = freeBytes;
        if (info.bufferram)
            available += info.bufferram * mem_unit;
        // convert to kilobytes to match /proc/meminfo semantics if desired, but here use bytes
        m_memoryTotal = static_cast<double>(totalBytes) / 1024.0; // KB
        m_memoryFree  = static_cast<double>(available) / 1024.0;  // KB
        m_swapTotal = static_cast<double>(info.totalswap * mem_unit) / 1024.0;
        m_swapFree  = static_cast<double>(info.freeswap * mem_unit) / 1024.0;

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

void ResourceMonitor::updateTemperature() {
    // Look for first sensible thermal zone or coretemp file in /sys/class/thermal
    // We attempt a few well-known places.
    const QStringList candidates = {
        "/sys/class/thermal/thermal_zone0/temp"
    };

    int tempC = -1;
    // try thermal_zone* enumerations (up to 16)
    for (int i = 0; i < 16; ++i) {
        QString path = QString("/sys/class/thermal/thermal_zone%1/temp").arg(i);
        QFile f(path);
        if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QByteArray content = f.readAll().trimmed();
            bool ok = false;
            long long val = content.toLongLong(&ok);
            if (ok) {
                // kernel usually reports millidegree Celsius
                if (val > 1000) tempC = static_cast<int>(val / 1000);
                else tempC = static_cast<int>(val);
                break;
            }
        }
    }

    // fallback: try coretemp entries under /sys/devices/platform/coretemp.*
    if (tempC < 0) {
        QDir d("/sys/class/hwmon");
        const QFileInfoList list = d.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot);
        for (const QFileInfo &fi : list) {
            QString labelFile = fi.filePath() + "/name";
            QFile label(labelFile);
            QString labelName;
            if (label.open(QIODevice::ReadOnly | QIODevice::Text))
                labelName = QString::fromUtf8(label.readAll()).trimmed();

            // try temp1_input
            QString tryPath = fi.filePath() + "/temp1_input";
            QFile tf(tryPath);
            if (tf.open(QIODevice::ReadOnly | QIODevice::Text)) {
                QByteArray content = tf.readAll().trimmed();
                bool ok = false;
                long long v = content.toLongLong(&ok);
                if (ok) {
                    tempC = (v > 1000) ? static_cast<int>(v / 1000) : static_cast<int>(v);
                    break;
                }
            }
        }
    }

    if (tempC >= 0) {
        m_cpuTemperature = tempC;
        emit cpuChanged();
    }
}

} // namespace sleex::services
