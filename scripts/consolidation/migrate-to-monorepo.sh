#!/usr/bin/env bash
# scripts/consolidation/migrate-to-monorepo.sh
#
# Consolidates MatVerse related repositories into a single monorepo layout.

set -euo pipefail

log() {
  local emoji="$1"
  shift
  printf '%s %s\n' "$emoji" "$*"
}

SECTION_BREAK="=================================================="

log "🚀" "Iniciando processo de consolidação MatVerse..."
printf '%s\n' "$SECTION_BREAK"

# Allow overriding via environment variables so the script can be tested easily.
MAIN_REPO=${MAIN_REPO:-"https://github.com/xMatVerse/xMatVerse.git"}
EXPLORE_REPO=${EXPLORE_REPO:-"https://github.com/xMatVerse/matverse-explore.git"}
SYMBIOS_REPO=${SYMBIOS_REPO:-"https://github.com/xMatVerse/SymbiOS-public.git"}
TEMP_DIR=${TEMP_DIR:-"./temp-consolidation"}
FINAL_DIR=${FINAL_DIR:-"./xMatVerse-monorepo"}
TEMPLATE_DIR=${TEMPLATE_DIR:-"../templates"}
INITIAL_COMMIT_MESSAGE=${INITIAL_COMMIT_MESSAGE:-"feat: initial monorepo consolidation"}

# Helper to ensure we are working with absolute paths inside the script.
resolve_path() {
  local path="$1"
  if [[ "$path" = /* ]]; then
    printf '%s' "$path"
  else
    printf '%s/%s' "$(pwd)" "$path"
  fi
}

TEMP_DIR=$(resolve_path "$TEMP_DIR")
FINAL_DIR=$(resolve_path "$FINAL_DIR")
TEMPLATE_DIR=$(resolve_path "$TEMPLATE_DIR")

cleanup() {
  if [[ -d "$TEMP_DIR" ]]; then
    rm -rf "$TEMP_DIR"
  fi
}
trap cleanup EXIT

if ! command -v git >/dev/null 2>&1; then
  log "❌" "Git não encontrado. Instale git para continuar."
  exit 1
fi

if [[ -d "$TEMP_DIR" ]]; then
  log "ℹ️" "Removendo diretório temporário existente em $TEMP_DIR"
  rm -rf "$TEMP_DIR"
fi

mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

log "📦" "Clonando repositórios..."

git clone --depth 1 "$MAIN_REPO" main-repo
log "✅" "Repositório principal clonado."

git clone --depth 1 "$EXPLORE_REPO" explore-repo
log "✅" "MatVerse Explore clonado."

git clone --depth 1 "$SYMBIOS_REPO" symbios-repo
log "✅" "SymbiOS clonado."

log "🏗️" "Criando estrutura do monorepo..."

mkdir -p "$FINAL_DIR"
cp -a main-repo/. "$FINAL_DIR/"
rm -rf "$FINAL_DIR/.git"

copy_with_dotfiles() {
  local source_dir="$1"
  local target_dir="$2"
  mkdir -p "$target_dir"
  (shopt -s dotglob nullglob; cp -a "$source_dir"/* "$target_dir"/ 2>/dev/null || true)
}

log "📂" "Migrando MatVerse Explore..."
copy_with_dotfiles "explore-repo" "$FINAL_DIR/apps/explore"
rm -rf "$FINAL_DIR/apps/explore/.git"

log "📂" "Migrando SymbiOS..."
copy_with_dotfiles "symbios-repo" "$FINAL_DIR/apps/symbios"
rm -rf "$FINAL_DIR/apps/symbios/.git"

log "📝" "Configurando package.json principal..."
cat > "$FINAL_DIR/package.json" <<'JSON'
{
  "name": "xmatverse-monorepo",
  "version": "1.0.0",
  "description": "MatVerse Ecosystem - Monorepo completo",
  "private": true,
  "workspaces": [
    "apps/*",
    "packages/*"
  ],
  "scripts": {
    "dev": "concurrently \"npm run dev:explore\" \"npm run dev:symbios\" \"npm run dev:cog-ui\"",
    "dev:explore": "cd apps/explore && npm run dev",
    "dev:symbios": "cd apps/symbios && go run main.go serve",
    "dev:cog-ui": "cd apps/cog-ui && npm run dev",
    "build": "npm run build --workspaces",
    "test": "npm run test --workspaces",
    "test:ci": "npm run test:ci --workspaces",
    "lint": "npm run lint --workspaces",
    "docker:up": "docker-compose -f infra/docker-compose.yml up -d",
    "docker:down": "docker-compose -f infra/docker-compose.yml down",
    "lakehouse:init": "scripts/verification/verify-lakehouse.sh",
    "status": "scripts/status/healthcheck.sh"
  },
  "devDependencies": {
    "concurrently": "^8.2.2"
  },
  "engines": {
    "node": ">=18.0.0",
    "npm": ">=9.0.0"
  }
}
JSON

log "⚙️" "Configurando arquivos de configuração adicionais..."
if [[ -d "$TEMPLATE_DIR" && -n "$(ls -A "$TEMPLATE_DIR" 2>/dev/null)" ]]; then
  cp -a "$TEMPLATE_DIR"/. "$FINAL_DIR"/
else
  log "ℹ️" "Nenhum template encontrado em $TEMPLATE_DIR. Pulando etapa."
fi

log "🔨" "Inicializando repositório git..."
cd "$FINAL_DIR"

git init >/dev/null
if git status --short >/dev/null 2>&1 && [[ -n "$(git status --short)" ]]; then
  git add .
  git commit -m "$INITIAL_COMMIT_MESSAGE" >/dev/null
  log "✅" "Commit inicial criado."
else
  log "ℹ️" "Nenhuma alteração a commitar."
fi

log "✅" "Consolidação concluída!"
log "📁" "Diretório final: $FINAL_DIR"
log "🚀" "Para iniciar: cd $FINAL_DIR && npm install && npm run docker:up"

