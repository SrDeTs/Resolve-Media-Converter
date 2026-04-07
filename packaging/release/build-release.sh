#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERSION="$(sed -n 's/^project(ResolveMediaConverter VERSION \([^ ]*\).*/\1/p' "${PROJECT_ROOT}/CMakeLists.txt")"
APPIMAGE_RUNTIME="${PROJECT_ROOT}/packaging/appimage/runtime/runtime-x86_64"
QML_SOURCE_DIR="${PROJECT_ROOT}/qml"
WORK_ROOT="/tmp/resolve-media-converter-release"
SOURCE_COPY="${WORK_ROOT}/source"
BUILD_DIR="${WORK_ROOT}/build"
APPDIR="${WORK_ROOT}/AppDir"
ARCH_DIR="${WORK_ROOT}/arch"
DIST_DIR="${PROJECT_ROOT}/dist"
APPIMAGE_ICON="${PROJECT_ROOT}/packaging/linux/io.github.srdets.ResolveMediaConverter.png"

echo "Preparando workspace temporario em ${WORK_ROOT}"
rm -rf "${WORK_ROOT}"
mkdir -p "${SOURCE_COPY}" "${DIST_DIR}" "${ARCH_DIR}"

if command -v rsync >/dev/null 2>&1; then
  rsync -a \
    --exclude ".git" \
    --exclude "build" \
    --exclude "dist" \
    "${PROJECT_ROOT}/" "${SOURCE_COPY}/"
else
  cp -a "${PROJECT_ROOT}/." "${SOURCE_COPY}/"
  rm -rf "${SOURCE_COPY}/.git" "${SOURCE_COPY}/build" "${SOURCE_COPY}/dist"
fi

echo "Configurando build Release"
cmake -S "${SOURCE_COPY}" -B "${BUILD_DIR}" -DCMAKE_BUILD_TYPE=Release

echo "Compilando"
cmake --build "${BUILD_DIR}"

echo "Limpando dist"
rm -f "${DIST_DIR}/"*.deb "${DIST_DIR}/"*.rpm "${DIST_DIR}/"*.AppImage
rm -rf "${DIST_DIR}/AppDir"

echo "Gerando pacote DEB"
(cd "${BUILD_DIR}" && cpack -G DEB)
find "${BUILD_DIR}" -maxdepth 1 -name '*.deb' -exec cp -f {} "${DIST_DIR}/" \;

echo "Gerando pacote RPM"
if (cd "${BUILD_DIR}" && cpack -G RPM); then
  find "${BUILD_DIR}" -maxdepth 1 -name '*.rpm' -exec cp -f {} "${DIST_DIR}/" \;
else
  echo "Aviso: falha ao gerar RPM neste ambiente; seguindo com os demais artefatos." >&2
fi

echo "Preparando AppDir"
rm -rf "${APPDIR}"
cmake --install "${BUILD_DIR}" --prefix "${APPDIR}/usr"
cp -a "${APPDIR}" "${DIST_DIR}/AppDir"

echo "Gerando pacote Arch"
ARCH_TARBALL="${ARCH_DIR}/resolve-media-converter-${VERSION}.tar.gz"
ARCH_SOURCE_DIR="${WORK_ROOT}/resolve-media-converter-${VERSION}"
cp "${PROJECT_ROOT}/packaging/arch/PKGBUILD" "${ARCH_DIR}/PKGBUILD"
sed -i "s/^pkgver=.*/pkgver=${VERSION}/" "${ARCH_DIR}/PKGBUILD"
rm -rf "${ARCH_SOURCE_DIR}"
cp -a "${SOURCE_COPY}" "${ARCH_SOURCE_DIR}"
tar -C "${WORK_ROOT}" -czf "${ARCH_TARBALL}" "resolve-media-converter-${VERSION}"
(cd "${ARCH_DIR}" && makepkg -f --nodeps)
find "${ARCH_DIR}" -maxdepth 1 -name '*.pkg.tar.*' -exec cp -f {} "${DIST_DIR}/" \;

echo "Tentando gerar AppImage"
if command -v linuxdeploy >/dev/null 2>&1 && command -v linuxdeploy-plugin-qt >/dev/null 2>&1; then
  EXTRA_PLATFORM_PLUGINS_VALUE=""
  if [[ -f /usr/lib/qt6/plugins/platforms/libqwayland.so ]]; then
    EXTRA_PLATFORM_PLUGINS_VALUE="libqwayland.so"
  fi

  if [[ -f "${APPIMAGE_RUNTIME}" ]]; then
    (
      cd "${DIST_DIR}" && \
      APPIMAGE_EXTRACT_AND_RUN=1 NO_STRIP=1 QMAKE=/usr/bin/qmake6 \
      QML_SOURCES_PATHS="${QML_SOURCE_DIR}" \
      EXTRA_PLATFORM_PLUGINS="${EXTRA_PLATFORM_PLUGINS_VALUE}" \
      LDAI_RUNTIME_FILE="${APPIMAGE_RUNTIME}" \
      linuxdeploy \
        --appdir "${DIST_DIR}/AppDir" \
        --desktop-file "${PROJECT_ROOT}/packaging/linux/io.github.srdets.ResolveMediaConverter.desktop" \
        --icon-file "${APPIMAGE_ICON}" \
        --plugin qt \
        --output appimage
    )
  else
    (
      cd "${DIST_DIR}" && \
      APPIMAGE_EXTRACT_AND_RUN=1 NO_STRIP=1 QMAKE=/usr/bin/qmake6 \
      QML_SOURCES_PATHS="${QML_SOURCE_DIR}" \
      EXTRA_PLATFORM_PLUGINS="${EXTRA_PLATFORM_PLUGINS_VALUE}" \
      linuxdeploy \
        --appdir "${DIST_DIR}/AppDir" \
        --desktop-file "${PROJECT_ROOT}/packaging/linux/io.github.srdets.ResolveMediaConverter.desktop" \
        --icon-file "${APPIMAGE_ICON}" \
        --plugin qt \
        --output appimage
    )
  fi
  find "${DIST_DIR}" -maxdepth 1 -name '*.AppImage' -print >/dev/null
else
  echo "Aviso: AppImage nao foi gerado automaticamente. Falta linuxdeploy-plugin-qt no ambiente." >&2
fi

cat <<EOF

Release concluido.

Arquivos gerados em:
  ${DIST_DIR}
EOF
