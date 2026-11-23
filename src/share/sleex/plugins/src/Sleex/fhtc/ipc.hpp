#pragma once

#include <QByteArray>
#include <QHash>
#include <QJSEngine>
#include <QJSValue>
#include <QLocalSocket>
#include <QObject>
#include <QQmlEngine>
#include <QQueue>
#include <QVariant>
#include <QVariantMap>
#include <functional>

namespace sleex::fhtc {

/**
 * @brief Singleton QML and C++ client for the `fht-compositor` Unix domain socket IPC.
 *
 * `Ipc` manages two logical channels over `FHTC_SOCKET_PATH`:
 * 1. A persistent subscription socket that streams compositor events (`windows`,
 *    `window-changed`, `window-closed`, `focused-window-changed`, `workspaces`,
 *    `workspace-changed`, `workspace-removed`, `active-workspace-changed`, `space`,
 *    `layer-shells`) and maintains a live snapshot for late subscribers.
 * 2. A sequential request/response queue over a dedicated request socket for queries
 *    and compositor actions (`dispatch`).
 */
class Ipc : public QObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(FhtcIpc)
    QML_SINGLETON

    Q_PROPERTY(bool connected READ isConnected NOTIFY connectedChanged)

public:
    /**
     * @brief Returns the process-wide shared `Ipc` singleton instance.
     * @return Pointer to the shared `Ipc` instance.
     */
    static Ipc *instance();

    /**
     * @brief QML singleton factory returning the shared `Ipc` instance with C++ ownership.
     * @param qmlEngine Active QML engine.
     * @param jsEngine Active JS engine.
     * @return Pointer to the shared `Ipc` instance.
     */
    static Ipc *create(QQmlEngine *qmlEngine, QJSEngine *jsEngine);

    /**
     * @brief Constructs an `Ipc` client and initiates connections to `FHTC_SOCKET_PATH`.
     * @param parent Optional parent `QObject`.
     */
    explicit Ipc(QObject *parent = nullptr);

    /**
     * @brief Destroys the `Ipc` client and closes active sockets.
     */
    ~Ipc() override;

    /**
     * @brief Checks whether the event subscription socket is currently connected.
     * @return `true` if connected to the `fht-compositor` IPC socket, `false` otherwise.
     */
    bool isConnected() const { return m_connected; }

    /**
     * @brief Sends an asynchronous IPC request with a QML JavaScript callback.
     * @param req Request payload (either a string command such as `"outputs"` or a map).
     * @param callback Optional QML JS function invoked with the parsed response.
     */
    Q_INVOKABLE void request(const QVariant &req, const QJSValue &callback = QJSValue());

    /**
     * @brief Dispatches a compositor action by kebab-case name and optional arguments.
     *
     * Automatically distinguishes unit variants (`"quit"`, `"disable-outputs"`,
     * `"reload-config"`, `"focus-next-output"`, `"focus-previous-output"`) from struct
     * variants (`"float-window"`, `"fullscreen-window"`, `"close-window"`, etc.) and
     * injects required default fields such as `"kill": false` on `"close-window"`.
     *
     * @param name Kebab-case action name matching `fht_compositor_ipc::Action`.
     * @param args Map of action parameters (e.g. `{"window-id": 12}`).
     */
    Q_INVOKABLE void dispatch(const QString &name, const QVariantMap &args = {});

    /**
     * @brief Sends an asynchronous IPC request with a C++ callback.
     * @param req Request payload (string command or `QVariantMap`).
     * @param cb Callback function receiving the decoded response `QVariant`.
     */
    void request(const QVariant &req, std::function<void(const QVariant &)> cb);

    /**
     * @brief Replays the latest cached state events (`windows`, `focused-window-changed`,
     *        `workspaces`, `active-workspace-changed`, `space`, `layer-shells`) to a handler.
     * @param handler Callback invoked for each cached event type and its current data payload.
     */
    void replayCachedEvents(const std::function<void(const QString &event, const QVariant &data)> &handler) const;

signals:
    /**
     * @brief Emitted when the subscription socket connection state changes.
     */
    void connectedChanged();

    /**
     * @brief Emitted whenever a subscribed compositor event arrives.
     * @param event Kebab-case event tag (e.g. `"window-changed"`, `"space"`).
     * @param data Parsed event data payload.
     */
    void eventReceived(const QString &event, const QVariant &data);

    /**
     * @brief Emitted when an IPC error occurs on the socket or in a response.
     * @param message Human-readable error description.
     */
    void errorOccurred(const QString &message);

private slots:
    /**
     * @brief Handles incoming newline-delimited JSON events on the subscription socket.
     */
    void onEventReadyRead();

    /**
     * @brief Handles incoming newline-delimited JSON responses on the request socket.
     */
    void onRequestReadyRead();

private:
    /**
     * @brief Represents a queued request and its completion callback.
     */
    struct PendingRequest {
        QVariant payload;
        std::function<void(const QVariant &)> callback;
    };

    /**
     * @brief Connects the subscription socket and sends the `"subscribe"` request.
     */
    void connectEventSocket();

    /**
     * @brief Updates the internal event cache so late listeners can synchronize state.
     * @param event Kebab-case event name.
     * @param data Event data payload.
     */
    void updateCachedState(const QString &event, const QVariant &data);

    /**
     * @brief Dequeues and transmits the next pending request over the request socket.
     */
    void processNextRequest();

    /**
     * @brief Serializes a `QVariant` (map, list, or primitive string) as a single JSON line.
     * @param sock Target `QLocalSocket` to write to.
     * @param v Value to serialize as JSON.
     */
    void writeJson(QLocalSocket *sock, const QVariant &v);

    /**
     * @brief Parses a single newline-delimited JSON payload into a `QVariant`.
     * @param line Raw UTF-8 JSON bytes (object, array, or string primitive).
     * @return Decoded `QVariant`, or an invalid `QVariant` on parse failure.
     */
    QVariant parseLine(const QByteArray &line);

    /**
     * @brief Resolves the filesystem path of the `fht-compositor` IPC socket from `FHTC_SOCKET_PATH`.
     * @return Socket path string, or empty string if `FHTC_SOCKET_PATH` is unset.
     */
    QString socketPath() const;

    QLocalSocket *m_eventSocket = nullptr;
    QLocalSocket *m_reqSocket = nullptr;
    QByteArray m_eventBuf;
    QByteArray m_reqBuf;

    QQueue<PendingRequest> m_queue;
    bool m_reqInFlight = false;
    bool m_connected = false;

    bool m_hasCachedWindows = false;
    bool m_hasCachedWorkspaces = false;
    QVariantMap m_cachedWindows;
    QVariantMap m_cachedWorkspaces;
    QHash<QString, QVariant> m_lastEvents;
};

} // namespace sleex::fhtc
