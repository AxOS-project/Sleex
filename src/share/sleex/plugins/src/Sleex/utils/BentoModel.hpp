#pragma once

#include <QAbstractListModel>
#include <QList>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <QQmlEngine>
#include <cstdint>

struct BentoSizePreset {
    int colSpan = 1;
    int rowSpan = 2;
    QString label;
};

struct BentoItem {
    QString id;
    QString title;
    QString icon;

    // Default geometry from registry
    int defaultCol = 0;
    int defaultRow = 0;
    int defaultColSpan = 1;
    int defaultRowSpan = 2;
    bool defaultEnabled = true;

    // Committed geometry
    int col = 0;
    int row = 0;
    int colSpan = 1;
    int rowSpan = 2;
    bool enabled = true;

    // Live preview geometry during drag/reflow
    int previewCol = 0;
    int previewRow = 0;
    int previewColSpan = 1;
    int previewRowSpan = 2;

    int minRowSpan = 2;
    int maxRowSpan = 10;
    QList<BentoSizePreset> presets;
};

class BentoModel : public QAbstractListModel {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(int columns READ columns WRITE setColumns NOTIFY gridSizeChanged)
    Q_PROPERTY(int rows READ rows WRITE setRows NOTIFY gridSizeChanged)
    Q_PROPERTY(bool isDragging READ isDragging NOTIFY dragStateChanged)
    Q_PROPERTY(QString activeDragId READ activeDragId NOTIFY dragStateChanged)
    Q_PROPERTY(int dropCol READ dropCol NOTIFY dropTargetChanged)
    Q_PROPERTY(int dropRow READ dropRow NOTIFY dropTargetChanged)
    Q_PROPERTY(int dropColSpan READ dropColSpan NOTIFY dropTargetChanged)
    Q_PROPERTY(int dropRowSpan READ dropRowSpan NOTIFY dropTargetChanged)
    Q_PROPERTY(bool dropValid READ dropValid NOTIFY dropTargetChanged)
    Q_PROPERTY(bool customizeOpen READ customizeOpen WRITE setCustomizeOpen NOTIFY customizeOpenChanged)
    Q_PROPERTY(QString currentPreset READ currentPreset NOTIFY currentPresetChanged)
    Q_PROPERTY(QVariantList hiddenWidgets READ hiddenWidgets NOTIFY hiddenWidgetsChanged)
    Q_PROPERTY(QVariantList layoutPresets READ layoutPresets CONSTANT)

public:
    enum BentoRoles {
        WidgetIdRole = Qt::UserRole + 1,
        TitleRole,
        IconRole,
        ColRole,
        RowRole,
        PreviewColRole,
        PreviewRowRole,
        ColSpanRole,
        RowSpanRole,
        PreviewColSpanRole,
        PreviewRowSpanRole,
        EnabledRole,
        PresetsRole
    };

    explicit BentoModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    int columns() const noexcept { return m_cols; }
    void setColumns(int c);

    int rows() const noexcept { return m_rows; }
    void setRows(int r);

    bool isDragging() const noexcept { return !m_activeDragId.isEmpty(); }
    QString activeDragId() const noexcept { return m_activeDragId; }

    int dropCol() const noexcept { return m_dropCol; }
    int dropRow() const noexcept { return m_dropRow; }
    int dropColSpan() const noexcept { return m_dropColSpan; }
    int dropRowSpan() const noexcept { return m_dropRowSpan; }
    bool dropValid() const noexcept { return m_dropValid; }

    bool customizeOpen() const noexcept { return m_customizeOpen; }
    void setCustomizeOpen(bool open);

    QString currentPreset() const noexcept { return m_currentPreset; }
    QVariantList hiddenWidgets() const;
    QVariantList layoutPresets() const;

    Q_INVOKABLE void initRegistry(const QVariantList &definitions);
    Q_INVOKABLE void beginDrag(const QString &widgetId);
    Q_INVOKABLE void updateDragTarget(int targetCol, int targetRow);
    Q_INVOKABLE void commitDrag();
    Q_INVOKABLE void cancelDrag();

    Q_INVOKABLE bool resizeWidget(const QString &widgetId, int newColSpan, int newRowSpan);
    Q_INVOKABLE void cycleWidgetSize(const QString &widgetId);
    Q_INVOKABLE void setWidgetEnabled(const QString &widgetId, bool enabled);
    Q_INVOKABLE void applyPreset(const QString &presetId);
    Q_INVOKABLE void resetToDefault();

signals:
    void gridSizeChanged();
    void dragStateChanged();
    void dropTargetChanged();
    void customizeOpenChanged();
    void currentPresetChanged();
    void hiddenWidgetsChanged();

private:
    struct Placement {
        int col = 0;
        int row = 0;
        int colSpan = 1;
        int rowSpan = 2;
        bool enabled = true;
    };

    int m_cols = 3;
    int m_rows = 10;
    QList<BentoItem> m_items;

    QString m_activeDragId;
    int m_activeDragIdx = -1;
    int m_lastTargetCol = -1;
    int m_lastTargetRow = -1;

    int m_dropCol = 0;
    int m_dropRow = 0;
    int m_dropColSpan = 1;
    int m_dropRowSpan = 2;
    bool m_dropValid = false;

    bool m_customizeOpen = false;
    QString m_currentPreset = QStringLiteral("default");

    int findIndexById(const QString &widgetId) const noexcept;
    static constexpr uint64_t rectMask(int col, int row, int colSpan, int rowSpan, int gridCols, int gridRows) noexcept {
        if (col < 0 || row < 0 || colSpan <= 0 || rowSpan <= 0 || col + colSpan > gridCols || row + rowSpan > gridRows) {
            return 0ULL;
        }
        uint64_t mask = 0ULL;
        for (int r = row; r < row + rowSpan; ++r) {
            for (int c = col; c < col + colSpan; ++c) {
                const int bit = r * gridCols + c;
                if (bit >= 0 && bit < 64) {
                    mask |= (1ULL << bit);
                }
            }
        }
        return mask;
    }

    bool isLayoutValid(const QList<Placement> &state) const noexcept;
    bool solveMove(int dragIdx, int rawTargetCol, int rawTargetRow, QList<Placement> &outState) const;
    void applyPreviewState(const QList<Placement> &newState, int dropC, int dropR, int dropCS, int dropRS, bool valid);

    QString getLayoutFilePath() const;
    void saveLayout() const;
    bool loadLayout();
};
