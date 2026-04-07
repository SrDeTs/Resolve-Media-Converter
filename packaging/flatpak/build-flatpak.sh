#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MANIFEST="${PROJECT_ROOT}/packaging/flatpak/io.github.srdets.ResolveMediaConverter.yml"
BUILD_DIR="${PROJECT_ROOT}/dist/flatpak-build"
REPO_DIR="${PROJECT_ROOT}/dist/flatpak-repo"
BUNDLE_PATH="${PROJECT_ROOT}/dist/ResolveMediaConverter.flatpak"
APP_ID="io.github.srdets.ResolveMediaConverter"
WORK_ROOT="/tmp/resolve-media-converter-flatpak"
SOURCE_COPY="${WORK_ROOT}/source"
MANIFEST_COPY="${WORK_ROOT}/io.github.srdets.ResolveMediaConverter.yml"

if ! command -v flatpak-builder >/dev/null 2>&1; then
  echo "Erro: flatpak-builder nao esta instalado." >&2
  echo "Instale com o gerenciador da sua distro e rode novamente." >&2
  exit 1
fi

if ! command -v flatpak >/dev/null 2>&1; then
  echo "Erro: flatpak nao esta instalado." >&2
  exit 1
fi

mkdir -p "${PROJECT_ROOT}/dist"
rm -rf "${BUILD_DIR}" "${REPO_DIR}" "${BUNDLE_PATH}" "${WORK_ROOT}"
mkdir -p "${SOURCE_COPY}"

if command -v rsync >/dev/null 2>&1; then
  rsync -a \
    --exclude ".git" \
    --exclude "build" \
    --exclude "dist" \
    --exclude ".flatpak-builder" \
    "${PROJECT_ROOT}/" "${SOURCE_COPY}/"
else
  cp -a "${PROJECT_ROOT}/." "${SOURCE_COPY}/"
  rm -rf "${SOURCE_COPY}/.git" "${SOURCE_COPY}/build" "${SOURCE_COPY}/dist" "${SOURCE_COPY}/.flatpak-builder"
fi

sed "s#path: ../../#path: ${SOURCE_COPY}#" "${MANIFEST}" > "${MANIFEST_COPY}"

echo "Gerando build Flatpak"
flatpak-builder --force-clean "${BUILD_DIR}" "${MANIFEST_COPY}"

echo "Exportando repositorio Flatpak"
flatpak-builder --repo="${REPO_DIR}" --force-clean "${BUILD_DIR}" "${MANIFEST_COPY}"

echo "Gerando bundle Flatpak"
flatpak build-bundle "${REPO_DIR}" "${BUNDLE_PATH}" "${APP_ID}"

cat <<EOF

Flatpak concluido.

Arquivos gerados:
  ${BUNDLE_PATH}
  ${REPO_DIR}
EOF
