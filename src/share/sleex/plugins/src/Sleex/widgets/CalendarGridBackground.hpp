#pragma once

#include <QQuickPaintedItem>
#include <QColor>
#include <QtQml/qqmlregistration.h>

class CalendarGridBackground : public QQuickPaintedItem {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(int   dayCount        READ dayCount        WRITE setDayCount        NOTIFY layoutChanged FINAL)
    Q_PROPERTY(qreal dayColumnWidth  READ dayColumnWidth   WRITE setDayColumnWidth  NOTIFY layoutChanged FINAL)
    Q_PROPERTY(qreal timeColumnWidth READ timeColumnWidth  WRITE setTimeColumnWidth NOTIFY layoutChanged FINAL)
    Q_PROPERTY(qreal columnSpacing   READ columnSpacing    WRITE setColumnSpacing   NOTIFY layoutChanged FINAL)
    Q_PROPERTY(qreal slotHeight      READ slotHeight       WRITE setSlotHeight      NOTIFY layoutChanged FINAL)
    Q_PROPERTY(int   totalSlots      READ totalSlots       WRITE setTotalSlots      NOTIFY layoutChanged FINAL)
    Q_PROPERTY(int   startHour       READ startHour        WRITE setStartHour       NOTIFY layoutChanged FINAL)
    Q_PROPERTY(int   startMinute     READ startMinute      WRITE setStartMinute     NOTIFY layoutChanged FINAL)
    Q_PROPERTY(int   slotDuration    READ slotDuration     WRITE setSlotDuration    NOTIFY layoutChanged FINAL)
    // "h" / "hh:mm" style Qt time format string, forwarded from Config.options.time.format
    Q_PROPERTY(QString timeFormat    READ timeFormat       WRITE setTimeFormat      NOTIFY layoutChanged FINAL)

    Q_PROPERTY(QColor gridLineColor  READ gridLineColor    WRITE setGridLineColor   NOTIFY styleChanged FINAL)
    Q_PROPERTY(QColor labelColor     READ labelColor       WRITE setLabelColor      NOTIFY styleChanged FINAL)

public:
    explicit CalendarGridBackground(QQuickItem *parent = nullptr);

    void paint(QPainter *painter) override;

    int   dayCount()        const { return m_dayCount; }
    qreal dayColumnWidth()  const { return m_dayColumnWidth; }
    qreal timeColumnWidth() const { return m_timeColumnWidth; }
    qreal columnSpacing()   const { return m_spacing; }
    qreal slotHeight()      const { return m_slotHeight; }
    int   totalSlots()      const { return m_totalSlots; }
    int   startHour()       const { return m_startHour; }
    int   startMinute()     const { return m_startMinute; }
    int   slotDuration()    const { return m_slotDuration; }
    QString timeFormat()    const { return m_timeFormat; }
    QColor gridLineColor()  const { return m_gridLineColor; }
    QColor labelColor()     const { return m_labelColor; }

    void setDayCount(int v);
    void setDayColumnWidth(qreal v);
    void setTimeColumnWidth(qreal v);
    void setColumnSpacing(qreal v);
    void setSlotHeight(qreal v);
    void setTotalSlots(int v);
    void setStartHour(int v);
    void setStartMinute(int v);
    void setSlotDuration(int v);
    void setTimeFormat(const QString &v);
    void setGridLineColor(const QColor &c);
    void setLabelColor(const QColor &c);

signals:
    void layoutChanged();
    void styleChanged();

private:
    void recalcImplicitSize();

    void rebuildLabelCache();

    int     m_dayCount        = 0;
    qreal   m_dayColumnWidth  = 0;
    qreal   m_timeColumnWidth = 90;
    qreal   m_spacing         = 8;
    qreal   m_slotHeight      = 60;
    int     m_totalSlots      = 24;
    int     m_startHour       = 0;
    int     m_startMinute     = 0;
    int     m_slotDuration    = 60;
    QString m_timeFormat      = QStringLiteral("hh:mm");

    QColor  m_gridLineColor;
    QColor  m_labelColor;

    QVector<QString> m_labelCache;
};