# Resolve Media Converter

Utilitario Linux em Qt/QML para deixar videos mais compativeis com o DaVinci Resolve no Linux sem reencodar o video.

## O que o app fazs

- Mantem o stream de video intacto com `-c:v copy`
- Converte somente a primeira faixa de audio para FLAC
- Gera um novo arquivo `.mkv` com sufixo `_resolve.flacfix.mkv`
- Aceita fila por arquivos individuais ou por pasta

## Requisitos

- Qt 6.5+
- CMake 3.21+
- `ffmpeg`
- `ffprobe`

## Build

```bash
cmake -S . -B build
cmake --build build
```

## Estrutura

- `src/core`: backend C++ com fila, worker e modelos
- `qml`: interface QML compacta
- `CMakeLists.txt`: build principal
