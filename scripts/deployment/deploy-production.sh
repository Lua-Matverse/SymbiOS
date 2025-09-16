#!/usr/bin/env bash
# scripts/deployment/deploy-production.sh
#
# Builds and deploys the MatVerse monorepo to the desired environment.

set -euo pipefail

log() {
  local emoji="$1"
  shift
  printf '%s %s\n' "$emoji" "$*"
}

log "🚀" "Iniciando deploy de produção..."
printf '===================================%s\n' ""

ENVIRONMENT=${1:-staging}
REGISTRY=${REGISTRY:-"ghcr.io/xmatverse"}
TAG=${TAG:-}

if [[ -z "$TAG" ]]; then
  if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    TAG=$(git rev-parse --short HEAD)
  else
    TAG=$(date +%Y%m%d%H%M%S)
  fi
fi

log "🔖" "Deploying version: $TAG to: $ENVIRONMENT"

if [[ ! -f "package.json" ]]; then
  log "❌" "Execute este script a partir do diretório raiz do monorepo"
  exit 1
fi

required_cmds=(docker $([[ -d infra/terraform ]] && echo terraform) kubectl)
missing_cmds=()
for cmd in "${required_cmds[@]}"; do
  if [[ -n "$cmd" && ! $(command -v "$cmd") ]]; then
    missing_cmds+=("$cmd")
  fi
done

if ((${#missing_cmds[@]})); then
  log "❌" "Comandos ausentes:" && printf ' - %s\n' "${missing_cmds[@]}"
  exit 1
fi

compose_cmd="docker-compose"
if ! command -v docker-compose >/dev/null 2>&1; then
  if docker compose version >/dev/null 2>&1; then
    compose_cmd="docker compose"
  else
    compose_cmd=""
  fi
fi

build_and_push() {
  local image_name="$1"
  local dockerfile="$2"

  if [[ ! -f "$dockerfile" ]]; then
    log "⚠️" "Dockerfile não encontrado em $dockerfile. Pulando imagem $image_name."
    return
  fi

  log "🐳" "Construindo imagem $image_name..."
  docker build -t "$REGISTRY/$image_name:$TAG" -f "$dockerfile" .

  log "📤" "Enviando $image_name para $REGISTRY..."
  docker push "$REGISTRY/$image_name:$TAG"
}

build_and_push "explore" "apps/explore/Dockerfile"
build_and_push "symbios" "apps/symbios/Dockerfile"
build_and_push "cog-ui" "apps/cog-ui/Dockerfile"
build_and_push "lakehouse-ingest" "packages/lakehouse/ingest/Dockerfile"
build_and_push "lakehouse-transform" "packages/lakehouse/transform/Dockerfile"

if [[ -d infra/terraform/$ENVIRONMENT ]]; then
  log "⚙️" "Aplicando configurações de infraestrutura..."
  pushd "infra/terraform/$ENVIRONMENT" >/dev/null
  terraform init
  terraform apply -auto-approve -var="image_tag=$TAG"
  popd >/dev/null
else
  log "⚠️" "Diretório infra/terraform/$ENVIRONMENT não encontrado. Pulando etapa de Terraform."
fi

if command -v kubectl >/dev/null 2>&1; then
  log "🔄" "Executando migrações de banco..."
  if kubectl exec deployment/symbios -- ./migrate up; then
    log "✅" "Migrações executadas com sucesso."
  else
    log "⚠️" "Falha ao executar migrações. Verifique o log do pod symbios."
  fi
else
  log "⚠️" "kubectl não encontrado. Pulando migrações."
fi

VERIFY_SCRIPT="./scripts/verification/verify-deployment.sh"
if [[ -x "$VERIFY_SCRIPT" ]]; then
  log "🔍" "Verificando deploy..."
  "$VERIFY_SCRIPT" "$ENVIRONMENT"
else
  log "⚠️" "Script de verificação de deploy não encontrado em $VERIFY_SCRIPT."
fi

log "✅" "Deploy concluído com sucesso!"
log "🌐" "URLs sugeridas:"
log "   -" "Explore: https://explore.$ENVIRONMENT.matverse.ai"
log "   -" "SymbiOS: https://symbios.$ENVIRONMENT.matverse.ai"
log "   -" "Cog UI: https://cog.$ENVIRONMENT.matverse.ai"

