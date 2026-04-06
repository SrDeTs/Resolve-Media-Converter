#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")"

DEFAULT_REMOTE="origin"
DEFAULT_BRANCH="main"

say() {
  printf '%s\n' "$*"
}

die() {
  printf '❌ %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Comando não encontrado: $1"
}

require_cmd git

# Segurança: só roda dentro de um repositório Git já existente
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || \
  die "Esta pasta não é um repositório Git. Crie/configure o repo manualmente primeiro."

# Segurança: não troca branch, só verifica
current_branch="$(git branch --show-current 2>/dev/null || true)"
[ -n "$current_branch" ] || die "Não foi possível identificar a branch atual."

if [ "$current_branch" != "$DEFAULT_BRANCH" ]; then
  die "Você está na branch '$current_branch'. Troque manualmente para '$DEFAULT_BRANCH' se quiser enviar essa branch."
fi

# Segurança: não cria/altera remote automaticamente
git remote get-url "$DEFAULT_REMOTE" >/dev/null 2>&1 || \
  die "Remote '$DEFAULT_REMOTE' não configurado. Configure manualmente antes de usar o script."

# Segurança: não continua se houver merge/rebase em andamento
if [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ] || [ -f .git/MERGE_HEAD ]; then
  die "Há rebase/merge em andamento. Resolva manualmente antes de enviar."
fi

# Confere identidade
git config user.name >/dev/null 2>&1 || die "git user.name não configurado."
git config user.email >/dev/null 2>&1 || die "git user.email não configurado."

say "---"
say "Arquivos ignorados pelo .gitignore:"
git ls-files --others --ignored --exclude-standard || true
say "---"

say "Adicionando arquivos rastreáveis..."
git add -A

say "---"
say "Status dos arquivos preparados:"
git status --short
say "---"

if git diff --cached --quiet; then
  say "Nada novo para comitar."
  exit 0
fi

read -r -p "Mensagem do commit: " COMMIT_MSG
[ -n "${COMMIT_MSG:-}" ] || COMMIT_MSG="update: $(date +'%Y-%m-%d %H:%M:%S')"

git commit -m "$COMMIT_MSG"

say "Enviando para $DEFAULT_REMOTE/$DEFAULT_BRANCH..."
git push "$DEFAULT_REMOTE" "$DEFAULT_BRANCH"

say "✓ Push concluído com sucesso."
