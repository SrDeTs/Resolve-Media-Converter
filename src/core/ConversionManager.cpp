#include "ConversionManager.h"

#include <QDir>
#include <QDirIterator>
#include <QFileInfo>
#include <QLoggingCategory>

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
}

bool ConversionManager::overwriteExisting() const
{
    return m_overwriteExisting;
}

void ConversionManager::setOverwriteExisting(bool enabled)
{
    if (m_overwriteExisting == enabled) {
        return;
    }

    m_overwriteExisting = enabled;
    emit overwriteExistingChanged();
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
        log(QStringLiteral("Pasta invalida: %1").arg(folderPath));
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
        log(QStringLiteral("Nenhum video suportado encontrado na pasta"));
        return;
    }

    addFiles(files);
}

void ConversionManager::clearQueue()
{
    if (m_running) {
        log(QStringLiteral("Nao e possivel limpar a fila durante a conversao"));
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
        log(QStringLiteral("Nenhum item pendente para converter"));
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
        m_queueModel.setProcessingState(index, cancelled ? ConversionItem::Status::Skipped : ConversionItem::Status::Error, message);
        log(QStringLiteral("%1 falhou: %2").arg(m_queueModel.itemAt(index).fileName, message));
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
    const QString outputName = (m_selectionMode == AudioMode || isSupportedAudioFile(sourcePath))
        ? QStringLiteral("%1_resolve.flac").arg(baseName)
        : QStringLiteral("%1_resolve.flacfix.mkv").arg(baseName);
    if (m_saveNextToSource || m_outputDirectory.isEmpty()) {
        return info.dir().filePath(outputName);
    }

    return QDir(m_outputDirectory).filePath(outputName);
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
    job.overwriteExisting = m_overwriteExisting;
    job.ffmpegPath = QStringLiteral("ffmpeg");
    job.ffprobePath = QStringLiteral("ffprobe");

    emit convertJobRequested(job);
}

void ConversionManager::updateStats()
{
    emit queueStatsChanged();
}
