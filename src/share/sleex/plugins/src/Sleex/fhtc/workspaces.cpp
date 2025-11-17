#include "workspaces.hpp"
#include <QQmlEngine>
#include <QJSEngine>

Workspaces::Workspaces(QObject *parent)
    : QObject(parent), m_ipc(nullptr), m_activeWorkspaceId(-1)
{
}

void Workspaces::classBegin()
{
    // this "hook" is called by the QML engine after instantiation.
    // It's the best moment to get the Ipc singleton instance.
    QQmlEngine *engine = qmlEngine(this);
    if (!engine) {
        qWarning() << "Workspaces: Unable to find the QML engine.";
        return;
    }

    // Qt 6.2+
    m_ipc = engine->singletonInstance<Ipc*>("Sleex.Fhtc", "Ipc");

    if (!m_ipc) {
        qWarning() << "Workspaces: Cannot find the 'Ipc' singleton.";
        qWarning() << "Make sure 'Ipc' is imported and used in QML (e.g., Ipc.subscribe())";
        return;
    }

    connect(m_ipc, &Ipc::newEvent, this, &Workspaces::handleNewEvent);
    connect(m_ipc, &Ipc::requestResponse, this, &Workspaces::handleRequestResponse);
    connect(m_ipc, &Ipc::subscribed, this, &Workspaces::requestInitialState);
    
    // If Ipc is already 'subscribed', request the state
    requestInitialState();
}


QVariantMap Workspaces::workspaces() const { return m_workspaces; }
QVariantMap Workspaces::space() const { return m_space; }
int Workspaces::activeWorkspaceId() const { return m_activeWorkspaceId; }

QVariant Workspaces::activeWorkspace() const
{
    return m_workspaces.value(QString::number(m_activeWorkspaceId));
}


void Workspaces::requestInitialState()
{
    if (!m_ipc) return;
    
    m_ipc->sendRequest(QVariantMap{{"workspaces", QVariant()}});
    m_ipc->sendRequest(QVariantMap{{"space", QVariant()}});
    m_ipc->sendRequest(QVariantMap{{"focused-workspace", QVariant()}});
}

void Workspaces::handleNewEvent(const QVariant &event)
{
    QVariantMap eventMap = event.toMap();
    QString type = eventMap.value("event").toString();
    if (type.isEmpty()) return;

    QVariant data = eventMap.value("data");
    bool changed = false;

    if (type == "workspaces") {
        m_workspaces = data.toMap();
        emit workspacesChanged();
        changed = true;
    } else if (type == "workspace-changed") {
        QVariantMap wsMap = data.toMap();
        QString id = wsMap.value("id").toString();
        m_workspaces.insert(id, wsMap);
        emit workspacesChanged(); 
        changed = true;
    } else if (type == "workspace-removed") { 
        QString id = data.toMap().value("id").toString();
        if (m_workspaces.remove(id)) {
            emit workspacesChanged();
            changed = true;
        }
    } else if (type == "active-workspace-changed") { 
        int id = data.toMap().value("id").toInt();
        if (m_activeWorkspaceId != id) {
            m_activeWorkspaceId = id;
            emit activeWorkspaceChanged();
        }
    } else if (type == "space") {
        m_space = data.toMap();
        emit spaceChanged();
    }
    
    if (changed) {
        emit activeWorkspaceChanged();
    }
}

void Workspaces::handleRequestResponse(const QVariant &response)
{
    QVariantMap resMap = response.toMap();

    if (resMap.contains("workspaces")) {
        m_workspaces = resMap.value("workspaces").toMap();
        emit workspacesChanged();
        emit activeWorkspaceChanged();
    }

    if (resMap.contains("space")) {
        m_space = resMap.value("space").toMap();
        emit spaceChanged();
    }

    if (resMap.contains("workspace")) {
        QVariant ws = resMap.value("workspace");
        int newId = -1;
        if (ws.isValid() && !ws.isNull()) {
            newId = ws.toMap().value("id").toInt();
        }
        if (m_activeWorkspaceId != newId) {
            m_activeWorkspaceId = newId;
            emit activeWorkspaceChanged();
        }
    }
}