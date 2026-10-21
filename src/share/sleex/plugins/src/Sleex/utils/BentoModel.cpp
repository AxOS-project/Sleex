#include "BentoModel.hpp"
#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QDebug>
#include <algorithm>
#include <cmath>

BentoModel::BentoModel(QObject *parent) : QAbstractListModel(parent) {}

int BentoModel::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) return 0;
    return m_items.size();
}

QVariant BentoModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() < 0 || index.row() >= m_items.size()) {
        return QVariant();
    }

    const BentoItem &item = m_items[index.row()];
    switch (role) {
        case WidgetIdRole: return item.id;
        case TitleRole: return item.title;
        case IconRole: return item.icon;
        case ColRole: return item.col;
        case RowRole: return item.row;
        case PreviewColRole: return item.previewCol;
        case PreviewRowRole: return item.previewRow;
        case ColSpanRole: return item.colSpan;
        case RowSpanRole: return item.rowSpan;
        case PreviewColSpanRole: return item.previewColSpan;
        case PreviewRowSpanRole: return item.previewRowSpan;
        case EnabledRole: return item.enabled;
        case PresetsRole: {
            QVariantList list;
            for (const auto &p : item.presets) {
                QVariantMap m;
                m[QStringLiteral("colSpan")] = p.colSpan;
                m[QStringLiteral("rowSpan")] = p.rowSpan;
                m[QStringLiteral("label")] = p.label;
                list.append(m);
            }
            return list;
        }
        default: return QVariant();
    }
}

QHash<int, QByteArray> BentoModel::roleNames() const {
    QHash<int, QByteArray> roles;
    roles[WidgetIdRole] = "widgetId";
    roles[TitleRole] = "title";
    roles[IconRole] = "icon";
    roles[ColRole] = "col";
    roles[RowRole] = "row";
    roles[PreviewColRole] = "previewCol";
    roles[PreviewRowRole] = "previewRow";
    roles[ColSpanRole] = "colSpan";
    roles[RowSpanRole] = "rowSpan";
    roles[PreviewColSpanRole] = "previewColSpan";
    roles[PreviewRowSpanRole] = "previewRowSpan";
    roles[EnabledRole] = "widgetEnabled";
    roles[PresetsRole] = "presets";
    return roles;
}

void BentoModel::setColumns(int c) {
    if (c > 0 && m_cols != c) {
        m_cols = c;
        emit gridSizeChanged();
    }
}

void BentoModel::setRows(int r) {
    if (r > 0 && m_rows != r) {
        m_rows = r;
        emit gridSizeChanged();
    }
}

void BentoModel::setCustomizeOpen(bool open) {
    if (m_customizeOpen != open) {
        m_customizeOpen = open;
        emit customizeOpenChanged();
    }
}

QVariantList BentoModel::hiddenWidgets() const {
    QVariantList list;
    for (const auto &item : m_items) {
        if (!item.enabled) {
            QVariantMap m;
            m[QStringLiteral("id")] = item.id;
            m[QStringLiteral("title")] = item.title;
            m[QStringLiteral("icon")] = item.icon;
            list.append(m);
        }
    }
    return list;
}

QVariantList BentoModel::layoutPresets() const {
    return {
        QVariantMap{{QStringLiteral("id"), QStringLiteral("default")}, {QStringLiteral("name"), QStringLiteral("Classic")}},
        QVariantMap{{QStringLiteral("id"), QStringLiteral("focus")}, {QStringLiteral("name"), QStringLiteral("Command Center")}},
        QVariantMap{{QStringLiteral("id"), QStringLiteral("wide")}, {QStringLiteral("name"), QStringLiteral("Wide Media")}}
    };
}

int BentoModel::findIndexById(const QString &widgetId) const noexcept {
    for (int i = 0; i < m_items.size(); ++i) {
        if (m_items[i].id == widgetId) return i;
    }
    return -1;
}

bool BentoModel::isLayoutValid(const QList<Placement> &state) const noexcept {
    uint64_t occupied = 0ULL;
    for (const auto &p : state) {
        if (!p.enabled) continue;
        if (p.col < 0 || p.row < 0 || p.colSpan <= 0 || p.rowSpan <= 0 ||
            p.col + p.colSpan > m_cols || p.row + p.rowSpan > m_rows) {
            return false;
        }
        const uint64_t mask = rectMask(p.col, p.row, p.colSpan, p.rowSpan, m_cols, m_rows);
        if (mask == 0ULL || (occupied & mask) != 0ULL) {
            return false;
        }
        occupied |= mask;
    }
    return true;
}

