#!/usr/bin/env bash
# scripts/consolidation/archive-repositories.sh
#
# Archives legacy repositories once the MatVerse monorepo is established.

set -euo pipefail

log() {
  local emoji="$1"
  shift
  printf '%s %s\n' "$emoji" "$*"
}

log "🗃️" "Arquivando repositórios antigos..."
printf '====================================%s\n' ""

REPOS=(
  "matverse-explore"
  "SymbiOS-public"
)

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  log "❌" "GITHUB_TOKEN não definido."
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  log "❌" "curl não encontrado."
  exit 1
fi

for repo in "${REPOS[@]}"; do
  log "📦" "Arquivando $repo..."

  response=$(curl -s -o /tmp/github-archive-response.json -w "%{http_code}" \
    -X PATCH \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/xMatVerse/$repo" \
    -d '{"name":"'$repo'-archived", "archived":true}')

  if [[ "$response" != "200" ]]; then
    log "❌" "Falha ao arquivar $repo (HTTP $response). Consulte /tmp/github-archive-response.json."
    continue
  fi

  issue_response=$(curl -s -o /tmp/github-archive-issue.json -w "%{http_code}" \
    -X POST \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/xMatVerse/$repo-archived/issues" \
    -d '{"title":"Repository Archived", "body":"This repository has been archived and consolidated into [xMatVerse monorepo](https://github.com/xMatVerse/xMatVerse). All future development will occur in the monorepo."}')

  if [[ "$issue_response" != "201" ]]; then
    log "⚠️" "Repositório arquivado, mas não foi possível criar o aviso (HTTP $issue_response)."
  else
    log "✅" "$repo arquivado"
  fi
done

log "🎉" "Arquivamento concluído!"
log "📝" "Todos os repositórios foram consolidados no monorepo xMatVerse"

