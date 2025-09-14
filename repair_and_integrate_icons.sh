#!/usr/bin/env bash
set -Eeuo pipefail

# -----------------------------------------------------------------------------
# Repara/cria apps/xplore e integra o gerador de ícones PWA
# Uso:
#   ./repair_and_integrate_icons.sh -d core [--generate-now]
# Deps:
#   - git
#   - npx/node (opcional; para scaffold Vite)
#   - ImageMagick "convert" (opcional; para gerar ícones)
# -----------------------------------------------------------------------------

MONO_DIR="core"
GENERATE_NOW=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--dir) MONO_DIR="${2:-core}"; shift 2;;
    --generate-now) GENERATE_NOW=1; shift;;
    -h|--help)
      echo "Uso: $0 -d <core> [--generate-now]"
      exit 0;;
    *) echo "Flag desconhecida: $1"; exit 1;;
  esac
done

# Helpers
say(){ printf "\n\033[1;36m%s\033[0m\n" "$*"; }
warn(){ printf "\033[1;33m⚠ %s\033[0m\n" "$*"; }
die(){ printf "\033[1;31m✖ %s\033[0m\n" "$*"; exit 1; }

[ -d "$MONO_DIR" ] || die "Diretório '$MONO_DIR' não existe. Rode a partir da raiz do repo e confira o nome."

cd "$MONO_DIR"
mkdir -p apps

# -----------------------------------------------------------------------------
# 1) Garantir apps/xplore com package.json (preferência: Vite; fallback: stub)
# -----------------------------------------------------------------------------
if [ -f "apps/xplore/package.json" ]; then
  say "apps/xplore já existe — mantendo."
else
  if command -v npx >/dev/null 2>&1 && command -v node >/dev/null 2>&1; then
    say "Criando Xplore via Vite (React+TS)…"
    pushd apps >/dev/null
    npx --yes create-vite@latest xplore -- --template react-ts
    cd xplore
    npm i --silent || true
    popd >/dev/null
  else
    warn "npx/node não encontrados — criando stub mínimo de xplore…"
    mkdir -p apps/xplore/public/icons apps/xplore/public/branding apps/xplore/src
    cat > apps/xplore/package.json <<'PKG'
{
  "name": "xplore",
  "version": "0.0.0",
  "private": true,
  "scripts": {
    "icons": "bash ../../scripts/make-icons.sh apps/xplore/public/branding/mv-xplore-logo.png apps/xplore/public/icons"
  }
}
PKG
    # index mínimo só para não ficar vazio
    cat > apps/xplore/src/main.ts <<'TS'
console.log("Xplore stub ready.");
TS
  fi
fi

# -----------------------------------------------------------------------------
# 2) Garantir script de ícones em scripts/make-icons.sh
# -----------------------------------------------------------------------------
mkdir -p scripts
if [ ! -f scripts/make-icons.sh ]; then
  say "Instalando scripts/make-icons.sh…"
  cat > scripts/make-icons.sh <<'EOS'
#!/usr/bin/env bash
set -Eeuo pipefail

SRC=${1:-apps/xplore/public/branding/mv-xplore-logo.png}
OUTDIR=${2:-apps/xplore/public/icons}
SIZES=(16 32 48 72 96 128 144 152 167 180 192 256 384 512)

command -v convert >/dev/null || { echo "ImageMagick (convert) não encontrado"; exit 1; }

mkdir -p "$OUTDIR"
for s in "${SIZES[@]}"; do
  convert "$SRC" -resize "${s}x${s}" "$OUTDIR/icon-${s}.png"
  echo "Gerado: $OUTDIR/icon-${s}.png"
done
EOS
  chmod +x scripts/make-icons.sh
fi

# -----------------------------------------------------------------------------
# 3) Public/branding + placeholder de logo (se ausente)
# -----------------------------------------------------------------------------
mkdir -p apps/xplore/public/branding apps/xplore/public/icons
if [ ! -f apps/xplore/public/branding/mv-xplore-logo.png ]; then
  if command -v convert >/dev/null 2>&1; then
    say "Gerando logo placeholder (512x512)…"
    convert -size 512x512 xc:none -fill "#7a4cff" -draw "circle 256,256 256,80" \
      -gravity center -pointsize 72 -fill white -annotate 0 "MV" \
      apps/xplore/public/branding/mv-xplore-logo.png
  else
    warn "ImageMagick ausente — crie seu logo em apps/xplore/public/branding/mv-xplore-logo.png"
  fi
fi

# -----------------------------------------------------------------------------
# 4) Adicionar script 'icons' ao package.json (se faltar)
# -----------------------------------------------------------------------------
PKG="apps/xplore/package.json"
if command -v jq >/dev/null 2>&1; then
  if ! jq -e '.scripts.icons' "$PKG" >/dev/null; then
    say "Inserindo script 'icons' no package.json (via jq)…"
    tmp="$(mktemp)"
    jq '.scripts.icons="bash ../../scripts/make-icons.sh apps/xplore/public/branding/mv-xplore-logo.png apps/xplore/public/icons"' "$PKG" > "$tmp"
    mv "$tmp" "$PKG"
  fi
else
  # fallback simples: se não encontrar "icons", injeta antes do fechamento de scripts
  if ! grep -q '"icons"' "$PKG"; then
    say "Inserindo script 'icons' no package.json (fallback sed)…"
    sed -i.bak 's/"scripts":[[:space:]]*{/"scripts": {\
    "icons": "bash ..\/..\/scripts\/make-icons.sh apps\/xplore\/public\/branding\/mv-xplore-logo.png apps\/xplore\/public\/icons",/1' "$PKG" || true
    rm -f "$PKG.bak"
  fi
fi

# -----------------------------------------------------------------------------
# 5) Gerar ícones agora (opcional)
# -----------------------------------------------------------------------------
if [ $GENERATE_NOW -eq 1 ]; then
  if command -v convert >/dev/null 2>&1; then
    say "Gerando ícones PWA…"
    bash ./scripts/make-icons.sh apps/xplore/public/branding/mv-xplore-logo.png apps/xplore/public/icons || true
  else
    warn "ImageMagick ausente — pulei geração de ícones (--generate-now)."
  fi
fi

# -----------------------------------------------------------------------------
# 6) Git add/commit
# -----------------------------------------------------------------------------
git add apps/xplore scripts/make-icons.sh || true
git commit -m "fix(xplore): scaffold/repair + icons integration" || true

say "✅ Pronto. Estrutura apps/xplore criada/checada e integração de ícones aplicada."
say "   Para gerar ícones manualmente: (na raiz do monorepo)  bash ./scripts/make-icons.sh apps/xplore/public/branding/mv-xplore-logo.png apps/xplore/public/icons"
