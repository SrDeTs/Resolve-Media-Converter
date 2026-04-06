#pragma once

#include "ConversionItem.h"

#include <QAbstractListModel>
#include <QSet>
#include <QStringList>
#include <QVector>

class ConversionQueueModel : public QAbstractListModel
{
    Q_OBJECT

public:
    enum Roles {
        FileNameRole = Qt::UserRole + 1,
        SourcePathRole,
        OutputPathRole,
        LocationHintRole,
        StatusRole,
        StatusLabelRole,
        MessageRole,
        ProgressRole,
        AudioCodecRole,
        VideoCodecRole,
        HasAudioRole,
        HasVideoRole,
        AlreadyCompatibleRole
    };
    Q_ENUM(Roles)

    explicit ConversionQueueModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool containsSource(const QString &path) const;
    int addFile(const QString &path);
    void clear();

    int count() const;
    int pendingCount() const;
    int completedCount() const;
    int nextPendingIndex() const;

    ConversionItem itemAt(int index) const;
    QStringList sourcePaths() const;

    void setOutputPath(int index, const QString &outputPath);
    void setProcessingState(int index, ConversionItem::Status status, const QString &message);
    void setProgress(int index, int progress, const QString &message = QString());
    void setProbeInfo(int index,
                      bool hasVideo,
                      bool hasAudio,
                      const QString &videoCodec,
                      const QString &audioCodec,
                      bool alreadyCompatible,
                      const QString &message);

private:
    static QString statusToLabel(ConversionItem::Status status);
    void emitDataChanged(int index, const QList<int> &roles);

    QVector<ConversionItem> m_items;
    QSet<QString> m_sources;
};
