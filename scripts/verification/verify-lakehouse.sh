#!/usr/bin/env bash
# scripts/verification/verify-lakehouse.sh
#
# Validates the health of the local Lakehouse stack used by MatVerse.

set -euo pipefail

log() {
  local emoji="$1"
  shift
  printf '%s %s\n' "$emoji" "$*"
}

log "🔍" "Verificando ambiente Lakehouse..."
printf '====================================%s\n' ""

compose_cmd="docker-compose"
if ! command -v docker-compose >/dev/null 2>&1; then
  if docker compose version >/dev/null 2>&1; then
    compose_cmd="docker compose"
  else
    log "❌" "docker-compose não encontrado. Instale docker compose plugin ou docker-compose."
    exit 1
  fi
fi

if [[ ! -f infra/docker-compose.yml ]]; then
  log "❌" "Arquivo infra/docker-compose.yml não encontrado."
  exit 1
fi

log "🐳" "Verificando se Docker Compose está rodando..."
if ! $compose_cmd -f infra/docker-compose.yml ps >/dev/null 2>&1 || \
   ! $compose_cmd -f infra/docker-compose.yml ps | grep -q "Up"; then
  log "⚠️" "Docker Compose não está rodando. Iniciando serviços..."
  $compose_cmd -f infra/docker-compose.yml up -d
  sleep 30
fi

if ! command -v curl >/dev/null 2>&1; then
  log "❌" "curl não encontrado. Necessário para verificações HTTP."
  exit 1
fi

log "🪣" "Testando conexão com MinIO..."
if curl -s http://localhost:9000/minio/health/live | grep -q "OK"; then
  log "✅" "MinIO conectado"
else
  log "❌" "Falha na conexão com MinIO"
  exit 1
fi

log "🐦" "Testando conexão com Trino..."
if curl -s http://localhost:8080/v1/info | grep -q "starting"; then
  log "✅" "Trino conectado"
else
  log "❌" "Falha na conexão com Trino"
  exit 1
fi

log "📊" "Testando consultas no Trino..."
QUERY_RESULT=$($compose_cmd -f infra/docker-compose.yml exec trino \
  trino --catalog iceberg --schema cog -e "SHOW TABLES" 2>/dev/null || true)

if grep -q "Table" <<<"$QUERY_RESULT"; then
  log "✅" "Consultas Trino funcionando"
else
  log "⚠️" "Nenhuma tabela encontrada."
  if [[ -x ./scripts/init-database.sh ]]; then
    log "ℹ️" "Inicializando banco via scripts/init-database.sh"
    ./scripts/init-database.sh
  else
    log "ℹ️" "Script scripts/init-database.sh não encontrado. Pule esta etapa manualmente."
  fi
fi

log "🧠" "Testando conexão com Redis..."
REDIS_PING=$($compose_cmd -f infra/docker-compose.yml exec redis redis-cli PING 2>/dev/null || true)
if [[ "$REDIS_PING" == "PONG" ]]; then
  log "✅" "Redis conectado"
else
  log "❌" "Falha na conexão com Redis"
  exit 1
fi

log "⚙️" "Testando serviços Go..."
if [[ -d packages/lakehouse/ingest ]]; then
  (cd packages/lakehouse/ingest && go test -v ./...)
fi
if [[ -d packages/lakehouse/transform ]]; then
  (cd packages/lakehouse/transform && go test -v ./...)
fi

log "✅" "Ambiente Lakehouse verificado com sucesso!"

