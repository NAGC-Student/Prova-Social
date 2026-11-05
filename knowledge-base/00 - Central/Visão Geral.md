---
tipo: area
area: produto e visão geral
status: NÃO VERIFICADO
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: []
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: media
atualizado: 2026-11-04
---

# Visão Geral

O Prova Social é uma plataforma de estudo cujo centro é a questão, ligada à
prova, à procedência, à tentativa e à revisão. A intenção de produto está em
[AGENTS.md](../../AGENTS.md); o funcionamento real foi auditado nas **18 áreas**
no SHA `05a8fc1`. O placar está em
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
- `lib/`: 60 arquivos Dart, 19.113 linhas medidas no checkout do inventário.
- 48 arquivos de teste Dart; 296 testes passaram na última suíte local.
- **18 de 18 áreas auditadas:** 16 **EVOLUIR**, 2 **REFATORAR** (Domínio e
  Supabase), nenhuma **MANTER** ou **REESCREVER**; média geral 2,92/5.
- A branch auditada é `main`, commit
  `05a8fc1aab92d43f58ad7da8b24e710f9874d281`; checkout limpo.
- A CI do commit auditado falhou apenas no gate estático de formatação de três
  probes locais; ver [[Estado Atual]] e [[../05 - Qualidade/Validação Atual|Validação]].

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
