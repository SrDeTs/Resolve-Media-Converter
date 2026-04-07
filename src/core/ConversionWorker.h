#pragma once

#include <QObject>
#include <QStringList>

class ConversionWorker : public QObject
{
    Q_OBJECT

public:
    struct JobRequest {
        int index = -1;
        QString sourcePath;
        QString outputPath;
        bool overwriteExisting = false;
        QString ffmpegPath;
        QString ffprobePath;
    };

    explicit ConversionWorker(QObject *parent = nullptr);

public slots:
    void process(const ConversionWorker::JobRequest &job);
    void cancelCurrent();

signals:
    void progressChanged(int index, int progress, const QString &message);
    void stateChanged(int index,
                      bool hasVideo,
                      bool hasAudio,
                      const QString &videoCodec,
                      const QString &audioCodec,
                      bool alreadyCompatible,
                      const QString &message);
    void logMessage(const QString &message);
    void finished(int index, bool success, bool warning, const QString &message);

private:
    struct ProbeResult {
        bool ok = false;
        bool hasVideo = false;
        bool hasAudio = false;
        bool alreadyCompatible = false;
        int audioStreamCount = 0;
        QString videoCodec;
        QString audioCodec;
        QString error;
        qint64 durationMs = 0;
    };

    ProbeResult runProbe(const JobRequest &job) const;
    bool runFfmpeg(const JobRequest &job, const ProbeResult &probe, QString *errorMessage);
    int progressFromLine(const QString &line, qint64 durationMs) const;

    bool m_cancelRequested = false;
};

Q_DECLARE_METATYPE(ConversionWorker::JobRequest)
