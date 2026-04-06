#include "ConversionQueueModel.h"

#include <QDir>
#include <QFileInfo>

ConversionQueueModel::ConversionQueueModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int ConversionQueueModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) {
        return 0;
    }

    return m_items.size();
}

QVariant ConversionQueueModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_items.size()) {
        return {};
    }

    const ConversionItem &item = m_items.at(index.row());

    switch (role) {
    case FileNameRole:
        return item.fileName;
    case SourcePathRole:
        return item.sourcePath;
    case OutputPathRole:
        return item.outputPath;
    case LocationHintRole:
        return item.locationHint;
    case StatusRole:
        return static_cast<int>(item.status);
    case StatusLabelRole:
        return statusToLabel(item.status);
    case MessageRole:
        return item.statusMessage;
    case ProgressRole:
        return item.progress;
    case AudioCodecRole:
        return item.audioCodec;
    case VideoCodecRole:
        return item.videoCodec;
    case HasAudioRole:
        return item.hasAudio;
    case HasVideoRole:
        return item.hasVideo;
    case AlreadyCompatibleRole:
        return item.alreadyCompatible;
    default:
        return {};
    }
}

QHash<int, QByteArray> ConversionQueueModel::roleNames() const
{
    return {
        {FileNameRole, "fileName"},
        {SourcePathRole, "sourcePath"},
        {OutputPathRole, "outputPath"},
        {LocationHintRole, "locationHint"},
        {StatusRole, "status"},
        {StatusLabelRole, "statusLabel"},
        {MessageRole, "message"},
        {ProgressRole, "progress"},
        {AudioCodecRole, "audioCodec"},
        {VideoCodecRole, "videoCodec"},
        {HasAudioRole, "hasAudio"},
        {HasVideoRole, "hasVideo"},
        {AlreadyCompatibleRole, "alreadyCompatible"},
    };
}

bool ConversionQueueModel::containsSource(const QString &path) const
{
    return m_sources.contains(QFileInfo(path).canonicalFilePath().isEmpty() ? QFileInfo(path).absoluteFilePath()
                                                                            : QFileInfo(path).canonicalFilePath());
}

int ConversionQueueModel::addFile(const QString &path)
{
    const QFileInfo info(path);
    const QString normalized = info.canonicalFilePath().isEmpty() ? info.absoluteFilePath() : info.canonicalFilePath();
    if (m_sources.contains(normalized)) {
        return -1;
    }

    beginInsertRows({}, m_items.size(), m_items.size());
    ConversionItem item;
    item.sourcePath = normalized;
    item.fileName = info.fileName();
    item.locationHint = info.dir().dirName();
    item.statusMessage = QStringLiteral("Pronto para analisar");
    m_items.push_back(item);
    endInsertRows();

    m_sources.insert(normalized);
    return m_items.size() - 1;
}

void ConversionQueueModel::clear()
{
    beginResetModel();
    m_items.clear();
    m_sources.clear();
    endResetModel();
}

int ConversionQueueModel::count() const
{
    return m_items.size();
}

int ConversionQueueModel::pendingCount() const
{
    int total = 0;
    for (const auto &item : m_items) {
        if (item.status == ConversionItem::Status::Pending) {
            ++total;
        }
    }
    return total;
}

int ConversionQueueModel::completedCount() const
{
    int total = 0;
    for (const auto &item : m_items) {
        if (item.status == ConversionItem::Status::Completed
            || item.status == ConversionItem::Status::Warning
            || item.status == ConversionItem::Status::Skipped) {
            ++total;
        }
    }
    return total;
}

int ConversionQueueModel::nextPendingIndex() const
{
    for (int i = 0; i < m_items.size(); ++i) {
        if (m_items.at(i).status == ConversionItem::Status::Pending) {
            return i;
        }
    }
    return -1;
}

ConversionItem ConversionQueueModel::itemAt(int index) const
{
    return m_items.value(index);
}

QStringList ConversionQueueModel::sourcePaths() const
{
    QStringList paths;
    paths.reserve(m_items.size());
    for (const auto &item : m_items) {
        paths.push_back(item.sourcePath);
    }
    return paths;
}

void ConversionQueueModel::setOutputPath(int index, const QString &outputPath)
{
    if (index < 0 || index >= m_items.size()) {
        return;
    }

    m_items[index].outputPath = outputPath;
    emitDataChanged(index, {OutputPathRole});
}

void ConversionQueueModel::setProcessingState(int index, ConversionItem::Status status, const QString &message)
{
    if (index < 0 || index >= m_items.size()) {
        return;
    }

    m_items[index].status = status;
    if (!message.isEmpty()) {
        m_items[index].statusMessage = message;
    }

    if (status == ConversionItem::Status::Completed
        || status == ConversionItem::Status::Warning
        || status == ConversionItem::Status::Skipped) {
        m_items[index].progress = 100;
    }

    emitDataChanged(index, {StatusRole, StatusLabelRole, MessageRole, ProgressRole});
}

void ConversionQueueModel::setProgress(int index, int progress, const QString &message)
{
    if (index < 0 || index >= m_items.size()) {
        return;
    }

    m_items[index].progress = qBound(0, progress, 100);
    if (!message.isEmpty()) {
        m_items[index].statusMessage = message;
    }
    emitDataChanged(index, {ProgressRole, MessageRole});
}

void ConversionQueueModel::setProbeInfo(int index,
                                        bool hasVideo,
                                        bool hasAudio,
                                        const QString &videoCodec,
                                        const QString &audioCodec,
                                        bool alreadyCompatible,
                                        const QString &message)
{
    if (index < 0 || index >= m_items.size()) {
        return;
    }

    auto &item = m_items[index];
    item.hasVideo = hasVideo;
    item.hasAudio = hasAudio;
    item.videoCodec = videoCodec;
    item.audioCodec = audioCodec;
    item.alreadyCompatible = alreadyCompatible;
    if (!message.isEmpty()) {
        item.statusMessage = message;
    }

    emitDataChanged(index, {HasVideoRole, HasAudioRole, VideoCodecRole, AudioCodecRole, AlreadyCompatibleRole, MessageRole});
}

QString ConversionQueueModel::statusToLabel(ConversionItem::Status status)
{
    switch (status) {
    case ConversionItem::Status::Pending:
        return QStringLiteral("Pendente");
    case ConversionItem::Status::Converting:
        return QStringLiteral("Convertendo");
    case ConversionItem::Status::Completed:
        return QStringLiteral("Concluido");
    case ConversionItem::Status::Warning:
        return QStringLiteral("Aviso");
    case ConversionItem::Status::Error:
        return QStringLiteral("Erro");
    case ConversionItem::Status::Skipped:
        return QStringLiteral("Ignorado");
    }

    return QStringLiteral("Desconhecido");
}

void ConversionQueueModel::emitDataChanged(int index, const QList<int> &roles)
{
    const QModelIndex modelIndex = createIndex(index, 0);
    emit dataChanged(modelIndex, modelIndex, roles);
}