void BentoModel::initRegistry(const QVariantList &definitions) {
    beginResetModel();
    m_items.clear();

    for (const QVariant &v : definitions) {
        const QVariantMap m = v.toMap();
        BentoItem item;
        item.id = m.value(QStringLiteral("id")).toString();
        item.title = m.value(QStringLiteral("title"), item.id).toString();
        item.icon = m.value(QStringLiteral("icon"), QStringLiteral("widgets")).toString();

        item.defaultCol = m.value(QStringLiteral("col"), 0).toInt();
        item.defaultRow = m.value(QStringLiteral("row"), 0).toInt();
        item.defaultColSpan = m.value(QStringLiteral("colSpan"), 1).toInt();
        item.defaultRowSpan = m.value(QStringLiteral("rowSpan"), 2).toInt();
        item.defaultEnabled = m.value(QStringLiteral("enabled"), true).toBool();

        item.col = item.defaultCol;
        item.row = item.defaultRow;
        item.colSpan = item.defaultColSpan;
        item.rowSpan = item.defaultRowSpan;
        item.enabled = item.defaultEnabled;

        item.previewCol = item.col;
        item.previewRow = item.row;
        item.previewColSpan = item.colSpan;
        item.previewRowSpan = item.rowSpan;

        int minRS = item.defaultRowSpan;
        int maxRS = item.defaultRowSpan;

        const QVariantList rawPresets = m.value(QStringLiteral("presets")).toList();
        for (const QVariant &pv : rawPresets) {
            const QVariantMap pm = pv.toMap();
            BentoSizePreset preset;
            preset.colSpan = pm.value(QStringLiteral("colSpan"), 1).toInt();
            preset.rowSpan = pm.value(QStringLiteral("rowSpan"), 2).toInt();
            preset.label = pm.value(QStringLiteral("label"),
                QStringLiteral("%1×%2").arg(preset.colSpan).arg(preset.rowSpan)).toString();
            item.presets.append(preset);
            if (preset.colSpan == 1) {
                minRS = std::min(minRS, preset.rowSpan);
                maxRS = std::max(maxRS, preset.rowSpan);
            }
        }
        if (item.presets.isEmpty()) {
            item.presets.append({item.defaultColSpan, item.defaultRowSpan,
                QStringLiteral("%1×%2").arg(item.defaultColSpan).arg(item.defaultRowSpan)});
        }
        item.minRowSpan = std::max(2, minRS);
        item.maxRowSpan = std::min(m_rows, std::max(maxRS, item.defaultRowSpan));

        m_items.append(item);
    }

    loadLayout();
    endResetModel();
    emit hiddenWidgetsChanged();
}

void BentoModel::beginDrag(const QString &widgetId) {
    const int idx = findIndexById(widgetId);
    if (idx < 0 || !m_items[idx].enabled) return;

    m_activeDragId = widgetId;
    m_activeDragIdx = idx;
    m_lastTargetCol = m_items[idx].col;
    m_lastTargetRow = m_items[idx].row;

    m_dropCol = m_items[idx].col;
    m_dropRow = m_items[idx].row;
    m_dropColSpan = m_items[idx].colSpan;
    m_dropRowSpan = m_items[idx].rowSpan;
    m_dropValid = true;

    for (auto &item : m_items) {
        item.previewCol = item.col;
        item.previewRow = item.row;
        item.previewColSpan = item.colSpan;
        item.previewRowSpan = item.rowSpan;
    }

    emit dragStateChanged();
    emit dropTargetChanged();
}

