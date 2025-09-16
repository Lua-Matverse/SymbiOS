#!/usr/bin/env bash
# scripts/troubleshooting/fix-common-issues.sh
#
# Applies a set of corrective actions for recurring environment issues.

set -euo pipefail

log() {
  local emoji="$1"
  shift
  printf '%s %s\n' "$emoji" "$*"
}

log "🐛" "Correção de Problemas Comuns"
printf '================================\n'

step=1

log "${step}." "Corrigindo permissões Docker..."
if command -v docker >/dev/null 2>&1; then
  if groups "$USER" | grep -qw docker; then
    log "✅" "Usuário já pertence ao grupo docker"
  else
    if command -v sudo >/dev/null 2>&1; then
      if sudo usermod -aG docker "$USER"; then
        log "🛠️" "Usuário adicionado ao grupo docker. Reinicie a sessão ou execute: newgrp docker"
      else
        log "⚠️" "Não foi possível ajustar o grupo docker"
      fi
    elif [[ "$EUID" -eq 0 ]]; then
      target_user=${SUDO_USER:-}
      if [[ -n "$target_user" ]]; then
        if usermod -aG docker "$target_user" 2>/dev/null; then
          log "🛠️" "Usuário ${target_user} adicionado ao grupo docker"
        else
          log "⚠️" "Não foi possível ajustar o grupo docker"
        fi
      else
        log "ℹ️" "Execute como usuário final (ex: via sudo) para ajustar o grupo docker."
      fi
      unset target_user
    else
      log "⚠️" "sudo não disponível. Ajuste manualmente o grupo docker."
    fi
  fi
else
  log "⚠️" "Docker não instalado. Pulando etapa."
fi
((step++))

log "${step}." "Limpando cache Docker..."
if command -v docker >/dev/null 2>&1; then
  docker system prune -f || log "⚠️" "Não foi possível limpar o cache Docker"
else
  log "⚠️" "Docker não instalado. Pulando etapa."
fi
((step++))

log "${step}." "Reinstalando dependências Node.js..."
if command -v npm >/dev/null 2>&1; then
  rm -rf node_modules package-lock.json
  npm install
else
  log "⚠️" "npm não disponível. Pulando reinstalação."
fi
((step++))

log "${step}." "Reinstalando dependências Go..."
if command -v go >/dev/null 2>&1 && [[ -d apps/symbios ]]; then
  pushd apps/symbios >/dev/null
  rm -rf vendor go.sum
  go mod download
  popd >/dev/null
else
  log "⚠️" "Go não disponível ou diretório apps/symbios ausente."
fi
((step++))

log "${step}." "Parando serviços em conflito..."
pkill -f "node" >/dev/null 2>&1 || true
pkill -f "go run" >/dev/null 2>&1 || true
pkill -f "npm" >/dev/null 2>&1 || true
log "✅" "Serviços conflitantes interrompidos (quando existentes)"
((step++))

log "${step}." "Verificando firewall..."
if command -v ufw >/dev/null 2>&1; then
  if command -v sudo >/dev/null 2>&1; then
    sudo ufw allow 3000 8080 9000 9001 >/dev/null 2>&1 || true
  elif [[ "$EUID" -eq 0 ]]; then
    ufw allow 3000 8080 9000 9001 >/dev/null 2>&1 || true
  else
    log "⚠️" "Permissões insuficientes para ajustar firewall"
  fi
  log "✅" "Regras básicas de firewall aplicadas"
else
  log "ℹ️" "ufw não encontrado. Pulando etapa."
fi
((step++))

log "${step}." "Avaliando memória disponível..."
if command -v free >/dev/null 2>&1; then
  total_mem=$(free -m | awk '/Mem:/ {print $2}')
  if [[ -n "$total_mem" && "$total_mem" -lt 4096 ]]; then
    export NODE_OPTIONS="--max-old-space-size=2048"
    log "⚠️" "Memória detectada (${total_mem}MB) abaixo de 4GB. NODE_OPTIONS ajustado para 2GB."
  else
    log "✅" "Memória suficiente detectada (${total_mem}MB)"
  fi
else
  log "⚠️" "Não foi possível determinar a memória disponível"
fi

log "✅" "Correções aplicadas!"
