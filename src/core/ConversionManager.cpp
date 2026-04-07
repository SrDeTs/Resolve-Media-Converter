#include "ConversionManager.h"

#include <QDir>
#include <QDirIterator>
#include <QFileInfo>
#include <QLoggingCategory>
#include <QStringView>

ConversionManager::ConversionManager(QObject *parent)
    : QObject(parent)
{
    qRegisterMetaType<ConversionWorker::JobRequest>();

    m_worker = new ConversionWorker();
    m_worker->moveToThread(&m_workerThread);

    connect(&m_workerThread, &QThread::finished, m_worker, &QObject::deleteLater);
    connect(this, &ConversionManager::convertJobRequested, m_worker, &ConversionWorker::process, Qt::QueuedConnection);
    connect(this, &ConversionManager::cancelRequested, m_worker, &ConversionWorker::cancelCurrent, Qt::QueuedConnection);
    connect(m_worker, &ConversionWorker::progressChanged, this, &ConversionManager::handleWorkerProgress);
    connect(m_worker,
            &ConversionWorker::stateChanged,
            this,
            &ConversionManager::handleWorkerState);
    connect(m_worker, &ConversionWorker::finished, this, &ConversionManager::handleWorkerFinished);
    connect(m_worker, &ConversionWorker::logMessage, this, [this](const QString &message) {
        log(message);
    });

    m_workerThread.start();
}

ConversionManager::~ConversionManager()
{
    emit cancelRequested();
    m_workerThread.quit();
    m_workerThread.wait();
}

ConversionQueueModel *ConversionManager::queueModel()
{
    return &m_queueModel;
}

LogModel *ConversionManager::logModel()
{
    return &m_logModel;
}

bool ConversionManager::running() const
{
    return m_running;
}

double ConversionManager::overallProgress() const
{
    if (m_queueModel.count() == 0) {
        return 0.0;
    }

    qint64 total = 0;
    for (int i = 0; i < m_queueModel.count(); ++i) {
        total += m_queueModel.itemAt(i).progress;
    }
    return static_cast<double>(total) / static_cast<double>(m_queueModel.count() * 100);
}

int ConversionManager::totalItems() const
{
    return m_queueModel.count();
}

int ConversionManager::completedItems() const
{
    return m_queueModel.completedCount();
}

QString ConversionManager::outputDirectory() const
{
    return m_outputDirectory;
}

void ConversionManager::setOutputDirectory(const QString &outputDirectory)
{
    if (m_outputDirectory == outputDirectory) {
        return;
    }

    m_outputDirectory = outputDirectory;
    emit outputDirectoryChanged();
    refreshOutputPaths();
}

bool ConversionManager::saveNextToSource() const
{
    return m_saveNextToSource;
}

void ConversionManager::setSaveNextToSource(bool enabled)
{
    if (m_saveNextToSource == enabled) {
        return;
    }

    m_saveNextToSource = enabled;
    emit saveNextToSourceChanged();
    refreshOutputPaths();
}

bool ConversionManager::removeOutputSuffix() const
{
    return m_removeOutputSuffix;
}

void ConversionManager::setRemoveOutputSuffix(bool enabled)
{
    if (m_removeOutputSuffix == enabled) {
        return;
    }

    m_removeOutputSuffix = enabled;
    emit removeOutputSuffixChanged();
    refreshOutputPaths();
}

bool ConversionManager::verboseLogging() const
{
    return m_verboseLogging;
}

void ConversionManager::setVerboseLogging(bool enabled)
{
    m_verboseLogging = enabled;
}

int ConversionManager::selectionMode() const
{
    return m_selectionMode;
}

void ConversionManager::setSelectionMode(int mode)
{
    if (m_selectionMode == mode) {
        return;
    }

    m_selectionMode = mode;
    emit selectionModeChanged();
}

