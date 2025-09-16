#!/usr/bin/env bash
# scripts/quick-check.sh
#
# Runs a lightweight readiness check for the MatVerse environment.

set -euo pipefail

log() {
  local emoji="$1"
  shift
  printf '%s %s\n' "$emoji" "$*"
}

quick_check() {
  local message="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    log "✅" "$message"
  else
    log "❌" "$message"
  fi
}

log "🎯" "Verificação Rápida do Ambiente"
printf '================================\n'

printf '🔍 Verificações básicas:\n'
quick_check "Node.js disponível" command -v node
quick_check "npm disponível" command -v npm
quick_check "Go disponível" command -v go
quick_check "Docker disponível" command -v docker
quick_check "Docker Compose disponível" bash -c 'command -v docker-compose >/dev/null 2>&1 || docker compose version >/dev/null 2>&1'
quick_check "Diretório raiz correto" test -f package.json
quick_check "Arquivo .env existe" test -f .env
if command -v docker >/dev/null 2>&1; then
  quick_check "Docker rodando" docker info
else
  log "⚠️" "Docker não instalado"
fi
printf '\n'

printf '📦 Verificações de dependências:\n'
quick_check "Dependências Node instaladas" test -d node_modules
if [[ -d apps/symbios ]]; then
  quick_check "Dependências Go instaladas" test -d apps/symbios/vendor
else
  log "⚠️" "apps/symbios não encontrado"
fi
printf '\n'

printf '🌐 Verificações de rede:\n'
if command -v nc >/dev/null 2>&1; then
  quick_check "Porta 3000 livre" bash -c '! nc -z localhost 3000 >/dev/null 2>&1'
  quick_check "Porta 8080 livre" bash -c '! nc -z localhost 8080 >/dev/null 2>&1'
else
  log "⚠️" "Ferramenta nc indisponível. Pulando checagem de portas."
fi
if command -v ping >/dev/null 2>&1; then
  quick_check "Conexão com internet" ping -c 1 github.com
else
  log "⚠️" "ping indisponível."
fi
printf '\n'

log "✅" "Verificação rápida concluída!"
