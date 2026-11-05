---
tipo: area
area: domínios
status: PARCIAL
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [lib/domain/models/exam.dart, lib/core/backend/]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: media
atualizado: 2026-11-05
---

# Fluxos Principais

Esta nota era o placeholder da Fase 2. O conteúdo que ela prometia desenhar foi
medido e está em três notas:

- [[../02 - Arquitetura/Fluxos Reais]] — os quatro fluxos executados no código,
  com estados de falha (F1 importação, F2 tentativa e fila, F3 publicação,
  F4 consumo).
- [[Modelo de Domínio Atual]] — as entidades e campos que hoje existem, e onde a
  política está espalhada.
- [[Contratos de Domínio Alvo]] — os contratos C1–C7 que esses fluxos precisam
  para virar base de um app novo.

## Entidades observadas

O modelo central está em `lib/domain/models/exam.dart` — 1 arquivo, 236 linhas,
importado por 15 arquivos. Backend organiza tentativa, importação, publicação,
mídia e entrega em 18 arquivos (`lib/core/backend/`, 3.160 linhas). A fronteira
entre eles está medida em [[../02 - Arquitetura/Mapa de Dependências]].

## Estado por caminho

1. Importar: arquivo → extração → perfil de layout → parser → gabarito → quality
   gate → revisão → rascunho. **Composição dentro da tela**
   (`publish_page.dart:472-522`), não em serviço. Ver
   [[../09 - Auditoria/Áreas/09 - Importação, OCR, parser e quality gate|área 9]].
2. Resolver: prova → rascunho local serializado → fila por `clientAttemptId` com
   6 estados e backoff 30→3600 s → resultado. Contrato maduro, documentado em
   [[../02 - Arquitetura/Fluxos Reais]].
3. Publicar/consumir: validação duplicada (tela × serviço), `source_type` fixo,
   download com `reviewState` forçado, entrega por gzip + sha256 verificado.

Os desenhos referenciam arquivos e métodos reais. Nenhum dado de prova ou
credencial foi copiado como exemplo.

## Fonte

[AGENTS.md — fluxo principal](../../AGENTS.md) e
[[../02 - Arquitetura/Mapa de Módulos]].