bool BentoModel::solveMove(int dragIdx, int rawTargetCol, int rawTargetRow, QList<Placement> &outState) const {
    const int n = m_items.size();
    QList<Placement> base(n);
    for (int i = 0; i < n; ++i) {
        base[i] = {m_items[i].col, m_items[i].row, m_items[i].colSpan, m_items[i].rowSpan, m_items[i].enabled};
    }

    const Placement origD = base[dragIdx];
    const int targetCol = std::clamp(rawTargetCol, 0, std::max(0, m_cols - origD.colSpan));
    const int targetRow = std::clamp(rawTargetRow, 0, std::max(0, m_rows - origD.rowSpan));

    if (targetCol == origD.col && targetRow == origD.row) {
        outState = base;
        return true;
    }

    // Compute bitmask of all other enabled widgets
    uint64_t otherMask = 0ULL;
    for (int i = 0; i < n; ++i) {
        if (i == dragIdx || !base[i].enabled) continue;
        otherMask |= rectMask(base[i].col, base[i].row, base[i].colSpan, base[i].rowSpan, m_cols, m_rows);
    }

    const uint64_t targetMask = rectMask(targetCol, targetRow, origD.colSpan, origD.rowSpan, m_cols, m_rows);

    // -------------------------------------------------------------------------
    // TIER 1: Direct placement into unoccupied cells
    // -------------------------------------------------------------------------
    if ((otherMask & targetMask) == 0ULL) {
        outState = base;
        outState[dragIdx].col = targetCol;
        outState[dragIdx].row = targetRow;
        return true;
    }

    // -------------------------------------------------------------------------
    // TIER 2: Same-Column (or Column-Aligned with Free Space) Vertical Stack Reorder
    // -------------------------------------------------------------------------
    {
        QList<int> colPeers;
        bool allSameSpan = true;
        int totalRowsInCol = origD.rowSpan;

        for (int i = 0; i < n; ++i) {
            if (i == dragIdx || !base[i].enabled) continue;
            const bool overlapsCols = (base[i].col < targetCol + origD.colSpan) && (base[i].col + base[i].colSpan > targetCol);
            if (overlapsCols) {
                if (base[i].col != targetCol || base[i].colSpan != origD.colSpan) {
                    allSameSpan = false;
                    break;
                }
                colPeers.append(i);
                totalRowsInCol += base[i].rowSpan;
            }
        }

        if (allSameSpan && totalRowsInCol <= m_rows) {
            std::sort(colPeers.begin(), colPeers.end(), [&](int a, int b) {
                return base[a].row < base[b].row;
            });

            int bestIns = 0;
            int bestDist = 999999;

            for (int ins = 0; ins <= colPeers.size(); ++ins) {
                int rCursor = 0;
                int dRow = 0;
                for (int k = 0; k <= colPeers.size(); ++k) {
                    if (k == ins) {
                        dRow = rCursor;
                        rCursor += origD.rowSpan;
                    }
                    if (k < colPeers.size()) {
                        rCursor += base[colPeers[k]].rowSpan;
                    }
                }
                const int dist = std::abs(dRow - targetRow);
                if (dist < bestDist) {
                    bestDist = dist;
                    bestIns = ins;
                }
            }

            QList<Placement> cand = base;
            int rCursor = 0;
            for (int k = 0; k <= colPeers.size(); ++k) {
                if (k == bestIns) {
                    cand[dragIdx].col = targetCol;
                    cand[dragIdx].row = rCursor;
                    rCursor += origD.rowSpan;
                }
                if (k < colPeers.size()) {
                    const int peerIdx = colPeers[k];
                    cand[peerIdx].col = targetCol;
                    cand[peerIdx].row = rCursor;
                    rCursor += cand[peerIdx].rowSpan;
                }
            }

            if (isLayoutValid(cand)) {
                outState = cand;
                return true;
            }
        }
    }

    // -------------------------------------------------------------------------
    // TIER 3: Exact Bounding-Box Block Swap (1-to-1, 1-to-Many, or Multi-Column)
    // -------------------------------------------------------------------------
    {
        QList<int> colliding;
        int minC = m_cols, minR = m_rows, maxC = 0, maxR = 0;

        for (int i = 0; i < n; ++i) {
            if (i == dragIdx || !base[i].enabled) continue;
            const uint64_t m = rectMask(base[i].col, base[i].row, base[i].colSpan, base[i].rowSpan, m_cols, m_rows);
            if ((m & targetMask) != 0ULL) {
                colliding.append(i);
                minC = std::min(minC, base[i].col);
                minR = std::min(minR, base[i].row);
                maxC = std::max(maxC, base[i].col + base[i].colSpan);
                maxR = std::max(maxR, base[i].row + base[i].rowSpan);
            }
        }

        if (!colliding.isEmpty() && (maxC - minC) == origD.colSpan && (maxR - minR) == origD.rowSpan) {
            QList<Placement> cand = base;
            cand[dragIdx].col = minC;
            cand[dragIdx].row = minR;
            for (int cIdx : colliding) {
                cand[cIdx].col = origD.col + (base[cIdx].col - minC);
                cand[cIdx].row = origD.row + (base[cIdx].row - minR);
            }
            if (isLayoutValid(cand)) {
                outState = cand;
                return true;
            }
        }
    }

    // -------------------------------------------------------------------------
    // TIER 4: Cross-Column Flexible Swap & Contiguous Block/Column Swap
    // -------------------------------------------------------------------------
    if (origD.colSpan == 1 && targetCol != origD.col) {
        QList<int> origColItems;
        QList<int> targetColItems;
        bool origSingleCol = true;
        bool targetSingleCol = true;

        for (int i = 0; i < n; ++i) {
            if (!base[i].enabled) continue;
            if (base[i].col <= origD.col && base[i].col + base[i].colSpan > origD.col) {
                if (base[i].colSpan != 1) origSingleCol = false;
                origColItems.append(i);
            }
            if (base[i].col <= targetCol && base[i].col + base[i].colSpan > targetCol) {
                if (base[i].colSpan != 1) targetSingleCol = false;
                targetColItems.append(i);
            }
        }

        std::sort(origColItems.begin(), origColItems.end(), [&](int a, int b) { return base[a].row < base[b].row; });
        std::sort(targetColItems.begin(), targetColItems.end(), [&](int a, int b) { return base[a].row < base[b].row; });

        if (origSingleCol && targetSingleCol && !targetColItems.isEmpty()) {
            // Find the primary hovered widget in targetCol
            const int dragCenterRow = targetRow + origD.rowSpan / 2;
            int hoveredTargetIdx = targetColItems.first();
            int bestCenterDist = 999999;
            for (int tIdx : targetColItems) {
                const int tCenter = base[tIdx].row + base[tIdx].rowSpan / 2;
                const int d = std::abs(tCenter - dragCenterRow);
                if (d < bestCenterDist) {
                    bestCenterDist = d;
                    hoveredTargetIdx = tIdx;
                }
            }

            // Subcase 4A: Smallest matching contiguous sub-blocks containing dragIdx and hoveredTargetIdx
            const int posD = origColItems.indexOf(dragIdx);
            const int posT = targetColItems.indexOf(hoveredTargetIdx);

            if (posD >= 0 && posT >= 0) {
                int bestSpanSum = 999999;
                int bestA1 = -1, bestA2 = -1, bestB1 = -1, bestB2 = -1;

                for (int a1 = 0; a1 <= posD; ++a1) {
                    for (int a2 = posD; a2 < origColItems.size(); ++a2) {
                        int sumA = 0;
                        for (int k = a1; k <= a2; ++k) sumA += base[origColItems[k]].rowSpan;

                        for (int b1 = 0; b1 <= posT; ++b1) {
                            for (int b2 = posT; b2 < targetColItems.size(); ++b2) {
                                int sumB = 0;
                                for (int k = b1; k <= b2; ++k) sumB += base[targetColItems[k]].rowSpan;

                                if (sumA == sumB && sumA < bestSpanSum) {
                                    // Prefer single-item or full-column swaps, or exact matches where D is the whole blockA
                                    if (a1 == a2 || (b1 == 0 && b2 == targetColItems.size() - 1) || (a1 == 0 && a2 == origColItems.size() - 1)) {
                                        bestSpanSum = sumA;
                                        bestA1 = a1; bestA2 = a2;
                                        bestB1 = b1; bestB2 = b2;
                                    }
                                }
                            }
                        }
                    }
                }

                // If the best match is a clean block swap where D is alone in blockA (e.g. calendar 1x5 <-> media 1x2 + weather 1x3)
                if (bestA1 != -1 && bestA1 == bestA2) {
                    QList<Placement> cand = base;
                    const int startRowA = base[origColItems[bestA1]].row;
                    const int startRowB = base[targetColItems[bestB1]].row;

                    cand[dragIdx].col = targetCol;
                    cand[dragIdx].row = startRowB;

                    int rCursor = startRowA;
                    for (int k = bestB1; k <= bestB2; ++k) {
                        const int idxB = targetColItems[k];
                        cand[idxB].col = origD.col;
                        cand[idxB].row = rCursor;
                        rCursor += cand[idxB].rowSpan;
                    }

                    if (isLayoutValid(cand)) {
                        outState = cand;
                        return true;
                    }
                }

                // Subcase 4B: 1-to-1 Card Swap across columns with neighbor flex (when hoveredTargetIdx is not a full-column widget)
                if (base[hoveredTargetIdx].rowSpan < m_rows) {
                    QList<Placement> cand = base;
                    cand[dragIdx].col = targetCol;
                    cand[hoveredTargetIdx].col = origD.col;

                    QList<int> newOrigCol = origColItems;
                    newOrigCol[posD] = hoveredTargetIdx;

                    QList<int> newTargetCol = targetColItems;
                    newTargetCol[posT] = dragIdx;

                    auto fitColumn = [&](QList<int> &colList, int colIndex, int primaryMovedIdx) -> bool {
                        int sum = 0;
                        for (int idx : colList) sum += cand[idx].rowSpan;

                        // Adjust other items first within [minRowSpan, maxRowSpan], then primaryMovedIdx if needed
                        while (sum > m_rows) {
                            int shrinkCandidate = -1;
                            int maxExcess = 0;
                            for (int idx : colList) {
                                if (idx == primaryMovedIdx) continue;
                                const int excess = cand[idx].rowSpan - m_items[idx].minRowSpan;
                                if (excess > maxExcess) {
                                    maxExcess = excess;
                                    shrinkCandidate = idx;
                                }
                            }
                            if (shrinkCandidate == -1 && cand[primaryMovedIdx].rowSpan > m_items[primaryMovedIdx].minRowSpan) {
                                shrinkCandidate = primaryMovedIdx;
                            }
                            if (shrinkCandidate == -1) return false;
                            cand[shrinkCandidate].rowSpan -= 1;
                            sum -= 1;
                        }

                        while (sum < m_rows) {
                            int growCandidate = -1;
                            for (int idx : colList) {
                                if (idx == primaryMovedIdx) continue;
                                if (cand[idx].rowSpan < m_items[idx].maxRowSpan) {
                                    growCandidate = idx;
                                    break;
                                }
                            }
                            if (growCandidate == -1 && cand[primaryMovedIdx].rowSpan < m_items[primaryMovedIdx].maxRowSpan) {
                                growCandidate = primaryMovedIdx;
                            }
                            if (growCandidate == -1) break;
                            cand[growCandidate].rowSpan += 1;
                            sum += 1;
                        }

                        int rCursor = 0;
                        for (int idx : colList) {
                            cand[idx].col = colIndex;
                            cand[idx].row = rCursor;
                            rCursor += cand[idx].rowSpan;
                        }
                        return rCursor <= m_rows;
                    };

                    if (fitColumn(newOrigCol, origD.col, hoveredTargetIdx) &&
                        fitColumn(newTargetCol, targetCol, dragIdx) &&
                        isLayoutValid(cand)) {
                        outState = cand;
                        return true;
                    }
                }

                // Subcase 4C: Full-column / Superset block swap (e.g. dragging onto notifications 1x10)
                if (bestA1 != -1) {
                    QList<Placement> cand = base;
                    const int startRowA = base[origColItems[bestA1]].row;
                    const int startRowB = base[targetColItems[bestB1]].row;

                    // Reorder block A according to targetRow if multiple items move together
                    QList<int> blockA;
                    for (int k = bestA1; k <= bestA2; ++k) {
                        if (origColItems[k] != dragIdx) blockA.append(origColItems[k]);
                    }
                    int bestIns = 0;
                    int bestDist = 999999;
                    for (int ins = 0; ins <= blockA.size(); ++ins) {
                        int rCur = startRowB;
                        int dRow = startRowB;
                        for (int k = 0; k <= blockA.size(); ++k) {
                            if (k == ins) { dRow = rCur; rCur += origD.rowSpan; }
                            if (k < blockA.size()) rCur += cand[blockA[k]].rowSpan;
                        }
                        if (std::abs(dRow - targetRow) < bestDist) {
                            bestDist = std::abs(dRow - targetRow);
                            bestIns = ins;
                        }
                    }

                    int rCurB = startRowB;
                    for (int k = 0; k <= blockA.size(); ++k) {
                        if (k == bestIns) {
                            cand[dragIdx].col = targetCol;
                            cand[dragIdx].row = rCurB;
                            rCurB += cand[dragIdx].rowSpan;
                        }
                        if (k < blockA.size()) {
                            const int idxA = blockA[k];
                            cand[idxA].col = targetCol;
                            cand[idxA].row = rCurB;
                            rCurB += cand[idxA].rowSpan;
                        }
                    }

                    int rCurA = startRowA;
                    for (int k = bestB1; k <= bestB2; ++k) {
                        const int idxB = targetColItems[k];
                        cand[idxB].col = origD.col;
                        cand[idxB].row = rCurA;
                        rCurA += cand[idxB].rowSpan;
                    }

                    if (isLayoutValid(cand)) {
                        outState = cand;
                        return true;
                    }
                }
            }
        }
    }

    return false;
}

