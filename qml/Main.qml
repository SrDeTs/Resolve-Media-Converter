import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

ApplicationWindow {
    id: window
    width: 920
    height: 700
    minimumWidth: 820
    minimumHeight: 620
    visible: true
    title: "Resolve Media Converter"
    color: "#12161a"

    readonly property color bg: "#12161a"
    readonly property color panel: "#1a2025"
    readonly property color panelSoft: "#20272d"
    readonly property color stroke: "#2c363e"
    readonly property color textPrimary: "#eef3f6"
    readonly property color textMuted: "#93a1aa"
    readonly property color accent: "#79d062"
    readonly property color accentText: "#0c120a"
    readonly property color error: "#d96f68"
    readonly property color warning: "#d6b866"

    function addDroppedUrls(urls) {
        const paths = []
        for (let i = 0; i < urls.length; ++i) {
            const value = urls[i].toString()
            if (value.startsWith("file://")) {
                paths.push(decodeURIComponent(value.substring(7)))
            }
        }

        if (!paths.length) {
            return
        }

        if (conversionManager.selectionMode === 1 && paths.length === 1) {
            conversionManager.addFolder(paths[0], false)
        } else {
            conversionManager.addFiles(paths)
        }
    }

    function statusColor(label) {
        switch (label) {
        case "Concluido":
            return accent
        case "Convertendo":
            return "#8dbcf6"
        case "Erro":
            return error
        case "Aviso":
            return warning
        default:
            return textMuted
        }
    }

    FileDialog {
        id: fileDialog
        title: "Selecionar videos"
        fileMode: FileDialog.OpenFiles
        nameFilters: ["Videos (*.mp4 *.mkv *.mov *.webm *.avi)"]
        onAccepted: conversionManager.addFiles(selectedFiles.map(url => decodeURIComponent(url.toString().substring(7))))
    }

    FolderDialog {
        id: folderDialog
        title: "Selecionar pasta"
        onAccepted: conversionManager.addFolder(decodeURIComponent(selectedFolder.toString().substring(7)), false)
    }

    FolderDialog {
        id: outputFolderDialog
        title: "Selecionar pasta de saida"
        onAccepted: {
            conversionManager.outputDirectory = decodeURIComponent(selectedFolder.toString().substring(7))
            conversionManager.saveNextToSource = false
        }
    }

    DropArea {
        id: rootDropArea
        anchors.fill: parent
        onDropped: event => addDroppedUrls(event.urls)
    }

    ScrollView {
        anchors.fill: parent
        clip: true

        ColumnLayout {
            width: Math.max(window.width - 32, 820)
            spacing: 14
            anchors.margins: 16

            Rectangle {
                Layout.fillWidth: true
                radius: 18
                color: panel
                border.color: stroke
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 16

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Label {
                            text: "Resolve Media Converter"
                            color: textPrimary
                            font.pixelSize: 30
                            font.weight: Font.DemiBold
                        }

                        Label {
                            Layout.fillWidth: true
                            text: "Mantem o video intacto e converte somente o audio para FLAC."
                            color: textMuted
                            wrapMode: Text.Wrap
                        }
                    }

                    Rectangle {
                        radius: 14
                        color: panelSoft
                        border.color: stroke
                        implicitWidth: 84
                        implicitHeight: 68

                        Column {
                            anchors.centerIn: parent
                            spacing: 2

                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: conversionManager.totalItems
                                color: textPrimary
                                font.pixelSize: 22
                                font.weight: Font.DemiBold
                            }

                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "na fila"
                                color: textMuted
                            }
                        }
                    }

                    Rectangle {
                        radius: 14
                        color: panelSoft
                        border.color: stroke
                        implicitWidth: 96
                        implicitHeight: 68

                        Column {
                            anchors.centerIn: parent
                            spacing: 2

                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: conversionManager.completedItems
                                color: accent
                                font.pixelSize: 22
                                font.weight: Font.DemiBold
                            }

                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "concluidos"
                                color: textMuted
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                radius: 18
                color: panel
                border.color: rootDropArea.containsDrag ? accent : stroke
                border.width: rootDropArea.containsDrag ? 2 : 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Label {
                                text: "Entrada"
                                color: textPrimary
                                font.pixelSize: 20
                                font.weight: Font.DemiBold
                            }

                            Label {
                                Layout.fillWidth: true
                                text: conversionManager.selectionMode === 0
                                      ? "Adicione um ou mais videos. Tambem funciona com drag and drop."
                                      : "Selecione uma pasta para importar os videos suportados."
                                color: textMuted
                                wrapMode: Text.Wrap
                            }
                        }

                        Rectangle {
                            radius: 14
                            color: panelSoft
                            border.color: stroke
                            implicitWidth: 196
                            implicitHeight: 42

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 4
                                spacing: 4

                                Repeater {
                                    model: ["Arquivos", "Pasta"]

                                    delegate: Button {
                                        id: modeButton
                                        required property int index
                                        required property string modelData
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        text: modelData
                                        checkable: true
                                        checked: conversionManager.selectionMode === index
                                        onClicked: conversionManager.selectionMode = index

                                        background: Rectangle {
                                            radius: 10
                                            color: modeButton.checked ? accent : "transparent"
                                        }

                                        contentItem: Text {
                                            text: modeButton.text
                                            color: modeButton.checked ? accentText : textMuted
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            font.pixelSize: 14
                                            font.weight: Font.Medium
                                        }
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Button {
                            id: selectButton
                            text: conversionManager.selectionMode === 0 ? "Selecionar arquivos" : "Selecionar pasta"
                            onClicked: {
                                if (conversionManager.selectionMode === 0) {
                                    fileDialog.open()
                                } else {
                                    folderDialog.open()
                                }
                            }

                            background: Rectangle {
                                radius: 12
                                color: accent
                            }

                            contentItem: Text {
                                text: selectButton.text
                                color: accentText
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }
                        }

                        Button {
                            id: clearButton
                            text: "Limpar fila"
                            enabled: !conversionManager.running
                            onClicked: conversionManager.clearQueue()

                            background: Rectangle {
                                radius: 12
                                color: clearButton.enabled ? panelSoft : "#1a1f24"
                                border.color: stroke
                                border.width: 1
                            }

                            contentItem: Text {
                                text: clearButton.text
                                color: clearButton.enabled ? textPrimary : "#68757d"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                font.pixelSize: 14
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        CheckBox {
                            id: saveNextToSource
                            checked: conversionManager.saveNextToSource
                            onToggled: conversionManager.saveNextToSource = checked

                            indicator: Rectangle {
                                implicitWidth: 18
                                implicitHeight: 18
                                radius: 4
                                border.color: checked ? accent : stroke
                                border.width: 1
                                color: checked ? accent : panelSoft

                                Label {
                                    anchors.centerIn: parent
                                    text: checked ? "✓" : ""
                                    color: accentText
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }
                            }

                            contentItem: Text {
                                text: "Salvar ao lado do original"
                                color: textPrimary
                                leftPadding: 28
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        Button {
                            id: outputButton
                            text: "Pasta de saida"
                            enabled: !conversionManager.saveNextToSource
                            onClicked: outputFolderDialog.open()

                            background: Rectangle {
                                radius: 12
                                color: outputButton.enabled ? panelSoft : "#1a1f24"
                                border.color: stroke
                                border.width: 1
                            }

                            contentItem: Text {
                                text: outputButton.text
                                color: outputButton.enabled ? textPrimary : "#68757d"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                font.pixelSize: 14
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 320
                radius: 18
                color: panel
                border.color: stroke
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Label {
                                text: "Fila"
                                color: textPrimary
                                font.pixelSize: 20
                                font.weight: Font.DemiBold
                            }

                            Label {
                                text: "O video e copiado sem reencodar. Apenas o audio vai para FLAC."
                                color: textMuted
                            }
                        }

                        CheckBox {
                            id: overwriteExisting
                            checked: conversionManager.overwriteExisting
                            onToggled: conversionManager.overwriteExisting = checked

                            indicator: Rectangle {
                                implicitWidth: 18
                                implicitHeight: 18
                                radius: 4
                                border.color: checked ? accent : stroke
                                border.width: 1
                                color: checked ? accent : panelSoft

                                Label {
                                    anchors.centerIn: parent
                                    text: checked ? "✓" : ""
                                    color: accentText
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }
                            }

                            contentItem: Text {
                                text: "Sobrescrever existentes"
                                color: textPrimary
                                leftPadding: 28
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }

                    ListView {
                        id: queueList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 10
                        model: conversionManager.queueModel

                        delegate: Rectangle {
                            required property string fileName
                            required property string sourcePath
                            required property string outputPath
                            required property string statusLabel
                            required property string message
                            required property int progress
                            required property string audioCodec
                            required property string videoCodec

                            width: queueList.width
                            height: 94
                            radius: 14
                            color: panelSoft
                            border.color: stroke
                            border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 6

                                RowLayout {
                                    Layout.fillWidth: true

                                    Label {
                                        text: fileName
                                        color: textPrimary
                                        font.pixelSize: 15
                                        font.weight: Font.Medium
                                        elide: Text.ElideMiddle
                                        Layout.fillWidth: true
                                    }

                                    Label {
                                        text: statusLabel
                                        color: statusColor(statusLabel)
                                        font.weight: Font.DemiBold
                                    }
                                }

                                Label {
                                    text: sourcePath
                                    color: textMuted
                                    elide: Text.ElideMiddle
                                    Layout.fillWidth: true
                                }

                                Label {
                                    text: (videoCodec || "?") + " video  •  " + (audioCodec || "?") + " audio"
                                    color: textMuted
                                    Layout.fillWidth: true
                                }

                                ProgressBar {
                                    id: itemProgress
                                    Layout.fillWidth: true
                                    from: 0
                                    to: 100
                                    value: progress

                                    background: Rectangle {
                                        radius: 6
                                        color: "#101418"
                                    }

                                    contentItem: Item {
                                        Rectangle {
                                            width: itemProgress.visualPosition * parent.width
                                            height: parent.height
                                            radius: 6
                                            color: accent
                                        }
                                    }
                                }

                                Label {
                                    text: message
                                    color: statusLabel === "Erro" ? error : textMuted
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            visible: queueList.count === 0
                            width: 320
                            height: 110
                            radius: 14
                            color: "#171d22"
                            border.color: stroke

                            Column {
                                anchors.centerIn: parent
                                spacing: 6

                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "Fila vazia"
                                    color: textPrimary
                                    font.pixelSize: 18
                                    font.weight: Font.DemiBold
                                }

                                Label {
                                    width: 240
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.Wrap
                                    text: "Adicione arquivos ou uma pasta para comecar."
                                    color: textMuted
                                }
                            }
                        }

                        ScrollBar.vertical: ScrollBar {
                            active: true
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                radius: 18
                color: panel
                border.color: stroke
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Label {
                                text: "Execucao"
                                color: textPrimary
                                font.pixelSize: 20
                                font.weight: Font.DemiBold
                            }

                            Label {
                                text: "Compatibilidade com Resolve no Linux, sem mexer no video."
                                color: textMuted
                            }
                        }

                        Button {
                            id: convertButton
                            text: conversionManager.running ? "Cancelar" : "Converter"
                            onClicked: {
                                if (conversionManager.running) {
                                    conversionManager.cancelCurrent()
                                } else {
                                    conversionManager.startConversion()
                                }
                            }

                            background: Rectangle {
                                radius: 12
                                color: conversionManager.running ? error : accent
                            }

                            contentItem: Text {
                                text: convertButton.text
                                color: conversionManager.running ? "white" : accentText
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                            }
                        }
                    }

                    ProgressBar {
                        id: overallProgress
                        Layout.fillWidth: true
                        from: 0
                        to: 1
                        value: conversionManager.overallProgress

                        background: Rectangle {
                            radius: 6
                            color: "#101418"
                        }

                        contentItem: Item {
                            Rectangle {
                                width: overallProgress.visualPosition * parent.width
                                height: parent.height
                                radius: 6
                                color: accent
                            }
                        }
                    }

                    Label {
                        text: Math.round(conversionManager.overallProgress * 100) + "% concluido"
                        color: textMuted
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 140
                        radius: 14
                        color: "#151a1e"
                        border.color: stroke
                        border.width: 1

                        ListView {
                            anchors.fill: parent
                            anchors.margins: 10
                            model: conversionManager.logModel
                            spacing: 6
                            clip: true

                            delegate: Label {
                                required property string message
                                width: ListView.view.width
                                text: message
                                color: textMuted
                                wrapMode: Text.Wrap
                            }

                            ScrollBar.vertical: ScrollBar {
                                active: true
                            }
                        }
                    }
                }
            }
        }
    }
}
