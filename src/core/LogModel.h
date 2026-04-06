#pragma once

#include <QAbstractListModel>
#include <QStringList>

class LogModel : public QAbstractListModel
{
    Q_OBJECT

public:
    enum Roles {
        MessageRole = Qt::UserRole + 1
    };

    explicit LogModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void clear();
    void append(const QString &message);

private:
    QStringList m_messages;
};
