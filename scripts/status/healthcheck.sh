#!/usr/bin/env bash
# scripts/status/healthcheck.sh
#
# Provides an overview of the MatVerse stack status.

set -euo pipefail

log() {
  local emoji="$1"
  shift
  printf '%s %s\n' "$emoji" "$*"
}

printf '📊 Status do Sistema MatVerse\n'
printf '==============================\n'
printf 'Data: %s\n\n' "$(date)"

compose_cmd="docker-compose"
if ! command -v docker-compose >/dev/null 2>&1; then
  if docker compose version >/dev/null 2>&1; then
    compose_cmd="docker compose"
  else
    compose_cmd=""
  fi
fi

if [[ -n "$compose_cmd" && -f infra/docker-compose.yml ]]; then
  printf '🔄 Serviços em execução:\n'
  $compose_cmd -f infra/docker-compose.yml ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
  printf '\n'
else
  printf '⚠️  docker-compose não está disponível ou infra/docker-compose.yml ausente.\n\n'
fi

printf '📈 Utilização de recursos:\n'
if command -v top >/dev/null 2>&1; then
  CPU=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')
else
  CPU="N/A"
fi
if command -v free >/dev/null 2>&1; then
  MEM=$(free -m | awk 'NR==2{printf "%.2f%%", $3*100/$2}')
else
  MEM="N/A"
fi
if df -h / >/dev/null 2>&1; then
  DISK=$(df -h / | awk 'NR==2{print $5}')
else
  DISK="N/A"
fi
printf 'CPU: %s\n' "$CPU"
printf 'Memória: %s\n' "$MEM"
printf 'Disco: %s\n\n' "$DISK"

printf '🌐 Status dos aplicativos:\n'
check_url() {
  local url="$1"
  if command -v curl >/dev/null 2>&1 && curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "200"; then
    printf '✅ %s\n' "$url"
  else
    printf '❌ %s\n' "$url"
  fi
}

check_url http://localhost:3000    # Explore
check_url http://localhost:8080    # SymbiOS
check_url http://localhost:9001    # MinIO Console
check_url http://localhost:9090    # Prometheus
check_url http://localhost:3001    # Grafana
printf '\n'

if [[ -n "$compose_cmd" ]]; then
  printf '📊 Métricas do Lakehouse:\n'
  if command -v docker >/dev/null 2>&1; then
    INGEST=$($compose_cmd exec redis redis-cli GET metrics:ingest:total 2>/dev/null || echo "N/A")
    INDEX_SIZE=$($compose_cmd exec trino trino --catalog iceberg --schema cog -e "SELECT COUNT(*) FROM silver_documents" 2>/dev/null | tail -1 || echo "N/A")
    printf 'Documentos ingestados: %s\n' "${INGEST:-N/A}"
    printf 'Tamanho do índice FAISS: %s\n' "${INDEX_SIZE:-N/A}"
  else
    printf '⚠️  Docker não disponível. Não foi possível coletar métricas.\n'
  fi
  printf '\n'
fi

printf '✅ Verificação de status concluída\n'

