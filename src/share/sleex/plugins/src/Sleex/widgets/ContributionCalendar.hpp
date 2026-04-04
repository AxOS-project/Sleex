#pragma once

#include <QQuickPaintedItem>
#include <QColor>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

class ContributionCalendar : public QQuickPaintedItem {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QVariantList contributions
               READ  contributions
               WRITE setContributions
               NOTIFY contributionsChanged FINAL)

    Q_PROPERTY(QColor level0Color READ level0Color WRITE setLevel0Color NOTIFY colorsChanged FINAL)
    Q_PROPERTY(QColor level1Color READ level1Color WRITE setLevel1Color NOTIFY colorsChanged FINAL)
    Q_PROPERTY(QColor level2Color READ level2Color WRITE setLevel2Color NOTIFY colorsChanged FINAL)
    Q_PROPERTY(QColor level3Color READ level3Color WRITE setLevel3Color NOTIFY colorsChanged FINAL)
    Q_PROPERTY(QColor level4Color READ level4Color WRITE setLevel4Color NOTIFY colorsChanged FINAL)

    Q_PROPERTY(int cellSize READ cellSize WRITE setCellSize NOTIFY layoutChanged FINAL)
    Q_PROPERTY(int gap      READ gap      WRITE setGap      NOTIFY layoutChanged FINAL)
    Q_PROPERTY(int radius   READ radius   WRITE setRadius   NOTIFY layoutChanged FINAL)

    // Hover state exposed to QML for tooltip rendering
    Q_PROPERTY(bool    containsMouse  READ containsMouse  NOTIFY hoveredChanged FINAL)
    Q_PROPERTY(int     hoveredIndex   READ hoveredIndex   NOTIFY hoveredChanged FINAL)
    Q_PROPERTY(QString hoveredTooltip READ hoveredTooltip NOTIFY hoveredChanged FINAL)

public:
    explicit ContributionCalendar(QQuickItem *parent = nullptr);

    void paint(QPainter *painter) override;

    QVariantList contributions() const { return m_contributions; }
    void setContributions(const QVariantList &v);

    QColor level0Color() const { return m_colors[0]; }
    QColor level1Color() const { return m_colors[1]; }
    QColor level2Color() const { return m_colors[2]; }
    QColor level3Color() const { return m_colors[3]; }
    QColor level4Color() const { return m_colors[4]; }
    void setLevel0Color(const QColor &c) { setColor(0, c); }
    void setLevel1Color(const QColor &c) { setColor(1, c); }
    void setLevel2Color(const QColor &c) { setColor(2, c); }
    void setLevel3Color(const QColor &c) { setColor(3, c); }
    void setLevel4Color(const QColor &c) { setColor(4, c); }

    int cellSize() const { return m_cellSize; }
    int gap()      const { return m_gap; }
    int radius()   const { return m_radius; }
    void setCellSize(int s);
    void setGap(int g);
    void setRadius(int r);

    bool    containsMouse()  const { return m_hoveredIndex >= 0; }
    int     hoveredIndex()   const { return m_hoveredIndex; }
    QString hoveredTooltip() const { return m_hoveredTooltip; }

signals:
    void contributionsChanged();
    void colorsChanged();
    void layoutChanged();
    void hoveredChanged();

protected:
    void hoverMoveEvent(QHoverEvent *event) override;
    void hoverLeaveEvent(QHoverEvent *event) override;

private:
    void setColor(int level, const QColor &c);
    int  cellIndexAt(const QPointF &pos) const;
    void updateHovered(int index);
    void recalcImplicitSize();

    QVariantList m_contributions;
    QColor       m_colors[5];
    int          m_cellSize    = 7;
    int          m_gap         = 2;
    int          m_radius      = 2;
    int          m_hoveredIndex = -1;
    QString      m_hoveredTooltip;

    static constexpr int COLS = 40;
    static constexpr int ROWS = 7;
};