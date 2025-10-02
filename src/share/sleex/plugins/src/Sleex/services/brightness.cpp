#include "brightness.hpp"
#include <QProcess>
#include <QRegularExpression>
#include <QDebug>

namespace sleex::services {

Brightness::Brightness(QObject *parent): QObject(parent), m_value(50) {
    // Initialize with current brightness
    updateCurrentBrightness();
}

int Brightness::value() const {
    return m_value;
}

void Brightness::setValue(int val) {
    // Clamp value between 1 and 100
    val = qBound(1, val, 100);
    
    if (m_value == val)
        return;
    
    // Try to set brightness using brightnessctl
    QProcess process;
    process.start("brightnessctl", QStringList() << "s" << QString("%1%").arg(val) << "--quiet");
    
    if (process.waitForFinished(1000)) {
        if (process.exitCode() == 0) {
            m_value = val;
            emit valueChanged();
            return;
        }
    }
    
    qWarning() << "Failed to set brightness. Install 'brightnessctl'";
}

void Brightness::updateCurrentBrightness() {
    QProcess process;
    process.start("sh", QStringList() << "-c" << "echo \"$(brightnessctl g) $(brightnessctl m)\"");
    
    if (process.waitForFinished(1000) && process.exitCode() == 0) {
        QString output = QString::fromUtf8(process.readAllStandardOutput()).trimmed();
        QStringList parts = output.split(' ');
        
        if (parts.size() >= 2) {
            bool okCurrent, okMax;
            int current = parts[0].toInt(&okCurrent);
            int max = parts[1].toInt(&okMax);
            
            if (okCurrent && okMax && max > 0) {
                m_value = qRound((current * 100.0) / max);
                emit valueChanged();
                return;
            }
        }
    }
    
    qWarning() << "Could not read current brightness. Install 'brightnessctl'";
}

} // namespace sleex::services