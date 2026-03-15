#pragma once

#include <QObject>
#include <QList>
#include <QString>
#include <QStringList>
#include <QLocalSocket>
#include <QTimer>
#include <QFile>
#include <QMap>
#include <functional>
#include <QtQml/qqmlregistration.h>

namespace sleex::services {

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
    explicit MonitorInfo(QObject *parent = nullptr) : QObject(parent) {}

    QString     name()           const { return m_name; }
    int         x()              const { return m_x; }
    int         y()              const { return m_y; }
    int         width()          const { return m_width; }
    int         height()         const { return m_height; }
    double      scale()          const { return m_scale; }
    double      refreshRate()    const { return m_refreshRate; }
    bool        enabled()        const { return m_enabled; }
    bool        primary()        const { return m_primary; }
    QString     make()           const { return m_make; }
    QString     model()          const { return m_model; }
    QString     description()    const { return m_description; }
    QStringList availableModes() const { return m_availableModes; }
    QString     mirrorOf()       const { return m_mirrorOf; }

    void setX(int x) { if (m_x != x) { m_x = x; emit changed(); } }
    void setY(int y) { if (m_y != y) { m_y = y; emit changed(); } }

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


class Monitors : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QList<QObject*> monitors      READ monitors      NOTIFY monitorsChanged)
    Q_PROPERTY(bool            busy          READ busy          NOTIFY busyChanged)
    Q_PROPERTY(QString         lastError     READ lastError     NOTIFY lastErrorChanged)
    Q_PROPERTY(int             snapThreshold READ snapThreshold CONSTANT)

public:
    explicit Monitors(QObject *parent = nullptr);
    ~Monitors() override;

    QList<QObject*> monitors()      const { return m_monitors; }
    bool            busy()          const { return m_busy; }
    QString         lastError()     const { return m_lastError; }
    int             snapThreshold() const { return 15; }

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void applyPosition(const QString &name, int x, int y);
    Q_INVOKABLE void applyAllPositions(const QVariantList &changes);
    Q_INVOKABLE void applyScale(const QString &name, double scale);
    Q_INVOKABLE void applyMode(const QString &name, const QString &mode);
    Q_INVOKABLE void applyMirror(const QString &name, const QString &mirrorTarget);
    Q_INVOKABLE void resetPositions();

signals:
    void monitorsChanged();
    void busyChanged();
    void lastErrorChanged();
    void applySucceeded();
    void applyFailed(const QString &error);

private:
    struct MonitorSnapshot {
        int    w, h, x, y;
        double rr, scale;
    };
    
    void         parseHyprctlOutput(const QByteArray &raw);
    void         setBusy(bool b);
    void         setError(const QString &e);
    MonitorInfo *findMonitor(const QString &name);

    void applyRule(const QString &name,
                   int            newW,
                   int            newH,
                   double         newRR,
                   int            newX,
                   int            newY,
                   double         newScale);

    static QString socketPath(int n = 1);
    void sendRequest(const QString &command,
                     bool           jsonResponse,
                     std::function<void(bool ok, const QByteArray &out)> cb);
    void connectEventSocket();
    void handleEventLine(const QByteArray &line);

    QList<QObject*> m_monitors;
    bool            m_busy        = false;
    QString         m_lastError;
    QTimer         *m_pollTimer   = nullptr;
    QLocalSocket   *m_eventSocket = nullptr;
    QByteArray      m_eventBuffer;

    QMap<QString, MonitorSnapshot> m_snapshots;

};

} // namespace sleex::services