void BentoModel::applyPreviewState(const QList<Placement> &newState, int dropC, int dropR, int dropCS, int dropRS, bool valid) {
    for (int i = 0; i < m_items.size() && i < newState.size(); ++i) {
        QList<int> changedRoles;
        if (m_items[i].previewCol != newState[i].col) {
            m_items[i].previewCol = newState[i].col;
            changedRoles.append(PreviewColRole);
        }
        if (m_items[i].previewRow != newState[i].row) {
            m_items[i].previewRow = newState[i].row;
            changedRoles.append(PreviewRowRole);
        }
        if (m_items[i].previewColSpan != newState[i].colSpan) {
            m_items[i].previewColSpan = newState[i].colSpan;
            changedRoles.append(PreviewColSpanRole);
        }
        if (m_items[i].previewRowSpan != newState[i].rowSpan) {
            m_items[i].previewRowSpan = newState[i].rowSpan;
            changedRoles.append(PreviewRowSpanRole);
        }
        if (!changedRoles.isEmpty()) {
            const QModelIndex idx = index(i, 0);
            emit dataChanged(idx, idx, changedRoles);
        }
    }

    if (m_dropCol != dropC || m_dropRow != dropR || m_dropColSpan != dropCS || m_dropRowSpan != dropRS || m_dropValid != valid) {
        m_dropCol = dropC;
        m_dropRow = dropR;
        m_dropColSpan = dropCS;
        m_dropRowSpan = dropRS;
        m_dropValid = valid;
        emit dropTargetChanged();
    }
}