void ConversionManager::addFiles(const QStringList &paths)
{
    int added = 0;
    for (const QString &path : paths) {
        if (!isSupportedInputFile(path)) {
            log(QStringLiteral("Ignorado por formato nao suportado: %1").arg(path));
            continue;
        }

        const int index = m_queueModel.addFile(path);
        if (index < 0) {
            log(QStringLiteral("Arquivo ja esta na fila: %1").arg(path));
            continue;
        }

        m_queueModel.setOutputPath(index, buildOutputPath(path));
        ++added;
    }

    if (added > 0) {
        log(QStringLiteral("%1 arquivo(s) adicionado(s) a fila").arg(added));
        updateStats();
    }
}

void ConversionManager::addFolder(const QString &folderPath, bool includeSubfolders)
{
    const QFileInfo info(folderPath);
    if (!info.exists() || !info.isDir()) {
        reportError(QStringLiteral("Pasta invalida: %1").arg(folderPath));
        return;
    }

    QStringList files;
    const auto iteratorFlags = includeSubfolders ? QDirIterator::Subdirectories : QDirIterator::NoIteratorFlags;
    QDirIterator it(folderPath, QDir::Files, iteratorFlags);
    while (it.hasNext()) {
        const QString path = it.next();
        if (isSupportedVideoFile(path)) {
            files.push_back(path);
        }
    }

    if (files.isEmpty()) {
        reportError(QStringLiteral("Nenhum video suportado encontrado na pasta"));
        return;
    }

    addFiles(files);
}

void ConversionManager::clearQueue()
{
    if (m_running) {
        reportError(QStringLiteral("Nao e possivel limpar a fila durante a conversao"));
        return;
    }

    m_queueModel.clear();
    m_logModel.clear();
    updateStats();
}

void ConversionManager::startConversion()
{
    if (m_running) {
        return;
    }

    if (m_queueModel.pendingCount() == 0) {
        reportError(QStringLiteral("Nenhum item pendente para converter"));
        return;
    }

    m_running = true;
    emit runningChanged();
    log(QStringLiteral("Conversao iniciada"));
    startNextPending();
}

void ConversionManager::cancelCurrent()
{
    if (!m_running) {
        return;
    }

    log(QStringLiteral("Cancelamento solicitado"));
    emit cancelRequested();
}

void ConversionManager::handleWorkerProgress(int index, int progress, const QString &message)
{
    m_queueModel.setProgress(index, progress, message);
    emit overallProgressChanged();
}

void ConversionManager::handleWorkerState(int index,
                                          bool hasVideo,
                                          bool hasAudio,
                                          const QString &videoCodec,
                                          const QString &audioCodec,
                                          bool alreadyCompatible,
                                          const QString &message)
{
    m_queueModel.setProbeInfo(index, hasVideo, hasAudio, videoCodec, audioCodec, alreadyCompatible, message);
}

void ConversionManager::handleWorkerFinished(int index, bool success, bool warning, const QString &message)
{
    if (success) {
        const auto status = warning ? ConversionItem::Status::Warning : ConversionItem::Status::Completed;
        m_queueModel.setProcessingState(index, status, message);
        log(QStringLiteral("%1 concluido").arg(m_queueModel.itemAt(index).fileName));
    } else {
        const bool cancelled = message.contains(QStringLiteral("cancelada"), Qt::CaseInsensitive);
        const QString queueMessage = cancelled
            ? message
            : summarizeError(message);
        m_queueModel.setProcessingState(index,
                                        cancelled ? ConversionItem::Status::Skipped : ConversionItem::Status::Error,
                                        queueMessage);
        log(QStringLiteral("%1 falhou: %2").arg(m_queueModel.itemAt(index).fileName, message));
        if (!cancelled) {
            reportError(message);
        }
    }

    updateStats();
    emit overallProgressChanged();
    startNextPending();
}

bool ConversionManager::isSupportedVideoFile(const QString &path)
{
    const QString suffix = QFileInfo(path).suffix().toLower();
    static const QSet<QString> supported{
        QStringLiteral("mp4"),
        QStringLiteral("mkv"),
        QStringLiteral("mov"),
        QStringLiteral("webm"),
        QStringLiteral("avi")
    };
    return supported.contains(suffix);
}

