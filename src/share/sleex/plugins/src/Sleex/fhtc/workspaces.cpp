#include "workspaces.hpp"
#include "ipc.hpp"

namespace sleex::fhtc {

Workspaces::Workspaces(QObject *parent)
    : QObject(parent)
    , m_ipc(Ipc::instance())
{
    connect(m_ipc, &Ipc::eventReceived, this, &Workspaces::handleEvent);
    m_ipc->replayCachedEvents([this](const QString &ev, const QVariant &data) {
        handleEvent(ev, data);
    });
}

QVariantMap Workspaces::focusedWindow() const
{
    if (m_focusedWindowId < 0) {
        return {};
    }
    return m_windows.value(QString::number(m_focusedWindowId)).toMap();
}

QVariantMap Workspaces::activeWorkspace() const
{
    if (m_activeWorkspaceId < 0) {
        return {};
    }
    return m_workspaces.value(QString::number(m_activeWorkspaceId)).toMap();
}

void Workspaces::handleEvent(const QString &ev, const QVariant &data)
{
    if (ev == QLatin1String("windows")) {
        m_windows = data.toMap();
        emit windowsChanged();
        emit focusedWindowChanged();
    } else if (ev == QLatin1String("window-changed")) {
        const QVariantMap win = data.toMap();
        const int winId = win.value(QStringLiteral("id")).toInt();
        const QString idKey = QString::number(winId);
        const bool isNew = !m_windows.contains(idKey);

        m_windows.insert(idKey, win);
        emit windowsChanged();
        if (winId == m_focusedWindowId) {
            emit focusedWindowChanged();
        }
        if (isNew) {
            emit windowOpened(win);
        }
    } else if (ev == QLatin1String("window-closed")) {
        const int winId = data.toMap().value(QStringLiteral("id")).toInt();
        m_windows.remove(QString::number(winId));
        emit windowsChanged();
        if (winId == m_focusedWindowId) {
            m_focusedWindowId = -1;
            emit focusedWindowChanged();
        }
    } else if (ev == QLatin1String("focused-window-changed")) {
        const QVariant idVar = data.toMap().value(QStringLiteral("id"));
        const int newId = idVar.isNull() || !idVar.isValid() ? -1 : idVar.toInt();
        if (newId != m_focusedWindowId) {
            m_focusedWindowId = newId;
            emit focusedWindowChanged();
        }
    } else if (ev == QLatin1String("workspaces")) {
        m_workspaces = data.toMap();
        emit workspacesChanged();
        emit activeWorkspaceChanged();
    } else if (ev == QLatin1String("workspace-changed")) {
        const QVariantMap ws = data.toMap();
        const int wsId = ws.value(QStringLiteral("id")).toInt();
        m_workspaces.insert(QString::number(wsId), ws);
        emit workspacesChanged();
        if (wsId == m_activeWorkspaceId) {
            emit activeWorkspaceChanged();
        }
    } else if (ev == QLatin1String("workspace-removed")) {
        const int wsId = data.toMap().value(QStringLiteral("id")).toInt();
        m_workspaces.remove(QString::number(wsId));
        emit workspacesChanged();
    } else if (ev == QLatin1String("active-workspace-changed")) {
        const int newId = data.toMap().value(QStringLiteral("id")).toInt();
        if (newId != m_activeWorkspaceId) {
            m_activeWorkspaceId = newId;
            emit activeWorkspaceChanged();
        }
    }
}

} // namespace sleex::fhtc
