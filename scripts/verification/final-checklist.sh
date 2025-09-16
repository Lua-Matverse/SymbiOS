#!/usr/bin/env bash
# scripts/verification/final-checklist.sh
#
# Interactive checklist used before declaring the consolidation finished.

set -euo pipefail

log() {
  local emoji="$1"
  shift
  printf '%s %s\n' "$emoji" "$*"
}

log "✅" "Checklist Final de Consolidação"
printf '=================================%s\n' ""

checks=(
  "Estrutura de diretórios completa"
  "Build bem-sucedido de todos os componentes"
  "Serviços Docker em execução"
  "Conexão com MinIO funcionando"
  "Conexão com Trino funcionando"
  "Redis respondendo"
  "Testes passando"
  "Configuração de CI/CD válida"
  "Documentação atualizada"
  "Variáveis de ambiente configuradas"
)

for check in "${checks[@]}"; do
  while true; do
    read -rp "$check (y/n): " -n 1 response
    printf '\n'
    case "$response" in
      [Yy]) break ;;
      [Nn])
        log "❌" "Checklist incompleto: $check"
        exit 1
        ;;
      *) printf 'Por favor responda com y ou n.\n' ;;
    esac
  done
  log "✅" "$check verificado"
done

log "🎉" "Checklist completo! MatVerse está pronto para produção!"

