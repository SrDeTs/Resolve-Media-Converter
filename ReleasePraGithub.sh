#!/usr/bin/env bash
set -euo pipefail

# Garante que o script roda na raiz do projeto
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PASTA_PACOTES="pacotes"

echo "====================================="
echo "   🚀 Gerador de Releases (GitHub)   "
echo "====================================="
echo ""

# Usa somente a pasta local de artefatos consolidada
if [ ! -d "$PASTA_PACOTES" ]; then
    echo "❌ Erro: a pasta '$PASTA_PACOTES' não existe."
    echo "Rode './build.sh' para gerar e mover os artefatos para '$PASTA_PACOTES'."
    exit 1
fi

echo "📁 Pasta de artefatos: $PASTA_PACOTES"

# Verifica se o GitHub CLI (gh) está instalado
if ! command -v gh >/dev/null 2>&1; then
    echo "⚠️  O executável 'gh' (GitHub CLI) não foi encontrado no sistema."
    echo "Para fazer lançamentos pelo terminal, você precisa instalá-lo."
    echo ""
    echo "Se estiver no Arch Linux, instale com:"
    echo "  sudo pacman -S github-cli"
    echo ""
    echo "Após instalar, faça login uma vez rodando:"
    echo "  gh auth login"
    exit 1
fi

# Verifica autenticação do GitHub CLI
if ! gh auth status >/dev/null 2>&1; then
    echo "❌ Você não está autenticado no GitHub CLI."
    echo "Execute: gh auth login"
    exit 1
fi

# Extrai a versão real do package.json
if ! command -v jq >/dev/null 2>&1; then
    # Fallback se não tiver jq (usa grep/sed)
    APP_VERSION=$(grep '"version":' package.json | head -1 | cut -d'"' -f4)
else
    APP_VERSION=$(jq -r .version package.json)
fi

if [ -z "$APP_VERSION" ]; then
    echo "❌ Erro: Não foi possível obter a versão de package.json"
    exit 1
fi

TAG_NAME="v$APP_VERSION"
RELEASE_TITLE="NebulaRec $TAG_NAME"

echo ""
echo "Gerando Release '$TAG_NAME' automaticamente baseada na configuração atual..."
echo ""

# Prepara os comandos adicionais detectando o Changelog Local
CHANGELOG_FILE=""
if [ -f "atualizações.md" ]; then
    CHANGELOG_FILE="atualizações.md"
elif [ -f "atualizacoes.md" ]; then
    CHANGELOG_FILE="atualizacoes.md"
fi

OPCOES_EXTRA=()
if [ -n "$CHANGELOG_FILE" ]; then
    echo "📝 Arquivo '$CHANGELOG_FILE' detectado. Injetando Notas de Lançamento embutidas..."
    OPCOES_EXTRA=(--notes-file "$CHANGELOG_FILE")
else
    echo "⚠️  Não foi encontrado 'atualizacoes.md'. Gerando notas vazias pelo Git..."
    OPCOES_EXTRA=(--generate-notes) # Tenta gerar notas automáticas de commits
fi

# Coleta somente artefatos de release válidos
shopt -s nullglob
ARTIFACTS=(
    "$PASTA_PACOTES"/*.deb
    "$PASTA_PACOTES"/*.AppImage
    "$PASTA_PACOTES"/*.pacman
    "$PASTA_PACOTES"/*.rpm
    "$PASTA_PACOTES"/*.zip
    "$PASTA_PACOTES"/*.exe
    "$PASTA_PACOTES"/*.msi
    "$PASTA_PACOTES"/*.dmg
)

shopt -u nullglob

if [ ${#ARTIFACTS[@]} -eq 0 ]; then
    echo "❌ Erro: nenhum artefato encontrado em '$PASTA_PACOTES'."
    echo "Esperado: .deb, .AppImage, .pacman, .rpm, .zip, .exe, .msi, .dmg"
    exit 1
fi

# Evita falhar com tag já existente
if gh release view "$TAG_NAME" >/dev/null 2>&1; then
    echo "❌ A release '$TAG_NAME' já existe no GitHub."
    echo "Use outra versão no package.json ou remova a release/tag existente."
    exit 1
fi

# Executa o comando do gh criando a release e enviando os instaladores
gh release create "$TAG_NAME" "${ARTIFACTS[@]}" --title "$RELEASE_TITLE" "${OPCOES_EXTRA[@]}"

echo ""
echo "✅ Release '$TAG_NAME' criada com sucesso e arquivos enviados!"
echo "Você pode conferi-la agora na aba 'Releases' do seu repositório GitHub."
