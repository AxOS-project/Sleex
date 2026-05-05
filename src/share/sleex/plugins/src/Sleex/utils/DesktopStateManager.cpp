#include "DesktopStateManager.hpp"
#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QDebug>
#include <QJsonArray>

DesktopStateManager::DesktopStateManager(QObject *parent) : QObject(parent) {}

QString DesktopStateManager::getConfigFilePath() const {
    QString configDir = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation) + "/sleex";
    QDir dir(configDir);
    if (!dir.exists()) {
        dir.mkpath(".");
    }
    return configDir + "/desktop_layout.json"; 
}

void DesktopStateManager::saveLayout(const QVariantMap& layout) {
    QJsonObject jsonObj = QJsonObject::fromVariantMap(layout);
    QJsonDocument doc(jsonObj);
    QFile file(getConfigFilePath());
    
    if (file.open(QIODevice::WriteOnly)) {
        file.write(doc.toJson(QJsonDocument::Indented));
        file.close();
    } else {
        qWarning() << "Sleex: Cannot save desktop layout to" << getConfigFilePath();
    }
}

QVariantMap DesktopStateManager::getLayout() {
    QFile file(getConfigFilePath());
    
    if (!file.open(QIODevice::ReadOnly)) {
        return QVariantMap();
    }

    QByteArray data = file.readAll();
    file.close();

    QJsonDocument doc = QJsonDocument::fromJson(data);
    if (doc.isObject()) {
        return doc.object().toVariantMap();
    }

    return QVariantMap();
}

QString DesktopStateManager::getPostItsFilePath() const {
    QString configDir = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation) + "/sleex";
    QDir dir(configDir);
    if (!dir.exists()) dir.mkpath(".");
    
    return configDir + "/postits.json"; 
}

void DesktopStateManager::savePostIts(const QVariantList& postits) {
    QJsonArray jsonArr = QJsonArray::fromVariantList(postits);
    QJsonDocument doc(jsonArr);
    QFile file(getPostItsFilePath());
    
    if (file.open(QIODevice::WriteOnly)) {
        file.write(doc.toJson(QJsonDocument::Indented));
        file.close();
    } else {
        qWarning() << "Sleex: Cannot save post-its to" << getPostItsFilePath();
    }
}

QVariantList DesktopStateManager::getPostIts() {
    QFile file(getPostItsFilePath());
    
    if (!file.open(QIODevice::ReadOnly)) {
        return QVariantList();
    }

    QByteArray data = file.readAll();
    file.close();

    QJsonDocument doc = QJsonDocument::fromJson(data);
    if (doc.isArray()) {
        return doc.array().toVariantList();
    }

    return QVariantList();
}