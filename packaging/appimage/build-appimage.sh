#!/usr/bin/env bash
set -euo pipefail

APPDIR="${PWD}/AppDir"
BUILD_DIR="${PWD}/build-appimage"

cmake -S . -B "${BUILD_DIR}" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
cmake --build "${BUILD_DIR}"
rm -rf "${APPDIR}"
cmake --install "${BUILD_DIR}" --prefix "${APPDIR}/usr"

echo "Use linuxdeploy e o plugin Qt para gerar o AppImage:"
echo "linuxdeploy --appdir ${APPDIR} \\"
echo "  --desktop-file packaging/linux/io.github.srdets.ResolveMediaConverter.desktop \\"
echo "  --icon-file Logo.png \\"
echo "  --output appimage"
