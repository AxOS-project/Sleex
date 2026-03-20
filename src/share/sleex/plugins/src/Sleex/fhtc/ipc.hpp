#ifndef IPC_H
#define IPC_H

#include <QObject>
#include <QtQml/qqml.h>
#include <QLocalSocket>
#include <QVariant>
#include <QQueue>

class Ipc : public QObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(FhtcIpc)
    QML_SINGLETON

public:
    explicit Ipc(QObject *parent = nullptr);
    ~Ipc() override;

signals:
    void error(const QString &message);
    void requestResponse(const QVariant &response);
    void subscribed();
    void newEvent(const QVariant &event);

public slots:
    void subscribe();
    void sendRequest(const QVariant &request);
    void sendAction(const QVariant &action);
    void dispatch(const QString &name, const QVariantMap &args = {});

private slots:
    void onRequestConnected();
    void onRequestReadyRead();
    void onRequestError(QLocalSocket::LocalSocketError socketError);
    void onRequestDisconnected();

    void onEventConnected();
    void onEventReadyRead();
    void onEventError(QLocalSocket::LocalSocketError socketError);
    void onEventDisconnected();

private:
    void writeJson(QLocalSocket* socket, const QVariant &data);
    QVariant parseLine(QByteArray &buffer);

    QString m_socketPath;
    QLocalSocket *m_requestSocket;
    QLocalSocket *m_eventSocket;

    QByteArray m_eventBuffer;
    QByteArray m_requestBuffer;
    QQueue<QVariant> m_pendingRequests;
};

#endif // IPC_H