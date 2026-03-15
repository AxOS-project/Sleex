#pragma once

#include <QAbstractListModel>
#include <QList>
#include <QString>
#include <QQmlEngine>

struct DesktopItem {
    QString fileName;
    QString filePath;
    bool isDir;
    int gridX;
    int gridY;
};

class DesktopModel : public QAbstractListModel {
    Q_OBJECT
    QML_ELEMENT

public:
    enum DesktopRoles {
        FileNameRole = Qt::UserRole + 1,
        FilePathRole,
        IsDirRole,
        GridXRole,
        GridYRole
    };

    explicit DesktopModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void loadDirectory(const QString &path);
    Q_INVOKABLE void moveIcon(int index, int newX, int newY);
    Q_INVOKABLE void massMove(const QVariantList &selectedPathsList, const QString &leaderPath, int targetX, int targetY, int maxCol, int maxRow);

private:
    QList<DesktopItem> m_items;
    void saveCurrentLayout();
};