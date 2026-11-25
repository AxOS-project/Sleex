#pragma once

#include <QObject>
#include <QQmlEngine>
#include <QString>
#include <QVariant>
#include <QVariantMap>

namespace sleex::fhtc {

class Ipc;

/**
 * @brief Singleton QML tracker for `fht-compositor` windows and workspaces.
 *
 * Subscribes to window and workspace events from the shared `Ipc::instance()` singleton,
 * maintaining reactive maps of all mapped windows and workspaces, the focused window,
 * the active workspace, and emitting `windowOpened` when a new window is mapped.
 */
class Workspaces : public QObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(FhtcWorkspaces)
    QML_SINGLETON

    Q_PROPERTY(QVariantMap windows READ windows NOTIFY windowsChanged)
    Q_PROPERTY(QVariantMap workspaces READ workspaces NOTIFY workspacesChanged)
    Q_PROPERTY(int focusedWindowId READ focusedWindowId NOTIFY focusedWindowChanged)
    Q_PROPERTY(QVariantMap focusedWindow READ focusedWindow NOTIFY focusedWindowChanged)
    Q_PROPERTY(int activeWorkspaceId READ activeWorkspaceId NOTIFY activeWorkspaceChanged)
    Q_PROPERTY(QVariantMap activeWorkspace READ activeWorkspace NOTIFY activeWorkspaceChanged)

public:
    /**
     * @brief Constructs the `Workspaces` singleton and attaches to `Ipc::instance()`.
     * @param parent Optional parent `QObject`.
     */
    explicit Workspaces(QObject *parent = nullptr);

    /**
     * @brief Returns a map of stringified window IDs to window descriptor maps.
     * @return `QVariantMap` mapping `"<id>"` to `fht_compositor_ipc::Window` properties.
     */
    QVariantMap windows() const { return m_windows; }

    /**
     * @brief Returns a map of stringified workspace IDs to workspace descriptor maps.
     * @return `QVariantMap` mapping `"<id>"` to `fht_compositor_ipc::Workspace` properties.
     */
    QVariantMap workspaces() const { return m_workspaces; }

    /**
     * @brief Returns the numeric ID of the currently focused window, or `-1` if none.
     * @return Focused window ID or `-1`.
     */
    int focusedWindowId() const { return m_focusedWindowId; }

    /**
     * @brief Returns the descriptor map of the currently focused window.
     * @return `QVariantMap` of the focused window, or empty map if no window is focused.
     */
    QVariantMap focusedWindow() const;

    /**
     * @brief Returns the numeric ID of the currently active workspace, or `-1` if unknown.
     * @return Active workspace ID or `-1`.
     */
    int activeWorkspaceId() const { return m_activeWorkspaceId; }

    /**
     * @brief Returns the descriptor map of the currently active workspace.
     * @return `QVariantMap` of the active workspace, or empty map if unknown.
     */
    QVariantMap activeWorkspace() const;

signals:
    /**
     * @brief Emitted when the window collection or any window's properties change.
     */
    void windowsChanged();

    /**
     * @brief Emitted when the workspace collection or any workspace's properties change.
     */
    void workspacesChanged();

    /**
     * @brief Emitted when keyboard focus moves to a different window or focused window data updates.
     */
    void focusedWindowChanged();

    /**
     * @brief Emitted when the active workspace ID or active workspace data updates.
     */
    void activeWorkspaceChanged();

    /**
     * @brief Emitted when a newly created window appears in a `"window-changed"` event.
     * @param window Descriptor map of the newly opened window.
     */
    void windowOpened(const QVariantMap &window);

private slots:
    /**
     * @brief Processes compositor IPC events for windows and workspaces.
     * @param event Kebab-case event identifier.
     * @param data Event payload.
     */
    void handleEvent(const QString &event, const QVariant &data);

private:
    Ipc *m_ipc = nullptr;
    QVariantMap m_windows;
    QVariantMap m_workspaces;
    int m_focusedWindowId = -1;
    int m_activeWorkspaceId = -1;
};

} // namespace sleex::fhtc