void BentoModel::updateDragTarget(int targetCol, int targetRow) {
    if (m_activeDragIdx < 0 || m_activeDragIdx >= m_items.size()) return;

    const BentoItem &dragItem = m_items[m_activeDragIdx];
    const int clampedCol = std::clamp(targetCol, 0, std::max(0, m_cols - dragItem.colSpan));
    const int clampedRow = std::clamp(targetRow, 0, std::max(0, m_rows - dragItem.rowSpan));

    // Short-circuit if pointer is still inside the same grid cell
    if (clampedCol == m_lastTargetCol && clampedRow == m_lastTargetRow) {
        return;
    }
    m_lastTargetCol = clampedCol;
    m_lastTargetRow = clampedRow;

    QList<Placement> solved;
    if (solveMove(m_activeDragIdx, clampedCol, clampedRow, solved)) {
        const Placement &dp = solved[m_activeDragIdx];
        applyPreviewState(solved, dp.col, dp.row, dp.colSpan, dp.rowSpan, true);
    } else {
        // Keep last valid preview state for neighbors, mark drop target position
        QList<Placement> currentPreview(m_items.size());
        for (int i = 0; i < m_items.size(); ++i) {
            currentPreview[i] = {m_items[i].previewCol, m_items[i].previewRow, m_items[i].previewColSpan, m_items[i].previewRowSpan, m_items[i].enabled};
        }
        applyPreviewState(currentPreview, clampedCol, clampedRow, dragItem.colSpan, dragItem.rowSpan, false);
    }
}

void BentoModel::commitDrag() {
    if (m_activeDragIdx < 0 || m_activeDragIdx >= m_items.size()) return;

    for (int i = 0; i < m_items.size(); ++i) {
        QList<int> changedRoles;
        if (m_items[i].col != m_items[i].previewCol) {
            m_items[i].col = m_items[i].previewCol;
            changedRoles.append(ColRole);
        }
        if (m_items[i].row != m_items[i].previewRow) {
            m_items[i].row = m_items[i].previewRow;
            changedRoles.append(RowRole);
        }
        if (m_items[i].colSpan != m_items[i].previewColSpan) {
            m_items[i].colSpan = m_items[i].previewColSpan;
            changedRoles.append(ColSpanRole);
        }
        if (m_items[i].rowSpan != m_items[i].previewRowSpan) {
            m_items[i].rowSpan = m_items[i].previewRowSpan;
            changedRoles.append(RowSpanRole);
        }
        if (!changedRoles.isEmpty()) {
            const QModelIndex idx = index(i, 0);
            emit dataChanged(idx, idx, changedRoles);
        }
    }

    m_activeDragId.clear();
    m_activeDragIdx = -1;
    m_lastTargetCol = -1;
    m_lastTargetRow = -1;
    m_dropValid = false;

    emit dragStateChanged();
    emit dropTargetChanged();
    saveLayout();
}

void BentoModel::cancelDrag() {
    if (m_activeDragIdx < 0) return;

    for (int i = 0; i < m_items.size(); ++i) {
        QList<int> changedRoles;
        if (m_items[i].previewCol != m_items[i].col) {
            m_items[i].previewCol = m_items[i].col;
            changedRoles.append(PreviewColRole);
        }
        if (m_items[i].previewRow != m_items[i].row) {
            m_items[i].previewRow = m_items[i].row;
            changedRoles.append(PreviewRowRole);
        }
        if (m_items[i].previewColSpan != m_items[i].colSpan) {
            m_items[i].previewColSpan = m_items[i].colSpan;
            changedRoles.append(PreviewColSpanRole);
        }
        if (m_items[i].previewRowSpan != m_items[i].rowSpan) {
            m_items[i].previewRowSpan = m_items[i].rowSpan;
            changedRoles.append(PreviewRowSpanRole);
        }
        if (!changedRoles.isEmpty()) {
            const QModelIndex idx = index(i, 0);
            emit dataChanged(idx, idx, changedRoles);
        }
    }

    m_activeDragId.clear();
    m_activeDragIdx = -1;
    m_lastTargetCol = -1;
    m_lastTargetRow = -1;
    m_dropValid = false;

    emit dragStateChanged();
    emit dropTargetChanged();
}

