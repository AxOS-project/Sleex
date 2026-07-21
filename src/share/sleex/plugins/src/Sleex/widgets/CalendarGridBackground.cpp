#include "CalendarGridBackground.hpp"
#include <QPainter>
#include <QTime>

CalendarGridBackground::CalendarGridBackground(QQuickItem *parent)
    : QQuickPaintedItem(parent)
{
    m_gridLineColor = QColor(128, 128, 128, 153); // ~0.6 opacity, overridden by QML
    m_labelColor    = QColor(128, 128, 128);
    rebuildLabelCache();
    recalcImplicitSize();
}

void CalendarGridBackground::setDayCount(int v)
{
    if (m_dayCount == v) return;
    m_dayCount = v;
    recalcImplicitSize();
    emit layoutChanged();
    update();
}

void CalendarGridBackground::setDayColumnWidth(qreal v)
{
    if (qFuzzyCompare(m_dayColumnWidth, v)) return;
    m_dayColumnWidth = v;
    recalcImplicitSize();
    emit layoutChanged();
    update();
}

void CalendarGridBackground::setTimeColumnWidth(qreal v)
{
    if (qFuzzyCompare(m_timeColumnWidth, v)) return;
    m_timeColumnWidth = v;
    recalcImplicitSize();
    emit layoutChanged();
    update();
}

void CalendarGridBackground::setColumnSpacing(qreal v)
{
    if (qFuzzyCompare(m_spacing, v)) return;
    m_spacing = v;
    recalcImplicitSize();
    emit layoutChanged();
    update();
}

void CalendarGridBackground::setSlotHeight(qreal v)
{
    if (qFuzzyCompare(m_slotHeight, v)) return;
    m_slotHeight = v;
    recalcImplicitSize();
    emit layoutChanged();
    update();
}

void CalendarGridBackground::setTotalSlots(int v)
{
    if (m_totalSlots == v) return;
    m_totalSlots = v;
    rebuildLabelCache();
    recalcImplicitSize();
    emit layoutChanged();
    update();
}

void CalendarGridBackground::setStartHour(int v)
{
    if (m_startHour == v) return;
    m_startHour = v;
    rebuildLabelCache();
    emit layoutChanged();
    update();
}

void CalendarGridBackground::setStartMinute(int v)
{
    if (m_startMinute == v) return;
    m_startMinute = v;
    rebuildLabelCache();
    emit layoutChanged();
    update();
}

void CalendarGridBackground::setSlotDuration(int v)
{
    if (m_slotDuration == v) return;
    m_slotDuration = v;
    rebuildLabelCache();
    emit layoutChanged();
    update();
}

void CalendarGridBackground::setTimeFormat(const QString &v)
{
    if (m_timeFormat == v) return;
    m_timeFormat = v;
    rebuildLabelCache();
    emit layoutChanged();
    update();
}

void CalendarGridBackground::setGridLineColor(const QColor &c)
{
    if (m_gridLineColor == c) return;
    m_gridLineColor = c;
    emit styleChanged();
    update();
}

void CalendarGridBackground::setLabelColor(const QColor &c)
{
    if (m_labelColor == c) return;
    m_labelColor = c;
    emit styleChanged();
    update();
}

void CalendarGridBackground::recalcImplicitSize()
{
    const qreal width = m_timeColumnWidth + m_spacing
        + (m_dayCount > 0 ? m_dayCount * m_dayColumnWidth + (m_dayCount - 1) * m_spacing : 0);
    setImplicitWidth(width);
    setImplicitHeight(m_totalSlots * m_slotHeight);
}

void CalendarGridBackground::rebuildLabelCache()
{
    m_labelCache.clear();
    m_labelCache.reserve(m_totalSlots);
    for (int i = 0; i < m_totalSlots; ++i) {
        const int totalMinutes = m_startMinute + i * m_slotDuration;
        const int hour = (m_startHour + totalMinutes / 60) % 24;
        const int minute = totalMinutes % 60;
        m_labelCache.append(QTime(hour, minute).toString(m_timeFormat));
    }
}

void CalendarGridBackground::paint(QPainter *painter)
{
    painter->setRenderHint(QPainter::Antialiasing, false);

    const qreal gridLeft = m_timeColumnWidth + m_spacing;
    const qreal gridWidth = m_dayCount > 0
        ? m_dayCount * m_dayColumnWidth + (m_dayCount - 1) * m_spacing
        : 0;
    const qreal gridHeight = m_totalSlots * m_slotHeight;

    // Hour gridlines, one draw call each instead of one Rectangle Item each
    QPen linePen(m_gridLineColor, 1);
    painter->setPen(linePen);
    for (int i = 0; i < m_totalSlots; ++i) {
        const qreal y = i * m_slotHeight;
        painter->drawLine(QPointF(gridLeft, y), QPointF(gridLeft + gridWidth, y));
    }

    // Day-column separators
    for (int d = 0; d <= m_dayCount; ++d) {
        const qreal x = gridLeft + d * (m_dayColumnWidth + m_spacing) - (d > 0 ? m_spacing : 0);
        painter->drawLine(QPointF(x, 0), QPointF(x, gridHeight));
    }

    // Hour labels in the time gutter, using the pre-formatted cache.
    painter->setPen(m_labelColor);
    QFont f = painter->font();
    painter->setFont(f);
    for (int i = 0; i < m_labelCache.size(); ++i) {
        const qreal y = i * m_slotHeight - f.pixelSize() / 2.0;
        const QRectF labelRect(0, y, m_timeColumnWidth, f.pixelSize() * 1.5);
        painter->drawText(labelRect, Qt::AlignHCenter | Qt::AlignTop, m_labelCache.at(i));
    }
}