#include "workspaces.hpp"
#include <QDebug>

Workspaces::Workspaces(QObject *parent) : QObject(parent)
{
    m_ipc = new Ipc(this);
    
    connect(m_ipc, &Ipc::newEvent, this, &Workspaces::handleEvent);
    
    m_ipc->subscribe();
}

void Workspaces::handleEvent(const QVariant &eventVar)
{
    QVariantMap event = eventVar.toMap();
    QString type = event.value("event").toString();
    QVariant data = event.value("data");

    if (type == "windows") {
        m_windows = data.toMap();
        emit windowsChanged();
    }
    else if (type == "focused-window-changed") {
        QVariantMap dataMap = data.toMap();
        QVariant idVar = dataMap.value("id");
        
        if (idVar.isNull() || !idVar.isValid()) {
            m_focusedWindowId = -1;
            m_focusedWindow = QVariant();
        } else {
            m_focusedWindowId = idVar.toInt();
            m_focusedWindow = m_windows.value(QString::number(m_focusedWindowId));
        }
        emit focusedWindowIdChanged();
        emit focusedWindowChanged();
    }
    else if (type == "window-closed") {
        int id = data.toMap().value("id").toInt();
        m_windows.remove(QString::number(id));
        emit windowsChanged();
    }
    else if (type == "window-changed") {
        QVariantMap win = data.toMap();
        int id = win.value("id").toInt();
        
        m_windows.insert(QString::number(id), win);
        emit windowsChanged();
        
        if (id == m_focusedWindowId) {
            m_focusedWindow = win;
            emit focusedWindowChanged();
        }
    }
    else if (type == "workspaces") {
        m_workspaces = data.toMap();
        emit workspacesChanged();
        
        if (m_activeWorkspaceId != -1) {
            m_activeWorkspace = m_workspaces.value(QString::number(m_activeWorkspaceId));
            emit activeWorkspaceChanged();
        }
    }
    else if (type == "active-workspace-changed") {
        QVariantMap dataMap = data.toMap();
        QVariant idVar = dataMap.value("id");
        
        if (idVar.isNull() || !idVar.isValid()) {
            m_activeWorkspaceId = -1;
            m_activeWorkspace = QVariant();
        } else {
            m_activeWorkspaceId = idVar.toInt();
            m_activeWorkspace = m_workspaces.value(QString::number(m_activeWorkspaceId));
        }
        emit activeWorkspaceIdChanged();
        emit activeWorkspaceChanged();
    }
    else if (type == "workspace-changed") {
        QVariantMap ws = data.toMap();
        int id = ws.value("id").toInt();
        
        m_workspaces.insert(QString::number(id), ws);
        emit workspacesChanged();
        
        if (id == m_activeWorkspaceId) {
            m_activeWorkspace = ws;
            emit activeWorkspaceChanged();
        }
    }
    else if (type == "workspace-removed") {
        int id = data.toMap().value("id").toInt();
        m_workspaces.remove(QString::number(id));
        emit workspacesChanged();
    }
}