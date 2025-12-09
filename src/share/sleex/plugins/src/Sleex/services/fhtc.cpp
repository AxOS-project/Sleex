#include "fhtc.hpp"
#include <QProcessEnvironment>
#include <QJsonArray>
#include <QDebug>

FhtCompositor::FhtCompositor(QObject *parent)
    : QObject(parent)
{
    QString socketPath = QProcessEnvironment::systemEnvironment().value("FHTC_SOCKET_PATH");
    if (socketPath.isEmpty()) {
        qWarning() << "FhtCompositor: FHTC_SOCKET_PATH not set.";
        return;
    }

    m_socket = new QTcpSocket(this);
    connect(m_socket, &QTcpSocket::readyRead, this, &FhtCompositor::onReadyRead);

    m_socket->connectToHost(socketPath, 0, QIODevice::ReadWrite);
}

void FhtCompositor::onReadyRead()
{
    while (m_socket->canReadLine()) {
        QByteArray line = m_socket->readLine().trimmed();
        QJsonParseError err;
        QJsonDocument doc = QJsonDocument::fromJson(line, &err);
        if (err.error != QJsonParseError::NoError) {
            qWarning() << "FhtCompositor: failed to parse event:" << line << err.errorString();
            continue;
        }

        if (doc.isObject())
            handleEvent(doc.object());
    }
}

void FhtCompositor::handleEvent(const QJsonObject &event)
{
    QString type = event.value("event").toString();
    QJsonValue data = event.value("data");

    enum EventType {
        Windows,
        FocusedWindowChanged,
        WindowClosed,
        WindowChanged,
        Workspaces,
        ActiveWorkspaceChanged,
        WorkspaceChanged,
        WorkspaceRemoved,
        Space,
        Unknown
    };

    static const QHash<QString, EventType> eventMap = {
        {"windows", Windows},
        {"focused-window-changed", FocusedWindowChanged},
        {"window-closed", WindowClosed},
        {"window-changed", WindowChanged},
        {"workspaces", Workspaces},
        {"active-workspace-changed", ActiveWorkspaceChanged},
        {"workspace-changed", WorkspaceChanged},
        {"workspace-removed", WorkspaceRemoved},
        {"space", Space}
    };

    switch (eventMap.value(type, Unknown)) {
    case Windows:
        m_windows = data.toObject().toVariantMap();
        emit windowsChanged();
        break;

    case FocusedWindowChanged: {
        int newId = data.toObject().value("id").toInt(-1);
        if (newId == -1) {
            m_focusedWindowId = -1;
            m_focusedWindow = QVariant();
        } else {
            m_focusedWindowId = newId;
            m_focusedWindow = m_windows.value(QString::number(newId));
        }
        emit focusedWindowIdChanged();
        emit focusedWindowChanged();
        break;
    }

    case WindowClosed: {
        QString id = QString::number(data.toObject().value("id").toInt());
        m_windows.remove(id);
        emit windowsChanged();
        break;
    }

    case WindowChanged: {
        QJsonObject win = data.toObject();
        m_windows[QString::number(win.value("id").toInt())] = win.toVariantMap();
        emit windowsChanged();
        break;
    }

    case Workspaces:
        m_workspaces = data.toObject().toVariantMap();
        emit workspacesChanged();
        break;

    case ActiveWorkspaceChanged: {
        int newId = data.toObject().value("id").toInt(-1);
        if (newId == -1) {
            m_activeWorkspaceId = -1;
            m_activeWorkspace = QVariant();
        } else {
            m_activeWorkspaceId = newId;
            m_activeWorkspace = m_workspaces.value(QString::number(newId));
        }
        emit activeWorkspaceIdChanged();
        emit activeWorkspaceChanged();
        break;
    }

    case WorkspaceChanged: {
        QJsonObject ws = data.toObject();
        m_workspaces[QString::number(ws.value("id").toInt())] = ws.toVariantMap();
        emit workspacesChanged();
        break;
    }

    case WorkspaceRemoved: {
        QString id = QString::number(data.toObject().value("id").toInt());
        m_workspaces.remove(id);
        emit workspacesChanged();
        break;
    }

    case Space:
        m_space = data.toVariant();
        emit spaceChanged();
        break;

    case Unknown:
    default:
        break;
    }
}
