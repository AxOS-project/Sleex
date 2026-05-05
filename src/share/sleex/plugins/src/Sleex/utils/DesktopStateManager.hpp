#pragma once

#include <QObject>
#include <QVariantMap>
#include <QVariantList>
#include <QQmlEngine>

class DesktopStateManager : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit DesktopStateManager(QObject *parent = nullptr);

    Q_INVOKABLE void saveLayout(const QVariantMap& layout);
    Q_INVOKABLE QVariantMap getLayout();
    
    Q_INVOKABLE void savePostIts(const QVariantList& postits);
    Q_INVOKABLE QVariantList getPostIts();

private:
    QString getConfigFilePath() const;
    QString getPostItsFilePath() const;
};