bool BentoModel::resizeWidget(const QString &widgetId, int newColSpan, int newRowSpan) {
    const int idx = findIndexById(widgetId);
    if (idx < 0 || !m_items[idx].enabled) return false;

    newColSpan = std::clamp(newColSpan, 1, m_cols);
    newRowSpan = std::clamp(newRowSpan, 2, m_rows);

    const int n = m_items.size();
    QList<Placement> cand(n);
    for (int i = 0; i < n; ++i) {
        cand[i] = {m_items[i].col, m_items[i].row, m_items[i].colSpan, m_items[i].rowSpan, m_items[i].enabled};
    }

    cand[idx].colSpan = newColSpan;
    cand[idx].rowSpan = newRowSpan;
    cand[idx].col = std::clamp(cand[idx].col, 0, m_cols - newColSpan);
    cand[idx].row = std::clamp(cand[idx].row, 0, m_rows - newRowSpan);

    bool solved = isLayoutValid(cand);

    // If single-column resize causes vertical overlap or gap in the column, repack/flex neighbors in that column
    if (!solved && newColSpan == 1 && m_items[idx].colSpan == 1) {
        const int col = cand[idx].col;
        QList<int> colItems;
        bool allSingle = true;
        for (int i = 0; i < n; ++i) {
            if (!cand[i].enabled) continue;
            if (cand[i].col <= col && cand[i].col + cand[i].colSpan > col) {
                if (cand[i].colSpan != 1) allSingle = false;
                colItems.append(i);
            }
        }
        if (allSingle) {
            std::sort(colItems.begin(), colItems.end(), [&](int a, int b) { return m_items[a].row < m_items[b].row; });
            int sum = 0;
            for (int i : colItems) sum += cand[i].rowSpan;

            while (sum > m_rows) {
                int shrinkIdx = -1;
                for (int i : colItems) {
                    if (i != idx && cand[i].rowSpan > m_items[i].minRowSpan) {
                        shrinkIdx = i;
                        break;
                    }
                }
                if (shrinkIdx == -1) break;
                cand[shrinkIdx].rowSpan -= 1;
                sum -= 1;
            }

            if (sum <= m_rows) {
                int rCur = 0;
                for (int i : colItems) {
                    cand[i].row = rCur;
                    rCur += cand[i].rowSpan;
                }
                solved = isLayoutValid(cand);
            }
        }
    }

    if (!solved) return false;

    for (int i = 0; i < n; ++i) {
        m_items[i].col = cand[i].col;
        m_items[i].row = cand[i].row;
        m_items[i].colSpan = cand[i].colSpan;
        m_items[i].rowSpan = cand[i].rowSpan;
        m_items[i].previewCol = cand[i].col;
        m_items[i].previewRow = cand[i].row;
        m_items[i].previewColSpan = cand[i].colSpan;
        m_items[i].previewRowSpan = cand[i].rowSpan;
        const QModelIndex mIdx = index(i, 0);
        emit dataChanged(mIdx, mIdx, {ColRole, RowRole, PreviewColRole, PreviewRowRole, ColSpanRole, RowSpanRole, PreviewColSpanRole, PreviewRowSpanRole});
    }

    saveLayout();
    return true;
}

void BentoModel::cycleWidgetSize(const QString &widgetId) {
    const int idx = findIndexById(widgetId);
    if (idx < 0) return;

    const auto &presets = m_items[idx].presets;
    if (presets.size() <= 1) return;

    int curPresetIdx = 0;
    for (int i = 0; i < presets.size(); ++i) {
        if (presets[i].colSpan == m_items[idx].colSpan && presets[i].rowSpan == m_items[idx].rowSpan) {
            curPresetIdx = i;
            break;
        }
    }

    for (int step = 1; step <= presets.size(); ++step) {
        const int nextIdx = (curPresetIdx + step) % presets.size();
        if (resizeWidget(widgetId, presets[nextIdx].colSpan, presets[nextIdx].rowSpan)) {
            return;
        }
    }
}

