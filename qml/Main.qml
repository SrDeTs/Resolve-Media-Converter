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
    readonly property color borderColor: "#2b353d"
    readonly property color textPrimary: "#eef3f6"
    readonly property color textMuted: "#95a3ac"
    readonly property color accent: "#7ad261"
    readonly property color accentText: "#0b1209"
    readonly property color error: "#da726a"
    readonly property color warning: "#d8ba6b"
    readonly property int controlHeight: 38
    property string currentErrorMessage: ""

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
            return "#88b8f1"
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
        title: conversionManager.selectionMode === 2 ? "Selecionar audios" : "Selecionar videos"
        fileMode: FileDialog.OpenFiles
        nameFilters: conversionManager.selectionMode === 2
                     ? ["Audios (*.wav *.mp3 *.aac *.m4a *.flac *.opus *.ogg *.aif *.aiff)"]
                     : ["Videos (*.mp4 *.mkv *.mov *.webm *.avi)"]
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
        anchors.fill: parent
        onDropped: event => addDroppedUrls(event.urls)
    }

    Connections {
        target: conversionManager

        function onErrorOccurred(message) {
            currentErrorMessage = message
            errorDialog.open()
        }
    }

    Dialog {
        id: errorDialog
        width: Math.min(window.width - 48, 620)
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape
        anchors.centerIn: Overlay.overlay
        padding: 0

        background: Rectangle {
            radius: 16
            color: panel
            border.color: borderColor
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 68
                color: "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    spacing: 12

                    Rectangle {
                        width: 34
                        height: 34
                        radius: 10
                        color: Qt.rgba(error.r, error.g, error.b, 0.16)
                        border.color: Qt.rgba(error.r, error.g, error.b, 0.4)

                        Label {
                            anchors.centerIn: parent
                            text: "!"
                            color: error
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Label {
                            text: "Erro"
                            color: textPrimary
                            font.pixelSize: 20
                            font.weight: Font.DemiBold
                        }

                        Label {
                            text: "O aplicativo encontrou um problema."
                            color: textMuted
                            font.pixelSize: 13
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: borderColor
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 188
                color: "transparent"

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 18
                    clip: true

                    TextArea {
                        id: errorTextArea
                        text: currentErrorMessage
                        wrapMode: Text.WrapAnywhere
                        readOnly: true
                        selectByMouse: true
                        color: textPrimary
                        selectionColor: accent
                        selectedTextColor: accentText
                        background: Rectangle {
                            radius: 12
                            color: panelSoft
                            border.color: borderColor
                            border.width: 1
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: borderColor
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 76
                color: "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    spacing: 10

                    Item {
                        Layout.fillWidth: true
                    }

                    Button {
                        text: "Copiar"
                        implicitHeight: controlHeight
                        onClicked: clipboardHelper.copyText(currentErrorMessage)

                        background: Rectangle {
                            radius: 10
                            color: panelSoft
                            border.color: borderColor
                            border.width: 1
                        }

                        contentItem: Text {
                            text: parent.text
                            color: textPrimary
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }
                    }

                    Button {
                        text: "OK"
                        implicitHeight: controlHeight
                        onClicked: errorDialog.close()

                        background: Rectangle {
                            radius: 10
                            color: accent
                        }

                        contentItem: Text {
                            text: parent.text
                            color: accentText
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 14

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 92
            radius: 16
            color: panel
            border.color: borderColor
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 16

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Rectangle {
                        Layout.preferredWidth: 56
                        Layout.preferredHeight: 56
                        radius: 12
                        color: panelSoft
                        border.color: borderColor

                        Image {
                            anchors.fill: parent
                            anchors.margins: 8
                            source: "qrc:/qt/qml/ResolveMediaConverter/Logo.png"
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Label {
                            text: "Resolve Media Converter"
                            color: textPrimary
                            font.pixelSize: 28
                            font.weight: Font.DemiBold
                        }

                        Label {
                            Layout.fillWidth: true
                            text: "Mantem o video intacto e converte somente o audio para FLAC."
                            color: textMuted
                            wrapMode: Text.Wrap
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 88
                    Layout.preferredHeight: 56
                    radius: 12
                    color: panelSoft
                    border.color: borderColor

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: conversionManager.totalItems
                            color: textPrimary
                            font.pixelSize: 20
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
                    Layout.preferredWidth: 104
                    Layout.preferredHeight: 56
                    radius: 12
                    color: panelSoft
                    border.color: borderColor

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: conversionManager.completedItems
                            color: accent
                            font.pixelSize: 20
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
            Layout.preferredHeight: 150
            radius: 16
            color: panel
            border.color: borderColor
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true

                    Label {
                        text: "Entrada"
                        color: textPrimary
                        font.pixelSize: 20
                        font.weight: Font.DemiBold
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        radius: 12
                        color: panelSoft
                        border.color: borderColor
                        implicitWidth: 286
                        implicitHeight: 40

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 4
                            spacing: 4

                            Repeater {
                                model: ["Arquivos", "Pasta", "Audio Solo"]

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
                                        radius: 9
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

                Label {
                    Layout.fillWidth: true
                    text: conversionManager.selectionMode === 0
                          ? "Adicione um ou mais videos. Tambem funciona com drag and drop."
                          : conversionManager.selectionMode === 1
                            ? "Selecione uma pasta para importar os videos suportados."
                            : "Adicione arquivos de audio para converter direto para FLAC."
                    color: textMuted
                    wrapMode: Text.Wrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                    Button {
                        id: selectButton
                        text: conversionManager.selectionMode === 1 ? "Selecionar pasta" : "Selecionar arquivos"
                        implicitHeight: controlHeight
                        onClicked: {
                            if (conversionManager.selectionMode === 1) {
                                folderDialog.open()
                            } else {
                                fileDialog.open()
                            }
                        }

                            background: Rectangle {
                                radius: 10
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
                            implicitHeight: controlHeight
                            onClicked: conversionManager.clearQueue()

                            background: Rectangle {
                                radius: 10
                                color: clearButton.enabled ? panelSoft : "#1a1f24"
                                border.color: borderColor
                                border.width: 1
                            }

                            contentItem: Text {
                                text: clearButton.text
                                color: clearButton.enabled ? textPrimary : "#67747c"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                font.pixelSize: 14
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }
                    }

                    RowLayout {
                        spacing: 10
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                        CheckBox {
                            id: removeSuffixToggle
                            implicitHeight: controlHeight
                            checked: conversionManager.removeOutputSuffix
                            spacing: 10
                            onToggled: conversionManager.removeOutputSuffix = checked

                            indicator: Rectangle {
                                x: 0
                                y: (removeSuffixToggle.height - height) / 2
                                implicitWidth: 18
                                implicitHeight: 18
                                radius: 4
                                border.color: removeSuffixToggle.checked ? accent : borderColor
                                border.width: 1
                                color: removeSuffixToggle.checked ? accent : panelSoft

                                Label {
                                    anchors.centerIn: parent
                                    text: removeSuffixToggle.checked ? "✓" : ""
                                    color: accentText
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }
                            }

                            contentItem: Label {
                                text: "Remover sufixo de saida"
                                color: textPrimary
                                font.pixelSize: 14
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: removeSuffixToggle.indicator.width + removeSuffixToggle.spacing
                            }
                        }

                        CheckBox {
                            id: saveNextToSourceToggle
                            implicitHeight: controlHeight
                            checked: conversionManager.saveNextToSource
                            spacing: 10
                            onToggled: conversionManager.saveNextToSource = checked

                            indicator: Rectangle {
                                x: 0
                                y: (saveNextToSourceToggle.height - height) / 2
                                implicitWidth: 18
                                implicitHeight: 18
                                radius: 4
                                border.color: saveNextToSourceToggle.checked ? accent : borderColor
                                border.width: 1
                                color: saveNextToSourceToggle.checked ? accent : panelSoft

                                Label {
                                    anchors.centerIn: parent
                                    text: saveNextToSourceToggle.checked ? "✓" : ""
                                    color: accentText
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }
                            }

                            contentItem: Label {
                                text: "Salvar ao lado do original"
                                color: textPrimary
                                font.pixelSize: 14
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: saveNextToSourceToggle.indicator.width + saveNextToSourceToggle.spacing
                            }
                        }

                        Button {
                            id: outputButton
                            text: "Pasta de saida"
                            enabled: !conversionManager.saveNextToSource
                            implicitHeight: controlHeight
                            onClicked: outputFolderDialog.open()

                            background: Rectangle {
                                radius: 10
                                color: outputButton.enabled ? panelSoft : "#1a1f24"
                                border.color: borderColor
                                border.width: 1
                            }

                            contentItem: Text {
                                text: outputButton.text
                                color: outputButton.enabled ? textPrimary : "#67747c"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                font.pixelSize: 14
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 16
            color: panel
            border.color: borderColor
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

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

                    Item {
                        Layout.fillWidth: true
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
                        required property string statusLabel
                        required property string message
                        required property int progress
                        required property string audioCodec
                        required property string videoCodec

                        width: queueList.width
                        height: 94
                        radius: 12
                        color: panelSoft
                        border.color: borderColor
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
                                    color: "#0f1316"
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
                                text: statusLabel === "Erro" ? "" : message
                                color: textMuted
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                visible: text.length > 0
                            }
                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        visible: queueList.count === 0
                        width: 280
                        height: 96
                        radius: 12
                        color: panelSoft
                        border.color: borderColor

                        Column {
                            anchors.centerIn: parent
                            spacing: 4

                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Fila vazia"
                                color: textPrimary
                                font.pixelSize: 18
                                font.weight: Font.DemiBold
                            }

                            Label {
                                width: 220
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
            Layout.preferredHeight: 170
            radius: 16
            color: panel
            border.color: borderColor
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

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

                    Item {
                        Layout.fillWidth: true
                    }

                    Button {
                        id: convertButton
                        text: conversionManager.running ? "Cancelar" : "Converter"
                        implicitHeight: controlHeight
                        implicitWidth: 120
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        onClicked: {
                            if (conversionManager.running) {
                                conversionManager.cancelCurrent()
                            } else {
                                conversionManager.startConversion()
                            }
                        }

                        background: Rectangle {
                            radius: 10
                            color: conversionManager.running ? error : accent
                        }

                        contentItem: Text {
                            text: convertButton.text
                            color: conversionManager.running ? "white" : accentText
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 14
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
                        color: "#0f1316"
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

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12
                    color: "#151a1e"
                    border.color: borderColor
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
