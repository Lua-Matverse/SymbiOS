#!/usr/bin/env bash
# scripts/verification/verify-consolidation.sh
#
# Performs a comprehensive verification of the MatVerse monorepo consolidation.

set -euo pipefail

log() {
  local emoji="$1"
  shift
  printf '%s %s\n' "$emoji" "$*"
}

log "🔍" "Verificando integridade da consolidação..."
printf '=============================================%s\n' ""

ROOT_DIR=$(pwd)

# Ensure we are running from the repository root.
if [[ ! -f "package.json" ]]; then
  log "⚠️" "package.json não encontrado no diretório atual ($ROOT_DIR)."
  log "ℹ️" "Execute este script a partir da raiz do monorepo consolidado."
  exit 1
fi

log "📁" "Verificando estrutura de diretórios..."
required_dirs=(
  "apps/explore"
  "apps/symbios"
  "apps/cog-ui"
  "packages/core"
  "packages/lakehouse"
  "packages/lakehouse/ingest"
  "packages/lakehouse/transform"
  "packages/cognitive"
  "packages/security"
  "infra"
  "scripts"
  "docs"
)

missing_dirs=()
for dir in "${required_dirs[@]}"; do
  if [[ ! -d "$dir" ]]; then
    missing_dirs+=("$dir")
  fi
done

if ((${#missing_dirs[@]})); then
  log "❌" "Diretórios faltando:" && printf ' - %s\n' "${missing_dirs[@]}"
  exit 1
fi

log "✅" "Estrutura de diretórios encontrada."

log "📄" "Verificando arquivos essenciais..."
required_files=(
  "package.json"
  "infra/docker-compose.yml"
  "README.md"
  "apps/explore/package.json"
  "apps/symbios/go.mod"
  "packages/lakehouse/ingest/go.mod"
  "packages/lakehouse/transform/go.mod"
)

missing_files=()
for file in "${required_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    missing_files+=("$file")
  fi
done

if ((${#missing_files[@]})); then
  log "❌" "Arquivos essenciais faltando:" && printf ' - %s\n' "${missing_files[@]}"
  exit 1
fi

log "✅" "Arquivos essenciais presentes."

log "📦" "Verificando dependências..."
dependencies=(node go docker)
missing_bins=()
for dep in "${dependencies[@]}"; do
  if ! command -v "$dep" >/dev/null 2>&1; then
    missing_bins+=("$dep")
  fi
done

if ((${#missing_bins[@]})); then
  log "❌" "Dependências ausentes:" && printf ' - %s\n' "${missing_bins[@]}"
  exit 1
fi

log "✅" "Dependências básicas instaladas."

compose_cmd="docker-compose"
if ! command -v docker-compose >/dev/null 2>&1; then
  if docker compose version >/dev/null 2>&1; then
    compose_cmd="docker compose"
  else
    log "❌" "docker-compose não encontrado."
    exit 1
  fi
fi

run_or_skip() {
  local description="$1"
  shift
  local cmd=("$@")
  log "⏳" "$description"
  if "${cmd[@]}"; then
    log "✅" "$description concluído."
  else
    log "❌" "Falha em: $description"
    exit 1
  fi
}

log "🏗️" "Testando builds..."
if [[ -d apps/explore ]]; then
  (
    cd apps/explore
    run_or_skip "Build do MatVerse Explore" bash -lc "npm install --silent && npm run build --silent"
  )
fi

if [[ -d apps/symbios ]]; then
  (cd apps/symbios && run_or_skip "Build do SymbiOS" go build -o /tmp/symbios main.go)
fi

if [[ -d packages/lakehouse/ingest ]]; then
  (cd packages/lakehouse/ingest && run_or_skip "Build lakehouse ingest" go build -o /tmp/ingest .)
fi

if [[ -d packages/lakehouse/transform ]]; then
  (cd packages/lakehouse/transform && run_or_skip "Build lakehouse transform" go build -o /tmp/transform .)
fi

log "🐳" "Verificando configuração Docker..."
$compose_cmd -f infra/docker-compose.yml config --quiet
log "✅" "Configuração Docker válida."

log "✅" "Verificação concluída com sucesso!"
log "🎉" "O monorepo está pronto para uso!"

