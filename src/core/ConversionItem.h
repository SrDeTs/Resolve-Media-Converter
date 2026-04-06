#pragma once

#include <QString>

struct ConversionItem {
    enum class Status {
        Pending,
        Converting,
        Completed,
        Warning,
        Error,
        Skipped
    };

    QString sourcePath;
    QString outputPath;
    QString fileName;
    QString locationHint;
    QString statusMessage;
    QString audioCodec;
    QString videoCodec;
    int progress = 0;
    Status status = Status::Pending;
    bool hasAudio = false;
    bool hasVideo = false;
    bool alreadyCompatible = false;
};
