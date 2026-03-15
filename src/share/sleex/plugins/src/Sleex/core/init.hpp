#pragma once
#include <QObject>
#include <QQmlEngine>

namespace SleexCore {

class DatabaseManager : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit DatabaseManager(QObject *parent = nullptr);

    Q_INVOKABLE QString getFullConfig();
    Q_INVOKABLE void saveAll(const QString &fullJson);
    Q_INVOKABLE void updateSettingField(const QString &module, const QString &path, const QVariant &value);
};

} // namespace SleexCore