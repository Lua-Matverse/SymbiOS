#!/usr/bin/env bash
# scripts/quickstart.sh
#
# Bootstraps a local MatVerse environment quickly.

set -euo pipefail

log() {
  local emoji="$1"
  shift
  printf '%s %s\n' "$emoji" "$*"
}

log "🚀" "Inicialização Rápida MatVerse"
printf '================================%s\n' ""

if [[ ! -f package.json ]]; then
  log "❌" "package.json não encontrado. Execute este script na raiz do monorepo."
  exit 1
fi

log "🔍" "Verificando dependências..."
required_cmds=(node npm go docker)
missing_cmds=()
for cmd in "${required_cmds[@]}"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    missing_cmds+=("$cmd")
  fi
done

compose_cmd="docker-compose"
if ! command -v docker-compose >/dev/null 2>&1; then
  if docker compose version >/dev/null 2>&1; then
    compose_cmd="docker compose"
  else
    missing_cmds+=("docker-compose")
  fi
fi

if ((${#missing_cmds[@]})); then
  log "❌" "Dependências ausentes:" && printf ' - %s\n' "${missing_cmds[@]}"
  exit 1
fi

log "📦" "Instalando dependências..."
npm install

log "🐳" "Iniciando Docker Compose..."
$compose_cmd -f infra/docker-compose.yml up -d

log "⏳" "Aguardando inicialização dos serviços..."
sleep 30

log "🔍" "Executando verificações..."
npm run lakehouse:init

log "🏗️" "Construindo aplicativos..."
npm run build

log "🚀" "Iniciando serviços..."
npm run dev &
DEV_PID=$!

log "🎉" "MatVerse inicializado com sucesso!"
printf '🌐 URLs disponíveis:\n'
printf '   - Explore: http://localhost:3000\n'
printf '   - SymbiOS: http://localhost:8080\n'
printf '   - MinIO Console: http://localhost:9001\n'
printf '   - Grafana: http://localhost:3001\n\n'
printf '📊 Para verificar status: npm run status\n'
printf '🛑 Para interromper os serviços de desenvolvimento: kill %s\n' "$DEV_PID"

