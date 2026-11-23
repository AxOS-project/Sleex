#pragma once

#include <QByteArray>
#include <QFile>
#include <QHash>
#include <QList>
#include <QLocalSocket>
#include <QMap>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>
#include <functional>

namespace sleex::services {

/**
 * @brief QML object representing the live properties and available modes of a single display output.
 */
class MonitorInfo : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Created by Monitors service")

    Q_PROPERTY(QString      name           READ name           NOTIFY changed)
    Q_PROPERTY(int          x              READ x              WRITE setX    NOTIFY changed)
    Q_PROPERTY(int          y              READ y              WRITE setY    NOTIFY changed)
    Q_PROPERTY(int          width          READ width          NOTIFY changed)
    Q_PROPERTY(int          height         READ height         NOTIFY changed)
    Q_PROPERTY(double       scale          READ scale          NOTIFY changed)
    Q_PROPERTY(double       refreshRate    READ refreshRate    NOTIFY changed)
    Q_PROPERTY(bool         enabled        READ enabled        NOTIFY changed)
    Q_PROPERTY(bool         primary        READ primary        NOTIFY changed)
    Q_PROPERTY(QString      make           READ make           NOTIFY changed)
    Q_PROPERTY(QString      model          READ model          NOTIFY changed)
    Q_PROPERTY(QString      description    READ description    NOTIFY changed)
    Q_PROPERTY(QStringList  availableModes READ availableModes NOTIFY changed)
    Q_PROPERTY(QString      mirrorOf       READ mirrorOf       NOTIFY changed)

public:
    /**
     * @brief Constructs an empty `MonitorInfo` object.
     * @param parent Optional parent `QObject`.
     */
    explicit MonitorInfo(QObject *parent = nullptr) : QObject(parent) {}

    /**
     * @brief Returns the output connector name (e.g. `"eDP-1"`).
     */
    QString name() const { return m_name; }

    /**
     * @brief Returns the horizontal logical position in the compositor space.
     */
    int x() const { return m_x; }

    /**
     * @brief Returns the vertical logical position in the compositor space.
     */
    int y() const { return m_y; }

    /**
     * @brief Returns the active mode width in pixels.
     */
    int width() const { return m_width; }

    /**
     * @brief Returns the active mode height in pixels.
     */
    int height() const { return m_height; }

    /**
     * @brief Returns the output integer scale factor (e.g. `1.0`, `2.0`, `3.0`).
     */
    double scale() const { return m_scale; }

    /**
     * @brief Returns the active refresh rate in Hz.
     */
    double refreshRate() const { return m_refreshRate; }

    /**
     * @brief Returns whether the output is currently enabled.
     */
    bool enabled() const { return m_enabled; }

    /**
     * @brief Returns whether the output is the active/primary monitor.
     */
    bool primary() const { return m_primary; }

    /**
     * @brief Returns the display manufacturer string.
     */
    QString make() const { return m_make; }

    /**
     * @brief Returns the display model string.
     */
    QString model() const { return m_model; }

    /**
     * @brief Returns a formatted human-readable description (`"<name> (<make> <model>)"`).
     */
    QString description() const { return m_description; }

    /**
     * @brief Returns unique `"WxH"` resolution strings sorted from highest to lowest pixel count.
     */
    QStringList availableModes() const { return m_availableModes; }

    /**
     * @brief Returns the target output being mirrored, or empty string if not mirroring.
     */
    QString mirrorOf() const { return m_mirrorOf; }

    /**
     * @brief Sets the horizontal logical position.
     * @param x New X coordinate.
     */
    void setX(int x) { if (m_x != x) { m_x = x; emit changed(); } }

    /**
     * @brief Sets the vertical logical position.
     * @param y New Y coordinate.
     */
    void setY(int y) { if (m_y != y) { m_y = y; emit changed(); } }

    /**
     * @brief Sets the active mode width in pixels.
     * @param w Width in pixels.
     */
    void setWidth(int w) { if (m_width != w) { m_width = w; emit changed(); } }

    /**
     * @brief Sets the active mode height in pixels.
     * @param h Height in pixels.
     */
    void setHeight(int h) { if (m_height != h) { m_height = h; emit changed(); } }

    /**
     * @brief Sets the output scale factor.
     * @param scale New scale factor.
     */
    void setScale(double scale) { if (m_scale != scale) { m_scale = scale; emit changed(); } }

