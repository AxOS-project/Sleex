#include "ipc.hpp"
#include <QProcessEnvironment>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QTimer>

Ipc::Ipc(QObject *parent)
: QObject(parent),
m_requestSocket(new QLocalSocket(this)),
m_eventSocket(new QLocalSocket(this))
{
    m_socketPath = qEnvironmentVariable("FHTC_SOCKET_PATH");
    if (m_socketPath.isEmpty()) {
        emit error("The environment variable FHTC_SOCKET_PATH is not set.");
        qWarning() << "Ipc: FHTC_SOCKET_PATH is not set.";
    }

    // Connections for the request socket
    connect(m_requestSocket, &QLocalSocket::connected, this, &Ipc::onRequestConnected);
    connect(m_requestSocket, &QLocalSocket::readyRead, this, &Ipc::onRequestReadyRead);
    connect(m_requestSocket, &QLocalSocket::errorOccurred, this, &Ipc::onRequestError);
    connect(m_requestSocket, &QLocalSocket::disconnected, this, &Ipc::onRequestDisconnected);

    // Connections for the event socket
    connect(m_eventSocket, &QLocalSocket::connected, this, &Ipc::onEventConnected);
    connect(m_eventSocket, &QLocalSocket::readyRead, this, &Ipc::onEventReadyRead);
    connect(m_eventSocket, &QLocalSocket::errorOccurred, this, &Ipc::onEventError);
    connect(m_eventSocket, &QLocalSocket::disconnected, this, &Ipc::onEventDisconnected);
}

Ipc::~Ipc()
{
    // Sockets are automatically destroyed because 'this' is their parent
}


void Ipc::subscribe()
{
    if (m_socketPath.isEmpty()) return;
    if (m_eventSocket->state() == QLocalSocket::UnconnectedState) {
        qDebug() << "Ipc: Connecting to the event socket...";
        m_eventSocket->connectToServer(m_socketPath);
    }
}

void Ipc::dispatch(const QString &name, const QVariantMap &args)
{
    if (!args.isEmpty() || name.contains("workspace")) { 
        QVariantMap actionBody;
        actionBody.insert(name, args);
        sendAction(actionBody);
    } 
    else {
        sendAction(name);
    }
}

void Ipc::sendRequest(const QVariant &request)
{
    if (m_socketPath.isEmpty()) return;

    // qDebug() << "Ipc: Queuing request:" << request;

    m_pendingRequests.enqueue(request);
    if (m_requestSocket->state() == QLocalSocket::UnconnectedState) {
        qDebug() << "Ipc: Connecting to the request socket...";
        m_requestSocket->connectToServer(m_socketPath);
    } else if (m_requestSocket->state() == QLocalSocket::ConnectedState) {
        // If already connected, send the pending request
        writeJson(m_requestSocket, m_pendingRequests.dequeue());
    }
    // If 'Connecting', the request will be sent in onRequestConnected
}

void Ipc::sendAction(const QVariant &action)
{
    QVariantMap request;
    request.insert("action", action);
    sendRequest(request);
}


void Ipc::onRequestConnected()
{
    qDebug() << "Ipc: Request socket connected.";
    // Send the first pending request (if any)
    if (!m_pendingRequests.isEmpty()) {
        writeJson(m_requestSocket, m_pendingRequests.dequeue());
    }
}

void Ipc::onRequestReadyRead()
{
    m_requestBuffer.append(m_requestSocket->readAll());

    // The fhtc IPC guarantees one response per request on this socket.
    // We do not loop, we just wait for a complete line.
    QVariant response = parseLine(m_requestBuffer);
    if (!response.isNull()) {
        // qDebug() << "Ipc: Received response:" << response;

        emit requestResponse(response);

        // If there are other requests, send them
        if (!m_pendingRequests.isEmpty()) {
            writeJson(m_requestSocket, m_pendingRequests.dequeue());
        }
    }
}

void Ipc::onRequestError(QLocalSocket::LocalSocketError socketError)
{
    Q_UNUSED(socketError);
    QString msg = "Ipc (Request): " + m_requestSocket->errorString();
    qWarning() << msg;
    emit error(msg);
    m_pendingRequests.clear(); // Clear pending requests
}

void Ipc::onRequestDisconnected()
{
    qDebug() << "Ipc: Request socket disconnected.";
    if (!m_requestBuffer.isEmpty()) {
        qWarning() << "Ipc (Request): Disconnected with data in buffer:" << m_requestBuffer;
        m_requestBuffer.clear();
    }
}


void Ipc::onEventConnected()
{
    qDebug() << "Ipc: Event socket connected. Sending 'subscribe' request.";
    emit subscribed();

    // Send the subscribe request
    QVariantMap subRequest;
    subRequest.insert("subscribe", QVariant()); // "subscribe": null
    writeJson(m_eventSocket, subRequest);
}

void Ipc::onEventReadyRead()
{
    m_eventBuffer.append(m_eventSocket->readAll());

    // There may be multiple JSON events in the buffer
    while (true) {
        QVariant event = parseLine(m_eventBuffer);
        if (event.isNull()) {
            break; // Incomplete line, wait for more data
        }
        emit newEvent(event);
    }
}

void Ipc::onEventError(QLocalSocket::LocalSocketError socketError)
{
    Q_UNUSED(socketError);
    QString msg = "Ipc (Event): " + m_eventSocket->errorString();
    qWarning() << msg;
    emit error(msg);
}

void Ipc::onEventDisconnected()
{
    QString msg = "Ipc: Event socket disconnected. Attempting to reconnect in 5s...";
    qWarning() << msg;
    emit error(msg);

    // Attempt automatic reconnection for the event socket
    QTimer::singleShot(5000, this, &Ipc::subscribe);
}

// --- Utility functions ---
void Ipc::writeJson(QLocalSocket *socket, const QVariant &data)
{
    if (socket->state() != QLocalSocket::ConnectedState) {
        qWarning() << "Ipc: Attempt to write to a socket that is not connected.";
        return;
    }

    QJsonDocument doc = QJsonDocument::fromVariant(data);
    if (doc.isNull()) {
        qWarning() << "Ipc: Failed to convert QVariant to JSON.";
        return;
    }

    QByteArray json = doc.toJson(QJsonDocument::Compact);
    json.append('\n'); // fhtc IPC is delimited by newlines

    socket->write(json);
}

QVariant Ipc::parseLine(QByteArray &buffer)
{
    int newlineIdx = buffer.indexOf('\n');
    if (newlineIdx == -1) {
        return QVariant(); // Incomplete line
    }

    // Extract the line and remove it from the buffer
    QByteArray line = buffer.left(newlineIdx);
    buffer = buffer.mid(newlineIdx + 1);

    if (line.isEmpty()) {
        return QVariant(); // Empty line, ignore
    }

    QJsonParseError parseError;
    QJsonDocument doc = QJsonDocument::fromJson(line, &parseError);

    if (parseError.error != QJsonParseError::NoError) {
        QString msg = "Ipc: JSON parse error: " + parseError.errorString() + " | Line: " + QString(line);
        qWarning() << msg;
        emit error(msg);
        return QVariant();
    }

    return doc.toVariant();
}
