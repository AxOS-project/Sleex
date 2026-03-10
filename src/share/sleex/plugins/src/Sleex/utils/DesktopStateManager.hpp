#pragma once

#include <QObject>
#include <QStringList>
#include <QQmlEngine>

class DesktopStateManager : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit DesktopStateManager(QObject *parent = nullptr);

    Q_INVOKABLE void saveOrder(const QStringList& order);
    Q_INVOKABLE QStringList getOrder();

private:
    QString getConfigFilePath() const;
};