    /**
     * @brief Sets the active refresh rate in Hz.
     * @param rr Refresh rate in Hz.
     */
    void setRefreshRate(double rr) { if (m_refreshRate != rr) { m_refreshRate = rr; emit changed(); } }

    /**
     * @brief Sets the mirrored target output name.
     * @param mirror Target output name, or empty string.
     */
    void setMirrorOf(const QString &mirror) { if (m_mirrorOf != mirror) { m_mirrorOf = mirror; emit changed(); } }

    /**
     * @brief Replaces all monitor properties and emits `changed()`.
     */
    void setAll(const QString     &name,
                int                x,
                int                y,
                int                w,
                int                h,
                double             scale,
                double             refreshRate,
                bool               enabled,
                bool               primary,
                const QString     &make,
                const QString     &model,
                const QStringList &availableModes,
                const QString     &mirrorOf)
    {
        m_name           = name;
        m_x              = x;
        m_y              = y;
        m_width          = w;
        m_height         = h;
        m_scale          = scale;
        m_refreshRate    = refreshRate;
        m_enabled        = enabled;
        m_primary        = primary;
        m_make           = make;
        m_model          = model;
        m_availableModes = availableModes;
        m_mirrorOf       = mirrorOf;
        m_description    = make.isEmpty()
                               ? name
                               : QStringLiteral("%1 (%2 %3)").arg(name, make, model);
        emit changed();
    }

signals:
    /**
     * @brief Emitted whenever any property of this monitor changes.
     */
    void changed();

private:
    QString     m_name;
    int         m_x           = 0;
    int         m_y           = 0;
    int         m_width       = 0;
    int         m_height      = 0;
    double      m_scale       = 1.0;
    double      m_refreshRate = 60.0;
    bool        m_enabled     = true;
    bool        m_primary     = false;
    QString     m_make;
    QString     m_model;
    QString     m_description;
    QStringList m_availableModes;
    QString     m_mirrorOf;
};

/**
 * @brief QML singleton service for querying and configuring display outputs on `fht-compositor`.
 *
 * Queries `"outputs"` and `"space"` from `FHTC_SOCKET_PATH`, subscribes to `"space"` events,
 * writes output configuration to `~/.config/fht/monitors.toml`, and dispatches
 * `{"action": "reload-config"}` to apply changes.
 */
class Monitors : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QList<QObject*> monitors      READ monitors      NOTIFY monitorsChanged)
    Q_PROPERTY(bool            busy          READ busy          NOTIFY busyChanged)
    Q_PROPERTY(QString         lastError     READ lastError     NOTIFY lastErrorChanged)
    Q_PROPERTY(int             snapThreshold READ snapThreshold CONSTANT)

public:
    /**
     * @brief Constructs the `Monitors` singleton, subscribes to `fht-compositor` IPC, and refreshes outputs.
     * @param parent Optional parent `QObject`.
     */
    explicit Monitors(QObject *parent = nullptr);

    /**
     * @brief Destroys the `Monitors` service and frees `MonitorInfo` instances.
     */
    ~Monitors() override;

    /**
     * @brief Returns the list of `MonitorInfo*` objects representing connected outputs.
     */
    QList<QObject*> monitors() const { return m_monitors; }

    /**
     * @brief Returns whether a configuration reload request is currently in flight.
     */
    bool busy() const { return m_busy; }

    /**
     * @brief Returns the last error message, or empty string if the last operation succeeded.
     */
    QString lastError() const { return m_lastError; }

    /**
     * @brief Returns the pixel snapping threshold used by the Display Settings arrangement canvas.
     */
    int snapThreshold() const { return 15; }

    /**
     * @brief Queries `"outputs"` and `"space"` from `fht-compositor` and updates `monitors`.
     */
    Q_INVOKABLE void refresh();

    /**
     * @brief Applies a new logical `(x, y)` position to output `name` and reloads compositor config.
     * @param name Output connector name.
     * @param x Horizontal logical position.
     * @param y Vertical logical position.
     */
    Q_INVOKABLE void applyPosition(const QString &name, int x, int y);

    /**
     * @brief Applies logical `(x, y)` positions for multiple outputs at once and reloads compositor config.
     * @param changes List of maps containing `name`, `x`, and `y`.
     */
    Q_INVOKABLE void applyAllPositions(const QVariantList &changes);

    /**
     * @brief Applies an integer scale factor to output `name` and reloads compositor config.
     * @param name Output connector name.
     * @param scale Target scale factor (rounded to an integer >= 1).
     */
    Q_INVOKABLE void applyScale(const QString &name, double scale);

    /**
     * @brief Applies a `"WxH"` resolution mode to output `name` and reloads compositor config.
     * @param name Output connector name.
     * @param mode Resolution string formatted as `"WxH"` (e.g. `"1920x1080"`).
     */
    Q_INVOKABLE void applyMode(const QString &name, const QString &mode);

    /**
     * @brief Stub for output mirroring (unsupported by `fht-compositor`).
     * @param name Output connector name.
     * @param mirrorTarget Target output name.
     */
    Q_INVOKABLE void applyMirror(const QString &name, const QString &mirrorTarget);

    /**
     * @brief Applies batched monitor changes (`x`, `y`, `scale`, `mode`) from Display Settings,
     *        writes `~/.config/fht/monitors.toml`, and reloads `fht-compositor`.
     * @param changes List of change maps per monitor.
     */
    Q_INVOKABLE void applyChanges(const QVariantList &changes);

    /**
     * @brief Reloads monitor positions and modes from the running compositor.
     */
    Q_INVOKABLE void resetPositions();

