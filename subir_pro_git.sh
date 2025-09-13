#!/usr/bin/env bash
set -euo pipefail

# =================== CONFIG ===================
OWNER="${OWNER:-MATVERSE-LUA}"         # altere se quiser
REPO="${REPO:-monorepo}"               # nome do repositório público novo
VISIBILITY="${VISIBILITY:-public}"     # public|private|internal
DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"
DESCRIPTION="${DESCRIPTION:-Meta-sistema operacional linguístico - Monorepo unificado}"

# Opcional: URLs dos repos antigos para migração (edite se precisar)
SRC_REPO_1="${SRC_REPO_1:-https://github.com/xMatVerse/SymbiOS.git}"
SRC_REPO_2="${SRC_REPO_2:-https://github.com/xMatVerse/SymbiOS.lua.git}"
SRC_REPO_3="${SRC_REPO_3:-https://github.com/Lua-Matverse/SymbiOS.git}"

# =================== UTIL ===================
say(){ printf "\n\033[1;36m%s\033[0m\n" "$*"; }
die(){ printf "\n\033[1;31mERRO:\033[0m %s\n" "$*" ; exit 1; }

command -v git >/dev/null || die "git não encontrado"
command -v gh  >/dev/null || die "gh (GitHub CLI) não encontrado. Rode: gh auth login"

# =================== 1) REPO (GitHub) ===================
say "1) Criando/verificando repositório $OWNER/$REPO ($VISIBILITY)…"
if gh repo view "$OWNER/$REPO" >/dev/null 2>&1; then
  say "→ Repo já existe. Usarei esse remoto."
else
  gh repo create "$OWNER/$REPO" --"$VISIBILITY" -y -d "$DESCRIPTION"
fi

# =================== 2) WORKDIR LOCAL ===================
WORKDIR="$(pwd)/$REPO"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# Init git se ainda não
if [ ! -d .git ]; then
  git init -b "$DEFAULT_BRANCH"
fi

# =================== 3) ESTRUTURA MONOREPO ===================
# (conforme recomendação: apps, packages, deployments, monitoring, testing, docs, future, data)
say "2) Gerando estrutura monorepo…"
mkdir -p apps packages deployments monitoring testing docs future data .github/workflows

# README
cat > README.md <<'EOR'
# MATVERSE-LUA Monorepo

Monorepo público unificado dos componentes **LUA/NEXUS** (visão + MVP DevOps).
- `apps/`       – CLIs, APIs, front-ends
- `packages/`   – bibliotecas e núcleos reutilizáveis
- `deployments/`– IaC, manifests, Docker/Compose
- `monitoring/` – observabilidade e métricas
- `testing/`    – testes de integração/e2e e utilitários
- `docs/`       – documentação técnica e guias
- `future/`     – P&D, protótipos
- `data/`       – datasets e fixtures (não sensíveis)

> Estrutura criada para consolidar projetos e padronizar CI/CD.
EOR

# .gitignore
cat > .gitignore <<'EOR'
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
EOR

# =================== 4) CI BÁSICO (monorepo-aware simples) ===================
# CI genérico: detecta Python e/ou Node e roda testes se existirem
cat > .github/workflows/ci.yml <<'EOR'
name: CI
on:
  push:
    branches: [ main ]
  pull_request:
jobs:
  detect-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # Python (FastAPI/tests)
      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - name: Python deps (se existirem)
        run: |
          if compgen -G "**/requirements*.txt" > /dev/null; then
            python -m pip install -U pip
            find . -name "requirements*.txt" -print0 | xargs -0 -I{} python -m pip install -r "{}"
          fi
      - name: Testes Python (se existirem)
        run: |
          if compgen -G "**/pytest.ini" > /dev/null || compgen -G "**/tests" > /dev/null; then
            python -m pip install pytest
            pytest -q || true
          fi

      # Node (web/cli)
      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: '18'
      - name: Instalar e testar (se existir package.json)
        run: |
          if compgen -G "**/package.json" > /dev/null; then
            npm i --prefer-offline --no-audit --no-fund || true
            npm test --silent || true
          fi
EOR

# =================== 5) OPCIONAL: MIGRAÇÃO DO CÓDIGO LEGADO ===================
# Sugestões de mapeamento (ajuste conforme seu repositório local/clonado):
cat > MIGRACAO_LEGADO.md <<'EOR'
# Migração do Legado para o Monorepo

Passos sugeridos:
1. Clone seus repos locais num diretório temporário:
   ```bash
   git clone https://github.com/xMatVerse/SymbiOS.git old/SymbiOS
   git clone https://github.com/xMatVerse/SymbiOS.lua.git old/SymbiOS.lua
   git clone https://github.com/Lua-Matverse/SymbiOS.git old/SymbiOS-main
```

2. Movimentação típica (exemplos):

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

3. Revise imports e caminhos, ajuste Dockerfiles/Compose e adicione testes mínimos.

4. Faça commit incremental e abra PRs para organizar por módulos.
EOR

# =================== 6) PRIMEIRO COMMIT ===================

say "3) Commit inicial…"
git add .
git commit -m "chore: bootstrap monorepo (estrutura + CI básico)"

# =================== 7) REMOTO + PUSH ===================

REMOTE_URL="https://github.com/$OWNER/$REPO.git"
if ! git remote | grep -q "^origin$"; then
git remote add origin "$REMOTE_URL"
fi
git branch -M "$DEFAULT_BRANCH"
say "4) Dando push para $REMOTE_URL…"
git push -u origin "$DEFAULT_BRANCH"

say "✅ Pronto! Repo: https://github.com/$OWNER/$REPO"
