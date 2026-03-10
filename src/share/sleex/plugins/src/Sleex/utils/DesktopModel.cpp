#include "DesktopModel.hpp"
#include "DesktopStateManager.hpp"
#include <QDir>
#include <QFileInfoList>

DesktopModel::DesktopModel(QObject *parent) : QAbstractListModel(parent) {}

int DesktopModel::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) return 0;
    return m_items.count();
}

QVariant DesktopModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= m_items.size()) return QVariant();

    const DesktopItem &item = m_items[index.row()];
    switch (role) {
        case FileNameRole: return item.fileName;
        case FilePathRole: return item.filePath;
        case IsDirRole: return item.isDir;
        case GridXRole: return item.gridX;
        case GridYRole: return item.gridY;
        default: return QVariant();
    }
}

QHash<int, QByteArray> DesktopModel::roleNames() const {
    QHash<int, QByteArray> roles;
    roles[FileNameRole] = "fileName";
    roles[FilePathRole] = "filePath";
    roles[IsDirRole] = "isDir";
    roles[GridXRole] = "gridX";
    roles[GridYRole] = "gridY";
    return roles;
}

void DesktopModel::loadDirectory(const QString &path) {
    beginResetModel();
    m_items.clear();

    QDir dir(path);
    dir.setFilter(QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot);
    QFileInfoList list = dir.entryInfoList();

    DesktopStateManager sm;
    QVariantMap savedLayout = sm.getLayout();

    for (const QFileInfo &fileInfo : list) {
        DesktopItem item;
        item.fileName = fileInfo.fileName();
        item.filePath = fileInfo.absoluteFilePath();
        item.isDir = fileInfo.isDir();
        
        if (savedLayout.contains(item.fileName)) {
            QVariantMap pos = savedLayout[item.fileName].toMap();
            item.gridX = pos["x"].toInt();
            item.gridY = pos["y"].toInt();
        } else {
            // TODO: make getEmptySpot in C++ and call it here to get the initial position for new icons
            item.gridX = 0; 
            item.gridY = 0;
        }
        m_items.append(item);
    }
    endResetModel();
}

void DesktopModel::moveIcon(int index, int newX, int newY) {
    if (index < 0 || index >= m_items.size()) return;

    m_items[index].gridX = newX;
    m_items[index].gridY = newY;

    QModelIndex modelIndex = createIndex(index, 0);
    emit dataChanged(modelIndex, modelIndex, {GridXRole, GridYRole});

    saveCurrentLayout();
}

void DesktopModel::saveCurrentLayout() {
    QVariantMap layout;
    for (const auto& item : m_items) {
        QVariantMap pos;
        pos["x"] = item.gridX;
        pos["y"] = item.gridY;
        layout[item.fileName] = pos;
    }
    
    DesktopStateManager sm;
    sm.saveLayout(layout);
}

void DesktopModel::massMove(const QVariantList& selectedPathsList, const QString& leaderPath, int targetX, int targetY, int maxCol, int maxRow) {
    QStringList selectedPaths;
    for (const QVariant& v : selectedPathsList) {
        selectedPaths << v.toString();
    }

    if (selectedPaths.isEmpty()) return;

    int oldX = 0, oldY = 0;
    for (const auto& item : m_items) {
        if (item.filePath == leaderPath) {
            oldX = item.gridX;
            oldY = item.gridY;
            break;
        }
    }

    int deltaX = targetX - oldX;
    int deltaY = targetY - oldY;

    if (deltaX == 0 && deltaY == 0) return;

    if (selectedPaths.size() == 1 && targetX >= 0 && targetX <= maxCol && targetY >= 0 && targetY <= maxRow) {
        QString movingPath = selectedPaths.first();
        int movingIndex = -1;
        int targetIndex = -1;

        for (int i = 0; i < m_items.size(); ++i) {
            if (m_items[i].filePath == movingPath) {
                movingIndex = i;
            } else if (m_items[i].gridX == targetX && m_items[i].gridY == targetY) {
                targetIndex = i;
            }
        }

        if (targetIndex != -1 && movingIndex != -1) {
            m_items[targetIndex].gridX = oldX;
            m_items[targetIndex].gridY = oldY;
            m_items[movingIndex].gridX = targetX;
            m_items[movingIndex].gridY = targetY;

            emit dataChanged(index(0, 0), index(m_items.size() - 1, 0), {GridXRole, GridYRole});
            saveCurrentLayout();
            return;
        }
    }

    QList<DesktopItem*> movingItems;
    QSet<QString> occupied;

    for (int i = 0; i < m_items.size(); ++i) {
        if (selectedPaths.contains(m_items[i].filePath)) {
            movingItems.append(&m_items[i]);
        } else {
            occupied.insert(QString::number(m_items[i].gridX) + "," + QString::number(m_items[i].gridY));
        }
    }

    for (auto* item : movingItems) {
        int newX = item->gridX + deltaX;
        int newY = item->gridY + deltaY;

        bool outOfBounds = newX < 0 || newX > maxCol || newY < 0 || newY > maxRow;
        bool collision = occupied.contains(QString::number(newX) + "," + QString::number(newY));

        if (outOfBounds || collision) {
            bool found = false;
            for (int x = 0; x <= maxCol && !found; ++x) {
                for (int y = 0; y <= maxRow && !found; ++y) {
                    QString key = QString::number(x) + "," + QString::number(y);
                    if (!occupied.contains(key)) {
                        newX = x;
                        newY = y;
                        occupied.insert(key);
                        found = true;
                    }
                }
            }
        } else {
            occupied.insert(QString::number(newX) + "," + QString::number(newY));
        }

        item->gridX = newX;
        item->gridY = newY;
    }

    emit dataChanged(index(0, 0), index(m_items.size() - 1, 0), {GridXRole, GridYRole});
    saveCurrentLayout();
}