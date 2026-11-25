#pragma once

#include <QObject>
#include <QQmlEngine>
#include <QString>
#include <QVariant>
#include <QVariantMap>

namespace sleex::fhtc {

class Ipc;

/**
 * @brief Singleton QML tracker for `fht-compositor` monitor (`Space`) state.
 *
 * Subscribes to `"space"` events from the shared `Ipc::instance()` singleton and exposes
 * all connected monitors, the currently focused monitor object, and the focused monitor's
 * output name (`activeMonitorName`).
 */
class Monitors : public QObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(FhtcMonitors)
    QML_SINGLETON

    Q_PROPERTY(QVariantMap monitors READ monitors NOTIFY monitorsChanged)
    Q_PROPERTY(QVariantMap activeMonitor READ activeMonitor NOTIFY activeMonitorChanged)
    Q_PROPERTY(QString activeMonitorName READ activeMonitorName NOTIFY activeMonitorChanged)

public:
    /**
     * @brief Constructs the `Monitors` singleton and connects to `Ipc::instance()`.
     * @param parent Optional parent `QObject`.
     */
    explicit Monitors(QObject *parent = nullptr);

    /**
     * @brief Returns a map of output names to monitor descriptors from the compositor space.
     * @return Map of `<output-name> -> QVariantMap` containing `output`, `workspaces`,
     *         `active-workspace-idx`, and `active`.
     */
    QVariantMap monitors() const { return m_monitors; }

    /**
     * @brief Returns the descriptor map of the currently active/focused monitor.
     * @return `QVariantMap` for the monitor where `active == true`, or empty map if none.
     */
    QVariantMap activeMonitor() const;

    /**
     * @brief Returns the output name of the currently active/focused monitor.
     * @return Output name string (e.g. `"eDP-1"`), or empty string if unknown.
     */
    QString activeMonitorName() const { return m_activeMonitorName; }

signals:
    /**
     * @brief Emitted whenever the compositor's monitor map or workspace assignment changes.
     */
    void monitorsChanged();

    /**
     * @brief Emitted whenever the active monitor or its active workspace index changes.
     */
    void activeMonitorChanged();

private slots:
    /**
     * @brief Processes compositor IPC events relevant to monitor state (`"space"`).
     * @param event Kebab-case event identifier.
     * @param data Event payload.
     */
    void handleEvent(const QString &event, const QVariant &data);

private:
    Ipc *m_ipc = nullptr;
    QVariantMap m_monitors;
    QString m_activeMonitorName;
};

} // namespace sleex::fhtc
