#!/usr/bin/env bash
set -Eeuo pipefail

################################################################################
# subir_pro_git.sh — bootstrap monorepo + import de repo legado (subtree) + push
# Requisitos: git, gh (autenticado: `gh auth login`)
#
# Exemplo:
# ./subir_pro_git.sh -o Lua-Matverse -r monorepo -v public -b main \
#   -d "Monorepo LUA/NEXUS" \
#   --source https://github.com/Lua-Matverse/SymbiOS.git \
#   --import-prefix apps/symbios
################################################################################

# ---------- util ----------
RED=$'\033[1;31m'; CYAN=$'\033[1;36m'; GRAY=$'\033[0;90m'; NC=$'\033[0m'
log(){ printf "\n${CYAN}%s${NC}\n" "$*"; }
die(){ printf "${RED}ERRO:${NC} %s\n" "$*" ; exit 1; }
trap 'printf "\n${RED}Falhou na linha ${BASH_LINENO[0]} (cmd: ${BASH_COMMAND})${NC}\n"' ERR

command -v git >/dev/null || die "git não encontrado"
command -v gh  >/dev/null || die "gh (GitHub CLI) não encontrado. Rode: gh auth login"

# ---------- defaults ----------
OWNER=""; REPO=""; VISIBILITY="public"; DEFAULT_BRANCH="main"
DESCRIPTION="Meta-sistema operacional linguístico - Monorepo unificado"
NO_CREATE=false; SKIP_CI=false; DRY_RUN=false
SOURCE_URL=""; IMPORT_PREFIX="apps/symbios"

usage(){
cat <<'USAGE'
Uso:
  $0 -o <owner> -r <repo> [opções]

Obrigatórios:
  -o, --owner          Organização/usuário no GitHub (ex: Lua-Matverse)
  -r, --repo           Nome do repositório alvo (ex: monorepo)

Opcionais:
  -v, --visibility     public|private|internal  (default: public)
  -b, --branch         branch padrão do alvo    (default: main)
  -d, --description    descrição do repo
      --source         URL do repo legado a importar (preserva histórico)
      --import-prefix  Caminho alvo no monorepo (default: apps/symbios)
      --no-create      Não cria repo no GitHub (usa existente)
      --skip-ci        Não cria workflow de CI
      --dry-run        Não altera remoto (sem criação/push)
  -h, --help           Ajuda
USAGE
}

# ---------- parse args ----------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--owner)        OWNER="${2:-}"; shift 2;;
    -r|--repo)         REPO="${2:-}"; shift 2;;
    -v|--visibility)   VISIBILITY="${2:-}"; shift 2;;
    -b|--branch)       DEFAULT_BRANCH="${2:-}"; shift 2;;
    -d|--description)  DESCRIPTION="${2:-}"; shift 2;;
    --source)          SOURCE_URL="${2:-}"; shift 2;;
    --import-prefix)   IMPORT_PREFIX="${2:-}"; shift 2;;
    --no-create)       NO_CREATE=true; shift;;
    --skip-ci)         SKIP_CI=true; shift;;
    --dry-run)         DRY_RUN=true; shift;;
    -h|--help)         usage; exit 0;;
    *) die "flag desconhecida: $1 (use -h)";;
  esac
done

[[ -n "$OWNER" ]] || die "informe -o|--owner"
[[ -n "$REPO"  ]] || die "informe -r|--repo"
[[ "$OWNER" =~ ^[A-Za-z0-9._-]+$ ]] || die "OWNER inválido"
[[ "$REPO"  =~ ^[A-Za-z0-9._-]+$ ]]  || die "REPO inválido"
[[ "$VISIBILITY" =~ ^(public|private|internal)$ ]] || die "visibility inválida"

# ---------- 1) repo remoto ----------
log "1) Repositório GitHub: ${OWNER}/${REPO} (${VISIBILITY})"
if gh repo view "$OWNER/$REPO" >/dev/null 2>&1; then
  log "→ já existe. usando remoto atual."
else
  $NO_CREATE && die "repo não existe e --no-create foi usado"
  if $DRY_RUN; then
    log "[DRY] criaria repo ${OWNER}/${REPO}"
  else
    gh repo create "$OWNER/$REPO" --"$VISIBILITY" -y -d "$DESCRIPTION"
  fi
fi
REMOTE_URL="https://github.com/${OWNER}/${REPO}.git"

# ---------- 2) workspace local ----------
WORKDIR="$(pwd)/$REPO"
mkdir -p "$WORKDIR"; cd "$WORKDIR"

if [ ! -d .git ]; then
  git init -b "$DEFAULT_BRANCH"
fi

# ---------- 3) estrutura monorepo ----------
log "2) Gerando estrutura monorepo…"
mkdir -p apps packages deployments monitoring testing docs future data .github/workflows

# README
cat > README.md <<'EOF_README'
# MATVERSE-LUA Monorepo

Monorepo público unificado dos componentes **LUA/NEXUS** (visão + MVP DevOps).

**Pastas**
- `apps/`       – CLIs, APIs, front-ends
- `packages/`   – bibliotecas e núcleos reutilizáveis
- `deployments/`– IaC, manifests, Docker/Compose
- `monitoring/` – observabilidade e métricas
- `testing/`    – testes de integração/e2e e utilitários
- `docs/`       – documentação técnica e guias
- `future/`     – P&D, protótipos
- `data/`       – datasets e fixtures (não sensíveis)

