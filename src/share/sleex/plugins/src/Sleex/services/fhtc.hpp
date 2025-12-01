#pragma once

#include <QObject>
#include <QMap>
#include <QVariant>
#include <QTcpSocket>
#include <QJsonDocument>
#include <QJsonObject>
#include <QtQml/qqml.h>

class FhtCompositor : public QObject {
    Q_OBJECT
    QML_SINGLETON
    QML_ELEMENT

    Q_PROPERTY(QVariantMap windows READ windows NOTIFY windowsChanged)
    Q_PROPERTY(QVariantMap workspaces READ workspaces NOTIFY workspacesChanged)
    Q_PROPERTY(QVariant space READ space NOTIFY spaceChanged)
    Q_PROPERTY(int focusedWindowId READ focusedWindowId NOTIFY focusedWindowIdChanged)
    Q_PROPERTY(QVariant focusedWindow READ focusedWindow NOTIFY focusedWindowChanged)
    Q_PROPERTY(int activeWorkspaceId READ activeWorkspaceId NOTIFY activeWorkspaceIdChanged)
    Q_PROPERTY(QVariant activeWorkspace READ activeWorkspace NOTIFY activeWorkspaceChanged)

public:
    explicit FhtCompositor(QObject *parent = nullptr);

    QVariantMap windows() const { return m_windows; }
    QVariantMap workspaces() const { return m_workspaces; }
    QVariant space() const { return m_space; }
    int focusedWindowId() const { return m_focusedWindowId; }
    QVariant focusedWindow() const { return m_focusedWindow; }
    int activeWorkspaceId() const { return m_activeWorkspaceId; }
    QVariant activeWorkspace() const { return m_activeWorkspace; }

signals:
    void windowsChanged();
    void workspacesChanged();
    void spaceChanged();
    void focusedWindowIdChanged();
    void focusedWindowChanged();
    void activeWorkspaceIdChanged();
    void activeWorkspaceChanged();

private slots:
    void onReadyRead();
    void handleEvent(const QJsonObject &event);

private:
    QTcpSocket *m_socket = nullptr;
    QVariantMap m_windows;
    QVariantMap m_workspaces;
    QVariant m_space;
    int m_focusedWindowId = -1;
    QVariant m_focusedWindow;
    int m_activeWorkspaceId = -1;
    QVariant m_activeWorkspace;
};