signals:
    /**
     * @brief Emitted when the list of monitors or their properties are refreshed.
     */
    void monitorsChanged();

    /**
     * @brief Emitted when `busy` changes.
     */
    void busyChanged();

    /**
     * @brief Emitted when `lastError` changes.
     */
    void lastErrorChanged();

    /**
     * @brief Emitted after monitor changes are written and `fht-compositor` reloads its configuration.
     */
    void applySucceeded();

    /**
     * @brief Emitted when applying monitor changes fails.
     * @param error Human-readable error message.
     */
    void applyFailed(const QString &error);

private:
    /**
     * @brief Updates `m_monitors` from `Response::Outputs` and `Space` JSON objects.
     * @param outputsRaw Raw JSON bytes from `"outputs"` request.
     */
    void parseFhtcOutputs(const QByteArray &outputsRaw);

    /**
     * @brief Updates `m_busy` and emits `busyChanged()` if modified.
     * @param b New busy state.
     */
    void setBusy(bool b);

    /**
     * @brief Updates `m_lastError` and emits `lastErrorChanged()` if modified.
     * @param e New error string.
     */
    void setError(const QString &e);

    /**
     * @brief Finds a `MonitorInfo` by output connector name.
     * @param name Output connector name.
     * @return Pointer to `MonitorInfo`, or `nullptr` if not found.
     */
    MonitorInfo *findMonitor(const QString &name);

    /**
     * @brief Writes the current monitor configuration to `~/.config/fht/monitors.toml`.
     * @return `true` if the file was written successfully, `false` otherwise.
     */
    bool saveMonitorsConfig() const;

    /**
     * @brief Updates a single monitor's properties, writes `monitors.toml`, and triggers `reload-config`.
     */
    void applyRule(const QString &name,
                   int            newW,
                   int            newH,
                   double         newRR,
                   int            newX,
                   int            newY,
                   double         newScale);

    /**
     * @brief Sends `"reload-config"` action to `fht-compositor` and emits `applySucceeded`/`applyFailed`.
     */
    void reloadCompositorConfig();

    /**
     * @brief Returns the `fht-compositor` IPC socket path from `FHTC_SOCKET_PATH`.
     */
    static QString socketPath();

    /**
     * @brief Sends a single newline-delimited JSON request line to `FHTC_SOCKET_PATH` and invokes `cb`.
     * @param jsonLine JSON-encoded request line (without trailing newline).
     * @param cb Completion callback receiving `(ok, responseLine)`.
     */
    void sendRequest(const QByteArray &jsonLine,
                     std::function<void(bool ok, const QByteArray &out)> cb);

    /**
     * @brief Connects the persistent subscription socket to receive `"space"` events.
     */
    void connectEventSocket();

    /**
     * @brief Processes a single JSON event line from the subscription socket.
     * @param line Raw UTF-8 JSON line.
     */
    void handleEventLine(const QByteArray &line);

    QList<QObject*> m_monitors;
    bool            m_busy           = false;
    QString         m_lastError;
    QTimer         *m_pollTimer      = nullptr;
    QTimer         *m_reconnectTimer = nullptr;
    QLocalSocket   *m_eventSocket    = nullptr;
    QByteArray      m_eventBuffer;
    QVariantMap     m_spaceMonitors;
    QHash<QString, QHash<QString, double>> m_modeRefreshRates; // outputName -> ("WxH" -> preferred/max refreshRate)
};

} // namespace sleex::services