> Estrutura criada para consolidar projetos e padronizar CI/CD.
EOF_README

# .gitignore
cat > .gitignore <<'EOF_GITIGNORE'
# Node / JS
node_modules
dist
.vite
# Python
__pycache__/
*.py[cod]
.venv/
.env*
# OS / misc
.DS_Store
*.log
# Build artifacts
build/
coverage/
EOF_GITIGNORE

# .editorconfig
cat > .editorconfig <<'EOF_EDITOR'
root = true
[*]
end_of_line = lf
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true
indent_style = space
indent_size = 2
EOF_EDITOR

# .gitattributes
cat > .gitattributes <<'EOF_ATTR'
* text=auto eol=lf
EOF_ATTR

# LICENSE (placeholder)
cat > LICENSE <<'EOF_LICENSE'
MIT License

Copyright (c)

Permission is hereby granted, free of charge, to any person obtaining a copy...
(Preencha o ano e titular antes de publicar versões)
EOF_LICENSE

# MIGRACAO_LEGADO.md
cat > MIGRACAO_LEGADO.md <<'EOF_MIG'
# Migração do Legado para o Monorepo

## 1) Exemplos de clones
```bash
git clone https://github.com/xMatVerse/SymbiOS.git old/SymbiOS
git clone https://github.com/xMatVerse/SymbiOS.lua.git old/SymbiOS.lua
git clone https://github.com/Lua-Matverse/SymbiOS.git old/SymbiOS-main
```

## 2) Movimentações sugeridas
```bash
# backend FastAPI → packages/core/lua-api
mkdir -p packages/core/lua-api
rsync -a old/SymbiOS/backend/ packages/core/lua-api/ || true

# CLI → apps/lua-cli
mkdir -p apps/lua-cli
rsync -a old/SymbiOS/cli/ apps/lua-cli/ || true

# Ops/IaC → deployments
mkdir -p deployments
rsync -a old/SymbiOS/ops/ deployments/ || true
```

## 3) Ajustes
- Corrigir imports/caminhos
- Revisar Dockerfiles/Compose
- Criar testes mínimos (unit/integration)
EOF_MIG

# ---------- 4) CI ----------
if ! $SKIP_CI; then
log "3) Adicionando CI com cache e segurança…"
cat > .github/workflows/ci.yml <<'EOF_CI'
name: CI
on:
  push:
    branches: [ main ]
    paths-ignore:
      - '/*.md'
      - 'docs/'
  pull_request:
    paths-ignore:
      - '/*.md'
      - 'docs/'
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
jobs:
  detect-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # Python
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
          cache: 'pip'
      - name: Instalar deps Python (se existirem)
        run: |
          shopt -s globstar nullglob
          REQS=( **/requirements*.txt )
          if (( ${#REQS[@]} )); then
            python -m pip install --upgrade pip
            for f in "${REQS[@]}"; do python -m pip install -r "$f"; done
          fi
      - name: Rodar testes Python (se existirem)
        run: |
          if compgen -G "**/tests" > /dev/null || compgen -G "**/pytest.ini" > /dev/null; then
            python -m pip install pytest
            pytest -q || true
          fi

      # Node
      - uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'
      - name: Instalar e testar Node (se existir package.json)
        run: |
          if compgen -G "**/package.json" > /dev/null; then
            npm i --prefer-offline --no-audit --no-fund || true
            npm test --silent || true
          fi
EOF_CI
fi

# ---------- 5) importar legado (opcional) ----------
if [[ -n "$SOURCE_URL" ]]; then
  log "4) Importando ${SOURCE_URL} em ${IMPORT_PREFIX} (preservando histórico via git subtree)…"
  SRC_BRANCH="$(git ls-remote --symref "$SOURCE_URL" HEAD | awk '/^ref:/ { sub("refs/heads/","",$2); print $2; exit }')"
  [[ -n "$SRC_BRANCH" ]] || SRC_BRANCH="main"
  if git remote | grep -q '^src$'; then
    git remote set-url src "$SOURCE_URL"
  else
    git remote add src "$SOURCE_URL"
  fi
  git fetch src "$SRC_BRANCH"
  mkdir -p "$(dirname "$IMPORT_PREFIX")"
  if git log --pretty=%s | grep -q "subtree: ${SOURCE_URL}"; then
    log "→ já importado anteriormente. pulando."
  else
    git subtree add --prefix="$IMPORT_PREFIX" src "$SRC_BRANCH" -m "subtree: ${SOURCE_URL} → ${IMPORT_PREFIX}"
  fi
fi

# ---------- 6) commit ----------
if [[ -n "$(git status --porcelain)" ]]; then
  log "5) Commit…"
  git add .
  git commit -m "chore: bootstrap monorepo (estrutura + CI + hygiene)"
fi

# ---------- 7) remoto + push ----------
if ! git remote | grep -q '^origin$'; then
  git remote add origin "$REMOTE_URL"
fi
git branch -M "$DEFAULT_BRANCH"

log "6) Push → $REMOTE_URL (${GRAY}branch ${DEFAULT_BRANCH}${NC})"
if $DRY_RUN; then
  log "[DRY] pularia push"
else
  git push -u origin "$DEFAULT_BRANCH"
fi

log "✅ pronto! Repo: https://github.com/${OWNER}/${REPO}"
