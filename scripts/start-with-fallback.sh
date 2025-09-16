#!/usr/bin/env bash
# scripts/start-with-fallback.sh
#
# Starts the MatVerse environment with retry/fallback logic.

set -euo pipefail

MAX_RETRIES=${MAX_RETRIES:-3}
RETRY_DELAY=${RETRY_DELAY:-5}

log() {
  local emoji="$1"
  shift
  printf '%s %s\n' "$emoji" "$*"
}

repo_root=$(pwd)
log_dir="$repo_root/logs/start-with-fallback"
mkdir -p "$log_dir"

background_pids=()

start_service() {
  local name="$1"
  shift
  local attempt=1
  while (( attempt <= MAX_RETRIES )); do
    if "$@"; then
      log "✅" "$name iniciado com sucesso"
      return 0
    fi
    ((attempt++))
    if (( attempt <= MAX_RETRIES )); then
      log "⚠️" "Tentativa $((attempt-1)) para $name falhou. Repetindo em ${RETRY_DELAY}s..."
      sleep "$RETRY_DELAY"
    fi
  done
  log "❌" "Falha ao iniciar $name após ${MAX_RETRIES} tentativas"
  return 1
}

start_background_service() {
  local name="$1"
  local dir="$2"
  shift 2
  local attempt=1
  local sanitized
  sanitized=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-')
  local log_file="$log_dir/${sanitized:-service}.log"

  while (( attempt <= MAX_RETRIES )); do
    if [[ ! -d "$dir" ]]; then
      log "❌" "Diretório ${dir} ausente para $name"
      return 1
    fi

    local pid
    if ! pid=$(cd "$dir" && nohup "$@" >>"$log_file" 2>&1 & echo $!); then
      log "⚠️" "Não foi possível iniciar $name"
      pid=""
    fi
    sleep 3
    if [[ -n "$pid" ]] && ps -p "$pid" >/dev/null 2>&1; then
      background_pids+=("$name:$pid:$log_file")
      log "✅" "$name iniciado (PID $pid, log em $log_file)"
      return 0
    fi

    log "⚠️" "Tentativa $attempt para $name falhou. Verifique $log_file"
    ((attempt++))
    if (( attempt <= MAX_RETRIES )); then
      sleep "$RETRY_DELAY"
    fi
  done
  log "❌" "Falha ao iniciar $name após ${MAX_RETRIES} tentativas"
  return 1
}

log "🚀" "Inicialização com Fallback"
printf '=============================\n'

compose_cmd="docker-compose"
if ! command -v docker-compose >/dev/null 2>&1; then
  if docker compose version >/dev/null 2>&1; then
    compose_cmd="docker compose"
  else
    compose_cmd=""
  fi
fi

if [[ -n "$compose_cmd" && -f infra/docker-compose.yml ]]; then
  start_service "Docker Compose" $compose_cmd -f infra/docker-compose.yml up -d
else
  log "⚠️" "docker-compose indisponível ou infra/docker-compose.yml ausente. Pulando inicialização de containers."
fi

start_background_service "Explore Frontend" "apps/explore" npm start || true
start_background_service "SymbiOS Backend" "apps/symbios" go run main.go serve || true

log "⏳" "Aguardando inicialização completa..."
sleep 10

if [[ -x scripts/troubleshooting/diagnose-fix.sh ]]; then
  log "🔍" "Executando diagnóstico final..."
  scripts/troubleshooting/diagnose-fix.sh || log "⚠️" "Diagnóstico reportou problemas"
else
  log "⚠️" "scripts/troubleshooting/diagnose-fix.sh não encontrado ou sem permissão de execução"
fi

if ((${#background_pids[@]})); then
  printf '\nServiços em execução:\n'
  for entry in "${background_pids[@]}"; do
    IFS=':' read -r name pid logfile <<<"$entry"
    printf ' - %s (PID %s, log: %s)\n' "$name" "$pid" "$logfile"
  done
fi

log "🎉" "Ambiente MatVerse inicializado com resiliência!"
