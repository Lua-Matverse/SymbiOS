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