bool ConversionManager::isSupportedAudioFile(const QString &path)
{
    const QString suffix = QFileInfo(path).suffix().toLower();
    static const QSet<QString> supported{
        QStringLiteral("wav"),
        QStringLiteral("mp3"),
        QStringLiteral("aac"),
        QStringLiteral("m4a"),
        QStringLiteral("flac"),
        QStringLiteral("opus"),
        QStringLiteral("ogg"),
        QStringLiteral("aif"),
        QStringLiteral("aiff")
    };
    return supported.contains(suffix);
}

QString ConversionManager::summarizeError(const QString &message)
{
    const QStringList lines = message.split('\n', Qt::SkipEmptyParts);
    for (const QString &line : lines) {
        const QString trimmed = line.trimmed();
        if (trimmed.isEmpty()) {
            continue;
        }

        QString summary = trimmed;
        if (summary.size() > 110) {
            summary = summary.left(107) + QStringLiteral("...");
        }
        return summary;
    }

    return QStringLiteral("Falha na conversao. Veja os detalhes no popup.");
}

bool ConversionManager::isSupportedInputFile(const QString &path) const
{
    if (m_selectionMode == AudioMode) {
        return isSupportedAudioFile(path);
    }

    return isSupportedVideoFile(path);
}

QString ConversionManager::buildOutputPath(const QString &sourcePath) const
{
    const QFileInfo info(sourcePath);
    const QString baseName = info.completeBaseName();
    const bool audioOnly = m_selectionMode == AudioMode || isSupportedAudioFile(sourcePath);
    const QString preferredOutputName = audioOnly
        ? (m_removeOutputSuffix
               ? QStringLiteral("%1.flac").arg(baseName)
               : QStringLiteral("%1_resolve.flac").arg(baseName))
        : (m_removeOutputSuffix
               ? QStringLiteral("%1.mkv").arg(baseName)
               : QStringLiteral("%1_resolve.flacfix.mkv").arg(baseName));

    const QDir targetDir = (m_saveNextToSource || m_outputDirectory.isEmpty())
        ? info.dir()
        : QDir(m_outputDirectory);
    QString outputPath = targetDir.filePath(preferredOutputName);

    const QString normalizedSource = info.absoluteFilePath();
    const QString normalizedOutput = QFileInfo(outputPath).absoluteFilePath();
    if (normalizedOutput == normalizedSource) {
        const QString fallbackName = audioOnly
            ? QStringLiteral("%1_resolve.flac").arg(baseName)
            : QStringLiteral("%1_resolve.flacfix.mkv").arg(baseName);
        outputPath = targetDir.filePath(fallbackName);
    }

    return outputPath;
}

void ConversionManager::refreshOutputPaths()
{
    for (int i = 0; i < m_queueModel.count(); ++i) {
        const auto item = m_queueModel.itemAt(i);
        if (item.status == ConversionItem::Status::Converting) {
            continue;
        }

        m_queueModel.setOutputPath(i, buildOutputPath(item.sourcePath));
    }
}

void ConversionManager::reportError(const QString &message)
{
    log(message);
    emit errorOccurred(message);
}

void ConversionManager::log(const QString &message)
{
    m_logModel.append(message);
    if (m_verboseLogging) {
        qInfo().noquote() << message;
    }
}

void ConversionManager::startNextPending()
{
    const int index = m_queueModel.nextPendingIndex();
    if (index < 0) {
        m_running = false;
        emit runningChanged();
        log(QStringLiteral("Fila finalizada"));
        return;
    }

    auto item = m_queueModel.itemAt(index);
    const QString outputPath = buildOutputPath(item.sourcePath);
    m_queueModel.setOutputPath(index, outputPath);
    m_queueModel.setProcessingState(index, ConversionItem::Status::Converting, QStringLiteral("Preparando ffmpeg"));
    emit overallProgressChanged();

    ConversionWorker::JobRequest job;
    job.index = index;
    job.sourcePath = item.sourcePath;
    job.outputPath = outputPath;
    job.overwriteExisting = false;
    job.ffmpegPath = QStringLiteral("ffmpeg");
    job.ffprobePath = QStringLiteral("ffprobe");

    emit convertJobRequested(job);
}

void ConversionManager::updateStats()
{
    emit queueStatsChanged();
}
