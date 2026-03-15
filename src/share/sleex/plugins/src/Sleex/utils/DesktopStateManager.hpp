#pragma once

#include <QObject>
#include <QVariantMap>
#include <QQmlEngine>

class DesktopStateManager : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit DesktopStateManager(QObject *parent = nullptr);

    Q_INVOKABLE void saveLayout(const QVariantMap& layout);
    Q_INVOKABLE QVariantMap getLayout();

private:
    QString getConfigFilePath() const;
};