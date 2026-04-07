#include "ConversionWorker.h"

#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QRegularExpression>
#include <QThread>

ConversionWorker::ConversionWorker(QObject *parent)
    : QObject(parent)
{
}

void ConversionWorker::process(const ConversionWorker::JobRequest &job)
{
    m_cancelRequested = false;
    emit logMessage(QStringLiteral("Analisando %1").arg(QFileInfo(job.sourcePath).fileName()));
    emit progressChanged(job.index, 0, QStringLiteral("Analisando arquivo"));

    const ProbeResult probe = runProbe(job);
    emit stateChanged(job.index,
                      probe.hasVideo,
                      probe.hasAudio,
                      probe.videoCodec,
                      probe.audioCodec,
                      probe.alreadyCompatible,
                      probe.ok
                          ? (probe.audioStreamCount > 1
                                 ? QStringLiteral("Analise concluida; multiplas faixas de audio detectadas")
                                 : QStringLiteral("Analise concluida"))
                          : probe.error);

    if (!probe.ok) {
        emit finished(job.index, false, false, probe.error);
        return;
    }

    if (!probe.hasAudio) {
        emit finished(job.index, false, false, QStringLiteral("Arquivo sem stream de audio"));
        return;
    }

    if (probe.audioStreamCount > 1) {
        emit logMessage(QStringLiteral("Aviso: %1 tem %2 faixas de audio; somente a primeira sera convertida")
                            .arg(QFileInfo(job.sourcePath).fileName())
                            .arg(probe.audioStreamCount));
    }

    QString errorMessage;
    const bool ok = runFfmpeg(job, probe, &errorMessage);
    if (!ok) {
        emit finished(job.index, false, false, errorMessage);
        return;
    }

    const bool warning = probe.alreadyCompatible || probe.audioStreamCount > 1;
    const QString resultMessage = probe.hasVideo
        ? (probe.audioStreamCount > 1
               ? QStringLiteral("Multiplas faixas de audio detectadas; somente a primeira foi convertida")
               : (probe.alreadyCompatible ? QStringLiteral("Audio ja estava em FLAC; arquivo final remuxado")
                                          : QStringLiteral("Video copiado e audio convertido para FLAC")))
        : (probe.audioStreamCount > 1
               ? QStringLiteral("Multiplas faixas de audio detectadas; somente a primeira foi convertida")
               : (probe.alreadyCompatible ? QStringLiteral("Audio ja estava em FLAC; arquivo final gerado sem reencodar")
                                          : QStringLiteral("Audio convertido para FLAC")));
    emit finished(job.index, true, warning, resultMessage);
}

void ConversionWorker::cancelCurrent()
{
    m_cancelRequested = true;
}

ConversionWorker::ProbeResult ConversionWorker::runProbe(const JobRequest &job) const
{
    ProbeResult result;

    QProcess probe;
    QStringList arguments{
        QStringLiteral("-v"),
        QStringLiteral("error"),
        QStringLiteral("-print_format"),
        QStringLiteral("json"),
        QStringLiteral("-show_streams"),
        QStringLiteral("-show_format"),
        job.sourcePath
    };

    startProcess(probe, job.ffprobePath, arguments, job.useHostTools);
    if (!probe.waitForStarted()) {
        result.error = QStringLiteral("Nao foi possivel iniciar ffprobe");
        return result;
    }

    probe.waitForFinished(-1);
    if (probe.exitStatus() != QProcess::NormalExit || probe.exitCode() != 0) {
        result.error = QString::fromUtf8(probe.readAllStandardError()).trimmed();
        if (result.error.isEmpty()) {
            result.error = QStringLiteral("ffprobe falhou ao analisar o arquivo");
        }
        return result;
    }

    const auto document = QJsonDocument::fromJson(probe.readAllStandardOutput());
    if (!document.isObject()) {
        result.error = QStringLiteral("Resposta invalida do ffprobe");
        return result;
    }

    const QJsonObject root = document.object();
    const QJsonArray streams = root.value(QStringLiteral("streams")).toArray();
    for (const QJsonValue &value : streams) {
        const QJsonObject stream = value.toObject();
        const QString codecType = stream.value(QStringLiteral("codec_type")).toString();
        const QString codecName = stream.value(QStringLiteral("codec_name")).toString();

        if (codecType == QStringLiteral("video") && !result.hasVideo) {
            result.hasVideo = true;
            result.videoCodec = codecName;
        } else if (codecType == QStringLiteral("audio")) {
            ++result.audioStreamCount;
            if (!result.hasAudio) {
                result.hasAudio = true;
                result.audioCodec = codecName;
            }
        }
    }

    const QJsonObject format = root.value(QStringLiteral("format")).toObject();
    const double durationSeconds = format.value(QStringLiteral("duration")).toString().toDouble();
    result.durationMs = static_cast<qint64>(durationSeconds * 1000.0);
    result.alreadyCompatible = result.audioCodec.compare(QStringLiteral("flac"), Qt::CaseInsensitive) == 0;
    result.ok = true;
    return result;
}

