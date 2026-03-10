#include "DesktopStateManager.hpp"
#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonArray>
#include <QDebug>

DesktopStateManager::DesktopStateManager(QObject *parent) : QObject(parent) {}

QString DesktopStateManager::getConfigFilePath() const {
    QString configDir = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation) + "/sleex";
    QDir dir(configDir);
    if (!dir.exists()) {
        dir.mkpath(".");
    }
    return configDir + "/desktop_order.json";
}

void DesktopStateManager::saveOrder(const QStringList& order) {
    QJsonArray jsonArray;
    for (const QString& fileName : order) {
        jsonArray.append(fileName);
    }

    QJsonDocument doc(jsonArray);
    QFile file(getConfigFilePath());
    
    if (file.open(QIODevice::WriteOnly)) {
        file.write(doc.toJson());
        file.close();
    } else {
        qWarning() << "Cannot save desktop icons order in " << getConfigFilePath();
    }
}

QStringList DesktopStateManager::getOrder() {
    QStringList order;
    QFile file(getConfigFilePath());
    
    if (!file.open(QIODevice::ReadOnly)) {
        return order;
    }

    QByteArray data = file.readAll();
    file.close();

    QJsonDocument doc = QJsonDocument::fromJson(data);
    if (doc.isArray()) {
        QJsonArray jsonArray = doc.array();
        for (const QJsonValue& val : jsonArray) {
            order.append(val.toString());
        }
    }

    return order;
}