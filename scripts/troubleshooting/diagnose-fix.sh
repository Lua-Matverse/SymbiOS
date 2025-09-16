#!/usr/bin/env bash
# scripts/troubleshooting/diagnose-fix.sh
#
# Performs an environment diagnosis and applies corrective actions for the MatVerse stack.

set -euo pipefail

log() {
  local emoji="$1"
  shift
  printf '%s %s\n' "$emoji" "$*"
}

print_version() {
  local label="$1"
  shift
  local cmd=("$@")
  if command -v "${cmd[0]}" >/dev/null 2>&1; then
    local version
    if version="$("${cmd[@]}" 2>&1)"; then
      log "ℹ️" "$label: $version"
    else
      log "⚠️" "$label: ${cmd[0]} --version falhou"
    fi
  else
    log "⚠️" "$label não instalado"
  fi
}

log "🔧" "Diagnóstico e Correção do Ambiente MatVerse"
printf '==============================================\n'

print_version "Node.js" node --version
print_version "npm" npm --version
print_version "Go" go version
print_version "Python" python3 --version
print_version "Docker" docker --version
if command -v docker-compose >/dev/null 2>&1; then
  print_version "Docker Compose" docker-compose --version
elif docker compose version >/dev/null 2>&1; then
  print_version "Docker Compose" docker compose version
else
  log "⚠️" "Docker Compose não instalado"
fi

if [[ ! -f package.json ]]; then
  log "❌" "Não está no diretório raiz do projeto (package.json ausente). Diretório atual: $(pwd)"
  exit 1
fi

log "🔒" "Verificando permissões de scripts..."
if [[ -d scripts ]]; then
  while IFS= read -r -d '' script_file; do
    chmod +x "$script_file"
  done < <(find scripts -type f -name '*.sh' -print0)
fi
log "✅" "Permissões ajustadas"

log "📦" "Verificando dependências Node.js..."
if command -v npm >/dev/null 2>&1; then
  if [[ ! -d node_modules ]]; then
    log "🛠️" "Instalando dependências Node.js..."
    npm install
  else
    log "✅" "Dependências Node.js já instaladas"
  fi
else
  log "❌" "npm não encontrado. Instale Node.js/npm antes de prosseguir."
  exit 1
fi

if [[ -d apps/symbios ]]; then
  log "📦" "Verificando dependências Go (apps/symbios)..."
  if command -v go >/dev/null 2>&1; then
    pushd apps/symbios >/dev/null
    if [[ ! -d vendor ]]; then
      log "🛠️" "Instalando dependências Go..."
      go mod download
    else
      log "✅" "Dependências Go já instaladas"
    fi
    popd >/dev/null
  else
    log "⚠️" "Go não instalado. Pulando verificação das dependências Go."
  fi
else
  log "⚠️" "Diretório apps/symbios não encontrado. Pulando verificação Go."
fi

log "🐳" "Verificando Docker..."
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  log "✅" "Docker em execução"
else
  log "❌" "Docker não está rodando. Inicie o serviço (ex: sudo systemctl start docker)."
  exit 1
fi

log "🔌" "Verificando portas..."
declare -A ports=(
  [3000]="Explore"
  [8080]="SymbiOS"
  [9000]="MinIO"
  [9001]="MinIO Console"
  [8081]="Trino"
  [6379]="Redis"
  [9090]="Prometheus"
  [3001]="Grafana"
)

check_port() {
  local port="$1"
  local description="$2"
  if command -v nc >/dev/null 2>&1; then
    if nc -z localhost "$port" >/dev/null 2>&1; then
      log "⚠️" "Porta $port (${description}) já está em uso"
    else
      log "✅" "Porta $port (${description}) disponível"
    fi
  elif command -v ss >/dev/null 2>&1; then
    if ss -ltn | awk '{print $4}' | grep -qE ":${port}$"; then
      log "⚠️" "Porta $port (${description}) já está em uso"
    else
      log "✅" "Porta $port (${description}) disponível"
    fi
  else
    log "⚠️" "Não foi possível verificar a porta $port (${description}). Ferramenta nc/ss indisponível."
  fi
}

for port in "${!ports[@]}"; do
  check_port "$port" "${ports[$port]}"
done

log "🌐" "Verificando variáveis de ambiente..."
if [[ -f .env ]]; then
  log "✅" ".env encontrado"
elif [[ -f .env.example ]]; then
  cp .env.example .env
  log "⚠️" "Arquivo .env criado a partir de .env.example. Revise as variáveis."
else
  log "⚠️" "Nenhum arquivo .env ou .env.example encontrado"
fi

log "📡" "Testando conectividade externa..."
if command -v ping >/dev/null 2>&1; then
  if ping -c 1 github.com >/dev/null 2>&1; then
    log "✅" "Conexão com a internet OK"
  else
    log "❌" "Falha na conexão com a internet"
  fi
else
  log "⚠️" "Comando ping indisponível. Não foi possível testar a conexão."
fi

log "💾" "Verificando espaço em disco..."
df -h . || log "⚠️" "Não foi possível obter uso de disco"

log "✅" "Diagnóstico concluído. Execute ./scripts/quickstart.sh para iniciar o ambiente."
