# Packaging

## DEB / RPM

Use CPack from the build directory:

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build
cd build
cpack -G DEB
cpack -G RPM
```

Ou use o script de release:

```bash
./packaging/release/build-release.sh
```

Ele copia o projeto para um caminho temporario sem espacos, gera `.deb`, `.rpm`
e prepara `dist/AppDir` para AppImage.

## AppImage

Prepare an AppDir:

```bash
./packaging/appimage/build-appimage.sh
```

Then generate the AppImage with `linuxdeploy` plus the Qt plugin.

## Arch / pacman

Use the provided `packaging/arch/PKGBUILD` as a starting point.

## Flatpak

Requer:

```bash
flatpak
flatpak-builder
```

Build local e bundle `.flatpak`:

```bash
./packaging/flatpak/build-flatpak.sh
```

Ou manualmente:

```bash
flatpak-builder build-flatpak packaging/flatpak/io.github.srdets.ResolveMediaConverter.yml --force-clean
flatpak-builder --repo=repo-flatpak build-flatpak packaging/flatpak/io.github.srdets.ResolveMediaConverter.yml --force-clean
flatpak build-bundle repo-flatpak ResolveMediaConverter.flatpak io.github.srdets.ResolveMediaConverter
```
