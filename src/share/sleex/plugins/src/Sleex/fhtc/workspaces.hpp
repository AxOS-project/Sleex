#ifndef WORKSPACES_H
#define WORKSPACES_H

#include <QObject>
#include <QtQml/qqml.h>
#include <QtQml/QQmlParserStatus>
#include <QVariantMap>
#include "ipc.hpp"

class Workspaces : public QObject, public QQmlParserStatus
{
    Q_OBJECT
    Q_INTERFACES(QQmlParserStatus)

    QML_NAMED_ELEMENT(Workspaces)
    QML_SINGLETON

    Q_PROPERTY(QVariantMap workspaces READ workspaces NOTIFY workspacesChanged)
    Q_PROPERTY(QVariantMap space READ space NOTIFY spaceChanged)
    Q_PROPERTY(int activeWorkspaceId READ activeWorkspaceId NOTIFY activeWorkspaceChanged)
    Q_PROPERTY(QVariant activeWorkspace READ activeWorkspace NOTIFY activeWorkspaceChanged)

public:
    explicit Workspaces(QObject *parent = nullptr);

    void classBegin() override;
    void componentComplete() override;

    QVariantMap workspaces() const;
    QVariantMap space() const;
    int activeWorkspaceId() const;
    QVariant activeWorkspace() const;

signals:
    void workspacesChanged();
    void spaceChanged();
    void activeWorkspaceChanged();

private slots:
    void handleNewEvent(const QVariant &event);
    void handleRequestResponse(const QVariant &response);
    void requestInitialState();

private:
    Ipc *m_ipc;
    QVariantMap m_workspaces;
    QVariantMap m_space;
    int m_activeWorkspaceId;
};

#endif // WORKSPACES_H