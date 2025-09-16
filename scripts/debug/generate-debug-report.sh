#!/usr/bin/env bash
# scripts/debug/generate-debug-report.sh
#
# Collects a comprehensive debug snapshot for troubleshooting MatVerse deployments.

set -euo pipefail

log() {
  local emoji="$1"
  shift
  printf '%s %s\n' "$emoji" "$*"
}

output_dir="logs/debug"
mkdir -p "$output_dir"
report_file="$output_dir/debug-report-$(date +%Y%m%d-%H%M%S).txt"

log "📝" "Gerando relatório de debug em $report_file"

{
  printf 'MatVerse Debug Report - %s\n' "$(date)"
  printf '=================================\n\n'

  printf '## System Information\n'
  printf '=====================\n'
  uname -a 2>&1 || printf 'uname indisponível\n'
  printf '\n'

  printf '## Resource Usage\n'
  printf '=================\n'
  free -h 2>&1 || printf 'free indisponível\n'
  printf '\n'
  df -h . 2>&1 || printf 'df indisponível\n'
  printf '\n'

  printf '## Network Information\n'
  printf '======================\n'
  if command -v ifconfig >/dev/null 2>&1; then
    ifconfig 2>&1
  elif command -v ip >/dev/null 2>&1; then
    ip addr 2>&1
  else
    printf 'Ferramentas de rede indisponíveis\n'
  fi
  printf '\n'

  printf '## Docker Status\n'
  printf '================\n'
  if command -v docker >/dev/null 2>&1; then
    docker info 2>&1 || printf 'docker info falhou\n'
    printf '\n'
    docker ps -a 2>&1 || printf 'docker ps falhou\n'
  else
    printf 'Docker não instalado\n'
  fi
  printf '\n'

  printf '## Service Status\n'
  printf '=================\n'
  if command -v ss >/dev/null 2>&1; then
    ss -tulpn 2>&1
  elif command -v netstat >/dev/null 2>&1; then
    netstat -tulpn 2>&1
  else
    printf 'Ferramentas ss/netstat indisponíveis\n'
  fi
  printf '\n'

  printf '## Process Information\n'
  printf '======================\n'
  ps aux | grep -E '(node|go|docker)' | head -20 2>&1 || printf 'ps indisponível\n'
  printf '\n'

  printf '## Environment Variables\n'
  printf '========================\n'
  printenv | grep -E '(MATVERSE|NODE|GO|DOCKER)' | sort 2>/dev/null || printf 'Variáveis relevantes não encontradas\n'
  printf '\n'

  printf '## Log Files (últimas 5 linhas)\n'
  printf '================================\n'
  find . -name '*.log' -type f -print0 2>/dev/null | while IFS= read -r -d '' logfile; do
    printf '-- %s --\n' "$logfile"
    tail -n 5 "$logfile" 2>/dev/null || printf 'Não foi possível ler %s\n' "$logfile"
    printf '\n'
  done
} >"$report_file"

log "✅" "Relatório de debug salvo em $report_file"
