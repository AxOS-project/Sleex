#include "ContributionCalendar.hpp"
#include <QPainter>
#include <QHoverEvent>

ContributionCalendar::ContributionCalendar(QQuickItem *parent)
    : QQuickPaintedItem(parent)
{
    // Sensible defaults, QML will override these
    m_colors[0] = QColor(45,  45,  45);
    m_colors[1] = QColor(14,  68,  41);
    m_colors[2] = QColor(0,  109,  50);
    m_colors[3] = QColor(38, 166,  65);
    m_colors[4] = QColor(57, 211,  83);

    setAcceptHoverEvents(true);

    recalcImplicitSize();
}

void ContributionCalendar::setContributions(const QVariantList &v)
{
    if (m_contributions == v) return;
    m_contributions = v;
    emit contributionsChanged();
    update();
}

void ContributionCalendar::setColor(int level, const QColor &c)
{
    if (m_colors[level] == c) return;
    m_colors[level] = c;
    emit colorsChanged();
    update();
}

void ContributionCalendar::setCellSize(int s)
{
    if (m_cellSize == s) return;
    m_cellSize = s;
    recalcImplicitSize();
    emit layoutChanged();
    update();
}

void ContributionCalendar::setGap(int g)
{
    if (m_gap == g) return;
    m_gap = g;
    recalcImplicitSize();
    emit layoutChanged();
    update();
}

void ContributionCalendar::setRadius(int r)
{
    if (m_radius == r) return;
    m_radius = r;
    emit layoutChanged();
    update();
}


void ContributionCalendar::recalcImplicitSize()
{
    // Total width / height = N cells + (N-1) gaps
    setImplicitWidth(COLS  * m_cellSize + (COLS  - 1) * m_gap);
    setImplicitHeight(ROWS * m_cellSize + (ROWS - 1) * m_gap);
}


void ContributionCalendar::paint(QPainter *painter)
{
    painter->setRenderHint(QPainter::Antialiasing, m_radius > 0);
    painter->setPen(Qt::NoPen);

    const int stride = m_cellSize + m_gap;

    for (int col = 0; col < COLS; ++col) {
        for (int row = 0; row < ROWS; ++row) {
            const int idx = col * ROWS + row;

            int level = 0;
            if (idx < m_contributions.size()) {
                const QVariantMap entry = m_contributions.at(idx).toMap();
                level = qBound(0, entry.value(QStringLiteral("level"), 0).toInt(), 4);
            }

            QColor color = m_colors[level];

            if (idx == m_hoveredIndex)
                color = color.lighter(160);

            painter->setBrush(color);

            const QRectF rect(
                col * stride,
                row * stride,
                m_cellSize,
                m_cellSize
            );

            if (m_radius > 0)
                painter->drawRoundedRect(rect, m_radius, m_radius);
            else
                painter->fillRect(rect, color);
        }
    }
}


int ContributionCalendar::cellIndexAt(const QPointF &pos) const
{
    const int stride = m_cellSize + m_gap;

    const int col = static_cast<int>(pos.x()) / stride;
    const int row = static_cast<int>(pos.y()) / stride;

    if (col < 0 || col >= COLS || row < 0 || row >= ROWS) return -1;

    // Reject hits that land inside the gap between cells
    const int localX = static_cast<int>(pos.x()) % stride;
    const int localY = static_cast<int>(pos.y()) % stride;
    if (localX >= m_cellSize || localY >= m_cellSize) return -1;

    return col * ROWS + row;
}

void ContributionCalendar::updateHovered(int index)
{
    if (m_hoveredIndex == index) return;

    m_hoveredIndex = index;

    if (index >= 0 && index < m_contributions.size()) {
        const QVariantMap entry = m_contributions.at(index).toMap();
        const int     count = entry.value(QStringLiteral("count"), 0).toInt();
        const QString date  = entry.value(QStringLiteral("date")).toString();
        m_hoveredTooltip = QStringLiteral("%1 commits on %2")
                               .arg(count)
                               .arg(date.isEmpty() ? QStringLiteral("unknown") : date);
    } else {
        m_hoveredTooltip.clear();
    }

    emit hoveredChanged();
    update();
}

void ContributionCalendar::hoverMoveEvent(QHoverEvent *event)
{
    updateHovered(cellIndexAt(event->position()));
    QQuickPaintedItem::hoverMoveEvent(event);
}

void ContributionCalendar::hoverLeaveEvent(QHoverEvent *event)
{
    updateHovered(-1);
    QQuickPaintedItem::hoverLeaveEvent(event);
}