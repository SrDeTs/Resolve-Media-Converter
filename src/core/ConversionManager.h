#pragma once

#include "ConversionQueueModel.h"
#include "ConversionWorker.h"
#include "LogModel.h"

#include <QObject>
#include <QThread>

class ConversionManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(ConversionQueueModel *queueModel READ queueModel CONSTANT)
    Q_PROPERTY(LogModel *logModel READ logModel CONSTANT)
    Q_PROPERTY(bool running READ running NOTIFY runningChanged)
    Q_PROPERTY(double overallProgress READ overallProgress NOTIFY overallProgressChanged)
    Q_PROPERTY(int totalItems READ totalItems NOTIFY queueStatsChanged)
    Q_PROPERTY(int completedItems READ completedItems NOTIFY queueStatsChanged)
    Q_PROPERTY(QString outputDirectory READ outputDirectory WRITE setOutputDirectory NOTIFY outputDirectoryChanged)
    Q_PROPERTY(bool saveNextToSource READ saveNextToSource WRITE setSaveNextToSource NOTIFY saveNextToSourceChanged)
    Q_PROPERTY(bool overwriteExisting READ overwriteExisting WRITE setOverwriteExisting NOTIFY overwriteExistingChanged)
    Q_PROPERTY(int selectionMode READ selectionMode WRITE setSelectionMode NOTIFY selectionModeChanged)

public:
    enum SelectionMode {
        FilesMode = 0,
        FolderMode = 1,
        AudioMode = 2
    };
    Q_ENUM(SelectionMode)

    explicit ConversionManager(QObject *parent = nullptr);
    ~ConversionManager() override;

    ConversionQueueModel *queueModel();
    LogModel *logModel();

    bool running() const;
    double overallProgress() const;
    int totalItems() const;
    int completedItems() const;

    QString outputDirectory() const;
    void setOutputDirectory(const QString &outputDirectory);

    bool saveNextToSource() const;
    void setSaveNextToSource(bool enabled);

    bool overwriteExisting() const;
    void setOverwriteExisting(bool enabled);

    bool verboseLogging() const;
    void setVerboseLogging(bool enabled);

    int selectionMode() const;
    void setSelectionMode(int mode);

    Q_INVOKABLE void addFiles(const QStringList &paths);
    Q_INVOKABLE void addFolder(const QString &folderPath, bool includeSubfolders = false);
    Q_INVOKABLE void clearQueue();
    Q_INVOKABLE void startConversion();
    Q_INVOKABLE void cancelCurrent();

signals:
    void runningChanged();
    void overallProgressChanged();
    void queueStatsChanged();
    void outputDirectoryChanged();
    void saveNextToSourceChanged();
    void overwriteExistingChanged();
    void selectionModeChanged();
    void convertJobRequested(const ConversionWorker::JobRequest &job);
    void cancelRequested();

private slots:
    void handleWorkerProgress(int index, int progress, const QString &message);
    void handleWorkerState(int index,
                           bool hasVideo,
                           bool hasAudio,
                           const QString &videoCodec,
                           const QString &audioCodec,
                           bool alreadyCompatible,
                           const QString &message);
    void handleWorkerFinished(int index, bool success, bool warning, const QString &message);

private:
    static bool isSupportedVideoFile(const QString &path);
    static bool isSupportedAudioFile(const QString &path);
    bool isSupportedInputFile(const QString &path) const;
    QString buildOutputPath(const QString &sourcePath) const;
    void log(const QString &message);
    void startNextPending();
    void updateStats();

    ConversionQueueModel m_queueModel;
    LogModel m_logModel;
    QThread m_workerThread;
    ConversionWorker *m_worker = nullptr;
    QString m_outputDirectory;
    bool m_running = false;
    bool m_saveNextToSource = true;
    bool m_overwriteExisting = false;
    bool m_verboseLogging = false;
    int m_selectionMode = FilesMode;
};