bool ConversionWorker::runFfmpeg(const JobRequest &job, const ProbeResult &probe, QString *errorMessage)
{
    QProcess ffmpeg;
    ffmpeg.setProcessChannelMode(QProcess::SeparateChannels);

    QStringList arguments{
        QStringLiteral("-hide_banner"),
        QStringLiteral("-nostats"),
        QStringLiteral("-progress"),
        QStringLiteral("pipe:2")
    };

    arguments << (job.overwriteExisting ? QStringLiteral("-y") : QStringLiteral("-n"));
    arguments << QStringLiteral("-i") << job.sourcePath;
    arguments << QStringLiteral("-map") << QStringLiteral("0:a:0");
    arguments << QStringLiteral("-map_metadata") << QStringLiteral("0");
    arguments << QStringLiteral("-c:a") << QStringLiteral("flac");

    if (probe.hasVideo) {
        arguments << QStringLiteral("-map") << QStringLiteral("0:v");
        arguments << QStringLiteral("-map") << QStringLiteral("0:s?");
        arguments << QStringLiteral("-c:v") << QStringLiteral("copy");
        arguments << QStringLiteral("-c:s") << QStringLiteral("copy");
    }

    arguments << job.outputPath;

    if (probe.alreadyCompatible) {
        emit logMessage(QStringLiteral("Audio ja esta em FLAC; mantendo a faixa sem nova conversao"));
        arguments.removeAll(QStringLiteral("flac"));
        const int audioCodecIndex = arguments.indexOf(QStringLiteral("-c:a"));
        if (audioCodecIndex >= 0 && audioCodecIndex + 1 < arguments.size()) {
            arguments[audioCodecIndex + 1] = QStringLiteral("copy");
        }
    } else {
        emit logMessage(probe.hasVideo
                            ? QStringLiteral("Convertendo audio para FLAC e copiando video sem reencodar")
                            : QStringLiteral("Convertendo audio solo para FLAC"));
    }

    startProcess(ffmpeg, job.ffmpegPath, arguments, job.useHostTools);
    if (!ffmpeg.waitForStarted()) {
        *errorMessage = QStringLiteral("Nao foi possivel iniciar ffmpeg");
        return false;
    }

    QByteArray buffer;
    while (ffmpeg.state() != QProcess::NotRunning) {
        if (m_cancelRequested) {
            ffmpeg.kill();
            ffmpeg.waitForFinished();
            *errorMessage = QStringLiteral("Conversao cancelada");
            return false;
        }

        if (!ffmpeg.waitForReadyRead(150)) {
            continue;
        }

        buffer += ffmpeg.readAllStandardError();
        int lineBreak = buffer.indexOf('\n');
        while (lineBreak >= 0) {
            const QByteArray rawLine = buffer.left(lineBreak);
            buffer.remove(0, lineBreak + 1);
            const QString line = QString::fromUtf8(rawLine).trimmed();
            if (line.startsWith(QStringLiteral("out_time_ms="))) {
                const int progress = progressFromLine(line, probe.durationMs);
                emit progressChanged(job.index, progress, QStringLiteral("Convertendo audio"));
            } else if (line == QStringLiteral("progress=end")) {
                emit progressChanged(job.index, 100, QStringLiteral("Finalizando arquivo"));
            }
            lineBreak = buffer.indexOf('\n');
        }
    }

    ffmpeg.waitForFinished();
    if (ffmpeg.exitStatus() != QProcess::NormalExit || ffmpeg.exitCode() != 0) {
        const QString stdErr = QString::fromUtf8(ffmpeg.readAllStandardError()).trimmed();
        *errorMessage = stdErr.isEmpty() ? QStringLiteral("ffmpeg falhou durante a conversao") : stdErr;
        return false;
    }

    emit logMessage(QStringLiteral("Arquivo finalizado: %1").arg(QFileInfo(job.outputPath).fileName()));
    return true;
}

void ConversionWorker::startProcess(QProcess &process,
                                    const QString &program,
                                    const QStringList &arguments,
                                    bool useHostTools)
{
    if (useHostTools) {
        QStringList hostArguments{QStringLiteral("--host"), program};
        hostArguments.append(arguments);
        process.start(QStringLiteral("flatpak-spawn"), hostArguments);
        return;
    }

    process.start(program, arguments);
}

int ConversionWorker::progressFromLine(const QString &line, qint64 durationMs) const
{
    if (durationMs <= 0) {
        return 0;
    }

    const qint64 outTimeMicroseconds = line.mid(QStringLiteral("out_time_ms=").size()).toLongLong();
    const qint64 processedMs = outTimeMicroseconds / 1000;
    return static_cast<int>((processedMs * 100) / durationMs);
}
