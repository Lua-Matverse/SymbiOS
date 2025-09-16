#!/usr/bin/env bash
# scripts/verification/verify-deployment.sh
#
# Validates a MatVerse deployment running in Kubernetes.

set -euo pipefail

ENVIRONMENT=${1:-staging}

log() {
  local emoji="$1"
  shift
  printf '%s %s\n' "$emoji" "$*"
}

log "🔍" "Verificando deploy no ambiente $ENVIRONMENT..."
printf '============================================%s\n' ""

if ! command -v kubectl >/dev/null 2>&1; then
  log "❌" "kubectl não encontrado."
  exit 1
fi

NAMESPACE=${NAMESPACE:-"matverse-$ENVIRONMENT"}

log "📦" "Listando deployments no namespace $NAMESPACE..."
if ! kubectl get deployments -n "$NAMESPACE"; then
  log "❌" "Não foi possível listar deployments."
  exit 1
fi

log "🌐" "Verificando ingressos/serviços principais..."
SERVICES=(
  "symbios"
  "explore"
  "cog-ui"
)
for svc in "${SERVICES[@]}"; do
  if kubectl get service "$svc" -n "$NAMESPACE" >/dev/null 2>&1; then
    log "✅" "Serviço $svc disponível."
  else
    log "⚠️" "Serviço $svc não encontrado."
  fi
  if kubectl get ingress "$svc" -n "$NAMESPACE" >/dev/null 2>&1; then
    log "✅" "Ingress $svc disponível."
  else
    log "⚠️" "Ingress $svc não encontrado."
  fi

done

log "🩺" "Executando verificação de pods..."
if ! kubectl get pods -n "$NAMESPACE"; then
  log "❌" "Não foi possível listar pods."
  exit 1
fi

log "✅" "Verificação de deploy concluída."

