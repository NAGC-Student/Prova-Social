---
tipo: area
area: offline e sincronização
status: INTENÇÃO
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [lib/core/backend/attempt_draft_store.dart, lib/core/backend/attempt_sync_service.dart]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: media
atualizado: 2026-11-03
---

# Offline e sincronização

## Intenção

Respostas persistidas localmente a cada alteração; prova baixada utilizável
offline; fila de sincronização com retry idempotente; estados claros de salvo,
sincronizando e sincronizado; conflitos tratados explicitamente; finalização
resiliente a falhas de rede.

## Estado observado

Há stores locais e serviço de sincronização em `lib/core/backend/`. Os dados
parecem serializados via SharedPreferences/JSON em arquivos consultados, mas
troca de conta, migração, concorrência e durabilidade precisam de auditoria
dedicada antes de uma decisão SQLite.

## Fonte

[AGENTS.md — offline e sincronização](../../AGENTS.md) e
[[../04 - Infraestrutura/Dados e Segurança|dados e segurança]].
