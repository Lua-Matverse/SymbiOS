# SymbiOS

SimbiOS/LUA é a ponte entre a intenção humana e a execução tecnológica, redefinindo a interação com sistemas.

## 📦 Scripts de Consolidação e Operação

Este repositório agora contém uma suíte completa de scripts para apoiar a consolidação do ecossistema MatVerse em um monorepo e orquestrar suas operações:

- `scripts/consolidation/migrate-to-monorepo.sh` — executa a migração automatizada dos repositórios legados para a estrutura consolidada.
- `scripts/consolidation/archive-repositories.sh` — automatiza o arquivamento dos repositórios antigos no GitHub.
- `scripts/verification/verify-consolidation.sh` — valida se a estrutura do monorepo está íntegra e se os builds essenciais funcionam.
- `scripts/verification/verify-lakehouse.sh` — verifica a saúde do ambiente Lakehouse local, incluindo MinIO, Trino e Redis.
- `scripts/verification/final-checklist.sh` — checklist interativo antes da liberação para produção.
- `scripts/verification/verify-deployment.sh` — confirma o estado do deploy em clusters Kubernetes.
- `scripts/deployment/deploy-production.sh` — empacota imagens Docker e aplica as configurações de infraestrutura para o ambiente desejado.
- `scripts/status/healthcheck.sh` — gera um relatório rápido de saúde da stack.
- `scripts/quickstart.sh` — realiza a inicialização rápida da infraestrutura local com Docker Compose.
- `scripts/start-with-fallback.sh` — inicializa os serviços com retentativas e geração de logs para cada componente.
- `scripts/quick-check.sh` — executa verificações rápidas de ambiente e pré-requisitos.
- `scripts/test/connectivity-test.sh` — valida conectividade externa e portas locais essenciais.
- `scripts/troubleshooting/diagnose-fix.sh` — diagnostica o ambiente e aplica correções automáticas.
- `scripts/troubleshooting/fix-common-issues.sh` — corrige problemas recorrentes como permissões e dependências quebradas.
- `scripts/debug/generate-debug-report.sh` — consolida informações de sistema e logs para análise detalhada.

Cada script está documentado com comentários internos e valida pré-requisitos para evitar falhas silenciosas.
