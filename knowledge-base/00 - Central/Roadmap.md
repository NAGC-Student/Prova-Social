---
tipo: area
area: roadmap
status: INTENÇÃO
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: []
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: alta
atualizado: 2026-11-05
---

# Roadmap

Este roadmap acompanha o [Plano Mestre](Plano%20Mestre.md). As prioridades não
autorizam alteração de código sem tarefa explícita; dependências arquiteturais
exigem evidência e ADR aprovado.

| Ordem | Fase | Resultado esperado | Estado |
|---:|---|---|---|
| 1 | Auditoria e congelamento | Baseline, inventário, CI, docs e pendências mensurados | **Concluída:** 18 áreas auditadas, 18 notas e [[../09 - Auditoria/Síntese da Refatoração\|síntese global]]. |
| 2 | Obsidian e arquitetura | Vault, fluxos reais, dependências e ADRs | **Parcial (avançou):** [[../02 - Arquitetura/Fluxos Reais|fluxos reais]], [[../02 - Arquitetura/Mapa de Dependências|dependências medidas]], [[../03 - Domínios/Modelo de Domínio Atual|domínio atual]] e [[../04 - Infraestrutura/Inventário de Persistência e Dados|persistência]] prontos; [[../03 - Domínios/Contratos de Domínio Alvo|contratos alvo C1–C7]] especificados; vault versionado (`eebb2b0`) e caracterização de pontuação/publicação/rascunho executada (`ff3be0c`). Faltam, no [[../05 - Qualidade/Critério de Prontidão para Refatoração Global|gate]]: ADR-0002/0003/0004 aceitos, SQL solto promovido a migrations com `local_db_test.sh` no CI, caracterização da tela de publicação e do `QuizPage`, `integration_test/`. O PR que levava tudo ao `main` do upstream **foi mesclado** (`2c62e30`). |
| 3 | Fundação e confiabilidade | Persistência transacional, migração reversível e testes de falha | **Não iniciada;** depende de ADR de persistência. |
| 4 | Refatoração modular | Extrair responsabilidades mantendo comportamento/contratos | **Não iniciada;** depende de testes de caracterização e contratos de domínio. |
| 5 | Importação e OCR | Fixtures autorizadas, ground truth e regressões mensuráveis | **Parcial:** auditoria profunda concluída e escopo P1.0–P1.3 fechado. Faltam câmera, feedback, discursivas na publicação e validação em aparelho. |
| 6 | Modelo e publicação | Questões mistas e sem gabarito, tópico/procedência preservados | **Pendente;** é pré-requisito de importação avançada e social. |
| 7 | Versionamento | Tentativa ligada à versão exata do conteúdo resolvido | **Pendente;** depende de ADR de versionamento. |
| 8 | Motor de aprendizagem | Revisão determinística e comparação de evolução | **Parcial;** prática local de erros existe, cobertura histórica precisa de contrato. |
| 9 | Observabilidade | Medidas úteis sem coletar conteúdo privado | **Pendente;** nenhum plano de telemetria aprovado. |

## Bloqueios conhecidos

- `main` estava vermelha por formatação em três probes — **resolvido**: Lote 0 e
  PR #19 mesclados em `2c62e30`, "QA Completo" `success` no run de `main`
  (`42088224910`).
- ~~Vault ainda não rastreado no Git~~ — versionado desde `eebb2b0`.
- Persistência atual em JSON/`SharedPreferences` requer ADR antes de SQLite.
- Supabase remoto, políticas aplicadas e produção não foram verificados.
- Identidade dividida entre app, site e `AGENTS.md` exige ADR de paleta/tema.
- Release sem APK universal e site sem detecção de ABI.
- Benchmark EPCAR/AFA carece de arquivos e ground truth autorizados.
- O fixture VUNESP está versionado com licença não verificada; decidir se
  permanece no repositório e como o QA local é autorizado.
- Licença do aplicativo precisa de decisão do responsável.
- O contrato social (comunidades, denúncia, moderação) ainda não existe.

Atualizar esta nota após cada fase concluída e manter
[[../08 - Agentes/Progresso|Progresso]] sincronizado.
