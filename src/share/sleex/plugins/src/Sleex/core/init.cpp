#include "init.hpp"
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QSqlError>
#include <QFile>
#include <QDir>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>
#include <QDebug>

namespace SleexCore {

DatabaseManager::DatabaseManager(QObject *parent) : QObject(parent) {
    QString configDir = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation) + "/sleex";
    QString stateDir = QDir::homePath() + "/.local/state/sleex"; 
    
    QDir().mkpath(configDir);
    QDir().mkpath(stateDir);

    QString jsonPath = QDir::homePath() + "/.sleex/settings.json";
    QString settingsDbPath = configDir + "/sleex_settings.db";
    QString stateDbPath = stateDir + "/sleex_state.db";

    // Settings DB
    QSqlDatabase settingsDb = QSqlDatabase::addDatabase("QSQLITE", "settings_conn");
    settingsDb.setDatabaseName(settingsDbPath);

    if (settingsDb.open()) {
        QSqlQuery query(settingsDb);
        query.exec("CREATE TABLE IF NOT EXISTS sleex_settings (module TEXT PRIMARY KEY, config_json TEXT)");

        // execute only if past version with JSON exists, otherwise we might mess with existing SQLite data
        if (QFile::exists(jsonPath)) {
            qInfo() << "[Sleex Core] Migration...";
            
            QFile file(jsonPath);
            if (file.open(QIODevice::ReadOnly)) {
                QJsonObject root = QJsonDocument::fromJson(file.readAll()).object();
                file.close();

                settingsDb.transaction();
                query.prepare("INSERT OR REPLACE INTO sleex_settings (module, config_json) VALUES (:module, :config)");

                for (auto it = root.begin(); it != root.end(); ++it) {
                    query.bindValue(":module", it.key());
                    query.bindValue(":config", QString(QJsonDocument(it.value().toObject()).toJson(QJsonDocument::Compact)));
                    query.exec();
                }
                settingsDb.commit();

                // Archiving the old JSON just in case, but it won't be used anymore
                QFile::rename(jsonPath, jsonPath + ".bak");
                qInfo() << "[Sleex Core] Migration completed. The JSON file is in the closet.";
            }
        }
    } else {
        qCritical() << "[Sleex Core] settings DB error:" << settingsDb.lastError().text();
    }

    // States DB
    QSqlDatabase stateDb = QSqlDatabase::addDatabase("QSQLITE", "state_conn");
    stateDb.setDatabaseName(stateDbPath);
    
    if (stateDb.open()) {
        QSqlQuery stateQuery(stateDb);
        // Enable Machine Gun mode for faster writes
        stateQuery.exec("PRAGMA journal_mode=WAL;");
        stateQuery.exec("PRAGMA synchronous=NORMAL;");
        
        stateQuery.exec("CREATE TABLE IF NOT EXISTS sleex_states (key TEXT PRIMARY KEY, value TEXT)");
    } else {
        qCritical() << "[Sleex Core] state DB error:" << stateDb.lastError().text();
    }
}

void DatabaseManager::updateSettingField(const QString &module, const QString &path, const QVariant &value) {
    QSqlDatabase db = QSqlDatabase::database("settings_conn");
    QSqlQuery query(db);
    
    QString fullPath = "$." + path; 
    query.prepare("UPDATE sleex_settings SET config_json = json_set(config_json, :path, :val) WHERE module = :module");
    query.bindValue(":path", fullPath);
    query.bindValue(":val", value);
    query.bindValue(":module", module);
    
    if (!query.exec()) {
        qWarning() << "[Sleex Core] Error while setting a setting:" << query.lastError().text();
    }
}

QString DatabaseManager::getFullConfig() {
    QSqlDatabase db = QSqlDatabase::database("settings_conn");
    QSqlQuery query(db);
    query.exec("SELECT module, config_json FROM sleex_settings");
    
    QJsonObject root;
    while (query.next()) {
        QString module = query.value(0).toString();
        QString json = query.value(1).toString();
        root.insert(module, QJsonDocument::fromJson(json.toUtf8()).object());
    }
    
    return QString(QJsonDocument(root).toJson(QJsonDocument::Compact));
}

void DatabaseManager::saveAll(const QString &fullJson) {
    QSqlDatabase db = QSqlDatabase::database("settings_conn");
    QSqlQuery query(db);
    QJsonDocument doc = QJsonDocument::fromJson(fullJson.toUtf8());
    QJsonObject root = doc.object();

    db.transaction();
    query.prepare("INSERT OR REPLACE INTO sleex_settings (module, config_json) VALUES (:module, :config)");
    
    for (auto it = root.begin(); it != root.end(); ++it) {
        query.bindValue(":config", QString(QJsonDocument(it.value().toObject()).toJson(QJsonDocument::Compact)));
        query.bindValue(":module", it.key());
        query.exec();
    }
    db.commit();

    // Touch the trigger file to notify other instances
    QString triggerPath = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation) + "/sleex/.db_trigger";
    QFile trigger(triggerPath);
    if (trigger.open(QIODevice::WriteOnly)) {
        trigger.write("ping");
        trigger.close();
    }
}
} // namespace SleexCore