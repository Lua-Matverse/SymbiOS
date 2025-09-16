#!/usr/bin/env bash
# scripts/test/connectivity-test.sh
#
# Validates external and internal connectivity required for MatVerse services.

set -euo pipefail

log() {
  local emoji="$1"
  shift
  printf '%s %s\n' "$emoji" "$*"
}

log "🧪" "Teste de Conectividade"
printf '========================\n'

check_external() {
  local host="$1"
  local label="$2"
  if ! command -v ping >/dev/null 2>&1; then
    log "⚠️" "ping indisponível. Não foi possível testar $label ($host)"
    return 1
  fi

  if ping -c 1 "$host" >/dev/null 2>&1; then
    log "✅" "$label: Conectado"
  else
    log "❌" "$label: Falha"
  fi
}

check_port() {
  local port="$1"
  local service="$2"
  if command -v nc >/dev/null 2>&1; then
    if nc -z localhost "$port" >/dev/null 2>&1; then
      log "✅" "$service: Rodando na porta $port"
    else
      log "❌" "$service: Não está rodando na porta $port"
    fi
  elif command -v ss >/dev/null 2>&1; then
    if ss -ltn | awk '{print $4}' | grep -qE ":${port}$"; then
      log "✅" "$service: Rodando na porta $port"
    else
      log "❌" "$service: Não está rodando na porta $port"
    fi
  else
    log "⚠️" "Ferramentas nc/ss indisponíveis. Não foi possível testar $service"
  fi
}

printf '🌐 Testando conexões externas...\n'
check_external github.com "GitHub"
check_external docker.com "Docker Hub"
check_external huggingface.co "Hugging Face"
printf '\n'

printf '🏠 Testando serviços locais...\n'
declare -A local_ports=(
  [3000]="Explore Frontend"
  [8080]="SymbiOS Backend"
  [9000]="MinIO"
  [9001]="MinIO Console"
  [8081]="Trino"
  [6379]="Redis"
  [9090]="Prometheus"
  [3001]="Grafana"
)
for port in "${!local_ports[@]}"; do
  check_port "$port" "${local_ports[$port]}"
done
printf '\n'

printf '🔧 Testando ferramentas...\n'
for tool in node go docker python3; do
  if command -v "$tool" >/dev/null 2>&1; then
    log "✅" "$tool: Instalado"
  else
    log "❌" "$tool: Faltando"
  fi
done

log "📊" "Teste de conectividade concluído!"
