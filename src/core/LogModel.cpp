#include "LogModel.h"

#include <QDateTime>

LogModel::LogModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int LogModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) {
        return 0;
    }

    return m_messages.size();
}

QVariant LogModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_messages.size()) {
        return {};
    }

    if (role == MessageRole) {
        return m_messages.at(index.row());
    }

    return {};
}

QHash<int, QByteArray> LogModel::roleNames() const
{
    return {{MessageRole, "message"}};
}

void LogModel::clear()
{
    beginResetModel();
    m_messages.clear();
    endResetModel();
}

void LogModel::append(const QString &message)
{
    beginInsertRows({}, m_messages.size(), m_messages.size());
    const QString time = QDateTime::currentDateTime().toString(QStringLiteral("HH:mm:ss"));
    m_messages.append(QStringLiteral("[%1] %2").arg(time, message));
    endInsertRows();
}
