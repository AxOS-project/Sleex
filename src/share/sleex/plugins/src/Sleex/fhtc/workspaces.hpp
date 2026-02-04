#pragma once

#include <QObject>
#include <QVariant>
#include <QVariantMap>
#include <QtQml>
#include "ipc.hpp"

class Workspaces : public QObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(Fhtc)
    QML_SINGLETON

    Q_PROPERTY(QVariantMap windows READ windows NOTIFY windowsChanged)
    Q_PROPERTY(QVariantMap workspaces READ workspaces NOTIFY workspacesChanged)
    Q_PROPERTY(QVariant space READ space NOTIFY spaceChanged)

    Q_PROPERTY(int focusedWindowId READ focusedWindowId NOTIFY focusedWindowIdChanged)
    Q_PROPERTY(QVariant focusedWindow READ focusedWindow NOTIFY focusedWindowChanged)

    Q_PROPERTY(int activeWorkspaceId READ activeWorkspaceId NOTIFY activeWorkspaceIdChanged)
    Q_PROPERTY(QVariant activeWorkspace READ activeWorkspace NOTIFY activeWorkspaceChanged)

public:
    explicit Workspaces(QObject *parent = nullptr);

    QVariantMap windows() const { return m_windows; }
    QVariantMap workspaces() const { return m_workspaces; }
    QVariant space() const { return m_space; }
    int focusedWindowId() const { return m_focusedWindowId; }
    QVariant focusedWindow() const { return m_focusedWindow; }
    int activeWorkspaceId() const { return m_activeWorkspaceId; }
    QVariant activeWorkspace() const { return m_activeWorkspace; }

    Q_INVOKABLE void dispatch(const QString &command, const QVariant &args);

signals:
    void windowsChanged();
    void workspacesChanged();
    void spaceChanged();
    void focusedWindowIdChanged();
    void focusedWindowChanged();
    void activeWorkspaceIdChanged();
    void activeWorkspaceChanged();

private slots:
    void handleEvent(const QVariant &eventVar);

private:
    Ipc *m_ipc;

    QVariantMap m_windows;
    QVariantMap m_workspaces;
    QVariant m_space;
    int m_focusedWindowId = -1;
    QVariant m_focusedWindow;
    int m_activeWorkspaceId = -1;
    QVariant m_activeWorkspace;
};