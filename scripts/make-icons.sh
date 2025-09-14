#!/usr/bin/env bash
set -Eeuo pipefail

usage(){
  cat <<USG
Uso:
  $0 -i <logo.png> [-o <dir-saida>]
Exemplo:
  $0 -i apps/xplore/public/branding/mv-xplore-logo.png -o apps/xplore/public/icons
USG
}

SRC=""
OUTDIR="public/icons"
SIZES=(16 32 48 72 96 128 144 152 167 180 192 256 384 512)

while getopts "i:o:h" opt; do
  case "$opt" in
    i) SRC="$OPTARG";;
    o) OUTDIR="$OPTARG";;
    h) usage; exit 0;;
    *) usage; exit 1;;
  esac
done

[ -n "$SRC" ] || { usage >&2; exit 1; }
[ -f "$SRC" ] || { echo "Arquivo não encontrado: $SRC" >&2; exit 1; }

command -v convert >/dev/null || { echo "ImageMagick (convert) não encontrado" >&2; exit 1; }

mkdir -p "$OUTDIR"
for s in "${SIZES[@]}"; do
  convert "$SRC" -resize "${s}x${s}" "$OUTDIR/icon-${s}.png"
  echo "Gerado: $OUTDIR/icon-${s}.png"
done