void BentoModel::setWidgetEnabled(const QString &widgetId, bool enabled) {
    const int idx = findIndexById(widgetId);
    if (idx < 0 || m_items[idx].enabled == enabled) return;

    if (!enabled) {
        m_items[idx].enabled = false;
        const QModelIndex mIdx = index(idx, 0);
        emit dataChanged(mIdx, mIdx, {EnabledRole});
        emit hiddenWidgetsChanged();
        saveLayout();
        return;
    }

    // Re-enabling widget: find a valid placement
    uint64_t occupied = 0ULL;
    for (int i = 0; i < m_items.size(); ++i) {
        if (i == idx || !m_items[i].enabled) continue;
        occupied |= rectMask(m_items[i].col, m_items[i].row, m_items[i].colSpan, m_items[i].rowSpan, m_cols, m_rows);
    }

    int targetCS = m_items[idx].defaultColSpan;
    int targetRS = m_items[idx].defaultRowSpan;
    bool placed = false;

    // 1. Check default position first
    const uint64_t defMask = rectMask(m_items[idx].defaultCol, m_items[idx].defaultRow, targetCS, targetRS, m_cols, m_rows);
    if (defMask != 0ULL && (occupied & defMask) == 0ULL) {
        m_items[idx].col = m_items[idx].defaultCol;
        m_items[idx].row = m_items[idx].defaultRow;
        m_items[idx].colSpan = targetCS;
        m_items[idx].rowSpan = targetRS;
        placed = true;
    }

    // 2. Scan all cells for a free slot of default size or minRowSpan
    for (int tryRS : {targetRS, m_items[idx].minRowSpan}) {
        if (placed) break;
        for (int c = 0; c <= m_cols - targetCS && !placed; ++c) {
            for (int r = 0; r <= m_rows - tryRS && !placed; ++r) {
                const uint64_t m = rectMask(c, r, targetCS, tryRS, m_cols, m_rows);
                if (m != 0ULL && (occupied & m) == 0ULL) {
                    m_items[idx].col = c;
                    m_items[idx].row = r;
                    m_items[idx].colSpan = targetCS;
                    m_items[idx].rowSpan = tryRS;
                    placed = true;
                }
            }
        }
    }

    // 3. If grid is full, compact widgets in default column (or any single-span column) to make room
    if (!placed) {
        for (int c = 0; c < m_cols && !placed; ++c) {
            const int colToTry = (c == 0) ? m_items[idx].defaultCol : (c - 1 == m_items[idx].defaultCol ? c : c - 1);
            QList<int> colPeers;
            bool allSingle = true;
            int minPossibleSum = 0;
            for (int i = 0; i < m_items.size(); ++i) {
                if (i == idx || !m_items[i].enabled) continue;
                if (m_items[i].col <= colToTry && m_items[i].col + m_items[i].colSpan > colToTry) {
                    if (m_items[i].colSpan != 1) allSingle = false;
                    colPeers.append(i);
                    minPossibleSum += m_items[i].minRowSpan;
                }
            }
            const int neededRS = m_items[idx].minRowSpan;
            if (allSingle && minPossibleSum + neededRS <= m_rows) {
                std::sort(colPeers.begin(), colPeers.end(), [&](int a, int b) { return m_items[a].row < m_items[b].row; });
                int currentSum = 0;
                for (int p : colPeers) currentSum += m_items[p].rowSpan;

                while (currentSum + neededRS > m_rows) {
                    int shrinkPeer = -1;
                    for (int p : colPeers) {
                        if (m_items[p].rowSpan > m_items[p].minRowSpan) {
                            shrinkPeer = p;
                            break;
                        }
                    }
                    if (shrinkPeer == -1) break;
                    m_items[shrinkPeer].rowSpan -= 1;
                    m_items[shrinkPeer].previewRowSpan = m_items[shrinkPeer].rowSpan;
                    currentSum -= 1;
                }

                int rCur = 0;
                for (int p : colPeers) {
                    m_items[p].col = colToTry;
                    m_items[p].row = rCur;
                    m_items[p].previewCol = colToTry;
                    m_items[p].previewRow = rCur;
                    rCur += m_items[p].rowSpan;
                    const QModelIndex pIdx = index(p, 0);
                    emit dataChanged(pIdx, pIdx, {ColRole, RowRole, PreviewColRole, PreviewRowRole, RowSpanRole, PreviewRowSpanRole});
                }

                m_items[idx].col = colToTry;
                m_items[idx].row = rCur;
                m_items[idx].colSpan = 1;
                m_items[idx].rowSpan = m_rows - rCur;
                placed = true;
            }
        }
    }

    if (!placed) {
        // Fallback: reset to default so all widgets fit cleanly
        resetToDefault();
        return;
    }

    m_items[idx].previewCol = m_items[idx].col;
    m_items[idx].previewRow = m_items[idx].row;
    m_items[idx].previewColSpan = m_items[idx].colSpan;
    m_items[idx].previewRowSpan = m_items[idx].rowSpan;
    m_items[idx].enabled = true;

    const QModelIndex mIdx = index(idx, 0);
    emit dataChanged(mIdx, mIdx, {ColRole, RowRole, PreviewColRole, PreviewRowRole, ColSpanRole, RowSpanRole, PreviewColSpanRole, PreviewRowSpanRole, EnabledRole});
    emit hiddenWidgetsChanged();
    saveLayout();
}

