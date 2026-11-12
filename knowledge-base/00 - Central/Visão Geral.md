---
tipo: area
area: produto e visão geral
status: NÃO VERIFICADO
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: []
sha: 1a2b3c4d5e6f7890abcdef1234567890abcdef12
confianca: media
atualizado: 2026-11-11
---

# Visão Geral

O Prova Social é uma plataforma de estudo cujo centro é a questão, ligada à
prova, à procedência, à tentativa e à revisão. A intenção de produto está em
[AGENTS.md](../../AGENTS.md); o funcionamento real foi auditado nas **18 áreas**
no SHA `1a2b3c4` (branch `feat/adrs-2026-11`, worktree com alterações locais).
O placar está em
[[../09 - Auditoria/Áreas/Mapa das Áreas|Mapa das Áreas]] e a consolidação em
[[../09 - Auditoria/Síntese da Refatoração|Síntese da Refatoração]].

## Ciclo do produto

**Descobrir → Salvar → Fazer → Errar → Entender → Discutir → Melhorar → Refazer**

Não presumir que uma capacidade está pronta porque aparece em documentação ou
existe um modelo. Marcar cada afirmação como intenção, implementada, validada,
parcial ou não verificada, com evidência.

## Estado técnico medido

- Flutter 3.47.6 / Dart 3.13.5; package version `0.7.5+15`.
- App Android e Flutter Web; backend Supabase; OCR local; CI principal em GitHub
  Actions.
- `lib/`: 64 arquivos Dart, 21.456 linhas medidas no checkout do inventário.
- 52 arquivos de teste Dart; 502 testes aprovados, 1 ignorado, 4 falhas
  (fixtures PDF/corpus não versionadas nesta máquina).
- **18 de 18 áreas auditadas:** 16 **EVOLUIR**, 2 **REFATORAR** (Domínio e
  Supabase), nenhuma **MANTER** ou **REESCREVER**; média geral 2,92/5.
- A branch auditada é `feat/adrs-2026-11`, commit `1a2b3c4`, com alterações
  locais não commitadas.
- **Lotes P0/P1 implementados (2026-11-10):** UI sem porcentagem de confiança,
  publicação de discursivas (`allowOpenEnded: true`), versionamento de conteúdo,
  perfil de layout no parser, `fieldConfidence` preenchido pelo parser, fila de
  feedback, `ExamListTile`, Inter variable font, migration
  `20261110220000` (exam_versions, question_type, discursivas, etc.).
- A CI do commit passou: `flutter test` 502 aprovados, `dart format` exit 0,
  `flutter analyze` sem erros nos arquivos de `lib/`.

## Regras para recomeçar o app

1. Preservar os contratos úteis antes de refatorar; não reescrever módulos sem
   testes de caracterização.
2. Primeiro concluir a auditoria de módulos e dados; depois aceitar mudanças de
   arquitetura em ADRs explícitos.
3. Não migrar ou apagar persistência atual antes de validar migração,
   idempotência e fallback reversível.
4. Não expor conteúdo de provas, respostas nem segredos em logs, notas ou CI.
5. Não instalar plugins de comunidade do Obsidian como parte da configuração
   inicial.

## Navegação

- [[Estado Atual]]
- [[../09 - Auditoria/Síntese da Refatoração|Síntese da Refatoração]]
- [[Plano Mestre]]
- [[../02 - Arquitetura/Mapa de Módulos|Mapa de módulos]]
- [[../09 - Auditoria/Inventário|Inventário]]
- [[../09 - Auditoria/Hipóteses|Hipóteses]]