void BentoModel::applyPreset(const QString &presetId) {
    struct PresetCoord {
        const char *id;
        int col;
        int row;
        int colSpan;
        int rowSpan;
    };

    QList<PresetCoord> coords;
    if (presetId == QStringLiteral("focus")) {
        coords = {
            {"notifications", 0, 0, 1, 10},
            {"clock",         1, 0, 1, 2},
            {"calendar",      1, 2, 1, 5},
            {"weather",       1, 7, 1, 3},
            {"userInfo",      2, 0, 1, 4},
            {"github",        2, 4, 1, 4},
            {"media",         2, 8, 1, 2}
        };
    } else if (presetId == QStringLiteral("wide")) {
        coords = {
            {"media",         0, 0, 2, 2},
            {"userInfo",      0, 2, 1, 4},
            {"github",        0, 6, 1, 4},
            {"notifications", 1, 2, 1, 8},
            {"clock",         2, 0, 1, 2},
            {"weather",       2, 2, 1, 3},
            {"calendar",      2, 5, 1, 5}
        };
    } else {
        // Default ("default")
        for (int i = 0; i < m_items.size(); ++i) {
            m_items[i].col = m_items[i].defaultCol;
            m_items[i].row = m_items[i].defaultRow;
            m_items[i].colSpan = m_items[i].defaultColSpan;
            m_items[i].rowSpan = m_items[i].defaultRowSpan;
            m_items[i].previewCol = m_items[i].col;
            m_items[i].previewRow = m_items[i].row;
            m_items[i].previewColSpan = m_items[i].colSpan;
            m_items[i].previewRowSpan = m_items[i].rowSpan;
            m_items[i].enabled = m_items[i].defaultEnabled;
        }
        m_currentPreset = QStringLiteral("default");
        if (!m_items.isEmpty()) {
            emit dataChanged(index(0, 0), index(m_items.size() - 1, 0));
        }
        emit currentPresetChanged();
        emit hiddenWidgetsChanged();
        saveLayout();
        return;
    }

    for (const auto &pc : coords) {
        const int idx = findIndexById(QString::fromLatin1(pc.id));
        if (idx >= 0) {
            m_items[idx].col = pc.col;
            m_items[idx].row = pc.row;
            m_items[idx].colSpan = pc.colSpan;
            m_items[idx].rowSpan = pc.rowSpan;
            m_items[idx].previewCol = pc.col;
            m_items[idx].previewRow = pc.row;
            m_items[idx].previewColSpan = pc.colSpan;
            m_items[idx].previewRowSpan = pc.rowSpan;
            m_items[idx].enabled = true;
        }
    }

    m_currentPreset = presetId;
    if (!m_items.isEmpty()) {
        emit dataChanged(index(0, 0), index(m_items.size() - 1, 0));
    }
    emit currentPresetChanged();
    emit hiddenWidgetsChanged();
    saveLayout();
}

void BentoModel::resetToDefault() {
    applyPreset(QStringLiteral("default"));
}

QString BentoModel::getLayoutFilePath() const {
    const QString configDir = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation) + QStringLiteral("/sleex");
    QDir dir(configDir);
    if (!dir.exists()) {
        dir.mkpath(QStringLiteral("."));
    }
    return configDir + QStringLiteral("/bento_layout.json");
}

void BentoModel::saveLayout() const {
    QJsonObject root;
    root[QStringLiteral("version")] = 1;
    root[QStringLiteral("columns")] = m_cols;
    root[QStringLiteral("rows")] = m_rows;
    root[QStringLiteral("preset")] = m_currentPreset;

    QJsonArray itemsArr;
    for (const auto &item : m_items) {
        QJsonObject obj;
        obj[QStringLiteral("id")] = item.id;
        obj[QStringLiteral("col")] = item.col;
        obj[QStringLiteral("row")] = item.row;
        obj[QStringLiteral("colSpan")] = item.colSpan;
        obj[QStringLiteral("rowSpan")] = item.rowSpan;
        obj[QStringLiteral("enabled")] = item.enabled;
        itemsArr.append(obj);
    }
    root[QStringLiteral("items")] = itemsArr;

    QFile file(getLayoutFilePath());
    if (file.open(QIODevice::WriteOnly)) {
        file.write(QJsonDocument(root).toJson(QJsonDocument::Indented));
        file.close();
    } else {
        qWarning() << "[BentoModel] Cannot save layout to" << getLayoutFilePath();
    }
}

bool BentoModel::loadLayout() {
    QFile file(getLayoutFilePath());
    if (!file.open(QIODevice::ReadOnly)) {
        return false;
    }

    const QByteArray raw = file.readAll();
    file.close();

    const QJsonDocument doc = QJsonDocument::fromJson(raw);
    if (!doc.isObject()) return false;

    const QJsonObject root = doc.object();
    m_currentPreset = root.value(QStringLiteral("preset")).toString(QStringLiteral("default"));

    const QJsonArray itemsArr = root.value(QStringLiteral("items")).toArray();
    if (itemsArr.isEmpty()) return false;

    QList<Placement> loadedState(m_items.size());
    for (int i = 0; i < m_items.size(); ++i) {
        loadedState[i] = {m_items[i].defaultCol, m_items[i].defaultRow, m_items[i].defaultColSpan, m_items[i].defaultRowSpan, m_items[i].defaultEnabled};
    }

    for (const QJsonValue &val : itemsArr) {
        const QJsonObject obj = val.toObject();
        const QString id = obj.value(QStringLiteral("id")).toString();
        const int idx = findIndexById(id);
        if (idx >= 0) {
            loadedState[idx].col = obj.value(QStringLiteral("col")).toInt(loadedState[idx].col);
            loadedState[idx].row = obj.value(QStringLiteral("row")).toInt(loadedState[idx].row);
            loadedState[idx].colSpan = obj.value(QStringLiteral("colSpan")).toInt(loadedState[idx].colSpan);
            loadedState[idx].rowSpan = obj.value(QStringLiteral("rowSpan")).toInt(loadedState[idx].rowSpan);
            loadedState[idx].enabled = obj.value(QStringLiteral("enabled")).toBool(true);
        }
    }

    if (!isLayoutValid(loadedState)) {
        qWarning() << "[BentoModel] Saved layout had invalid/overlapping bounds, falling back to default.";
        return false;
    }

    for (int i = 0; i < m_items.size(); ++i) {
        m_items[i].col = loadedState[i].col;
        m_items[i].row = loadedState[i].row;
        m_items[i].colSpan = loadedState[i].colSpan;
        m_items[i].rowSpan = loadedState[i].rowSpan;
        m_items[i].enabled = loadedState[i].enabled;
        m_items[i].previewCol = loadedState[i].col;
        m_items[i].previewRow = loadedState[i].row;
        m_items[i].previewColSpan = loadedState[i].colSpan;
        m_items[i].previewRowSpan = loadedState[i].rowSpan;
    }

    return true;
}
