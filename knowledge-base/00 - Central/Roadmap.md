---
tipo: area
area: roadmap
status: INTENÇÃO
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: []
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: alta
atualizado: 2026-11-07
---

# Roadmap

Este roadmap acompanha o [Plano Mestre](Plano%20Mestre.md). As prioridades não
autorizam alteração de código sem tarefa explícita; dependências arquiteturais
exigem evidência e ADR aprovado.

| Ordem | Fase | Resultado esperado | Estado |
|---:|---|---|---|
| 1 | Auditoria e congelamento | Baseline, inventário, CI, docs e pendências mensurados | **Concluída:** 18 áreas auditadas, 18 notas e [[../09 - Auditoria/Síntese da Refatoração\|síntese global]]. |
| 2 | Obsidian e arquitetura | Vault, fluxos reais, dependências e ADRs | **Parcial (avançou):** [[../02 - Arquitetura/Fluxos Reais|fluxos reais]], [[../02 - Arquitetura/Mapa de Dependências|dependências medidas]], [[../03 - Domínios/Modelo de Domínio Atual|domínio atual]] e [[../04 - Infraestrutura/Inventário de Persistência e Dados|persistência]] prontos; [[../03 - Domínios/Contratos de Domínio Alvo|contratos alvo C1–C7]] especificados; vault versionado (`eebb2b0`) e caracterização de pontuação/publicação/rascunho executada (`ff3be0c`). Os 12 ADRs foram **aceitos em 2026-11-07** ([[../06 - Decisões/ADR/README|índice]]); a única decisão aberta é a licença do app no ADR-0007. Faltam, no [[../05 - Qualidade/Critério de Prontidão para Refatoração Global|gate]]: SQL solto promovido a migrations com `local_db_test.sh` no CI, caracterização da tela de publicação e do `QuizPage`, `integration_test/`. O PR que levava tudo ao `main` do upstream **foi mesclado** (`2c62e30`). |
| 3 | Fundação e confiabilidade | Persistência transacional, migração reversível e testes de falha | **Não iniciada;** ADR-0004 aceito em 2026-11-07; falta tarefa de implementação autorizada. |
| 4 | Refatoração modular | Extrair responsabilidades mantendo comportamento/contratos | **Não iniciada;** depende de testes de caracterização e contratos de domínio. |
| 5 | Importação e OCR | Fixtures autorizadas, ground truth e regressões mensuráveis | **Parcial:** auditoria profunda concluída e escopo P1.0–P1.3 fechado. Faltam câmera, feedback, discursivas na publicação e validação em aparelho. |
| 6 | Modelo e publicação | Questões mistas e sem gabarito, tópico/procedência preservados | **Pendente;** é pré-requisito de importação avançada e social. |
| 7 | Versionamento | Tentativa ligada à versão exata do conteúdo resolvido | **Pendente;** ADR-0003 aceito em 2026-11-07; falta tarefa de implementação autorizada. |
| 8 | Motor de aprendizagem | Revisão determinística e comparação de evolução | **Parcial;** prática local de erros existe, cobertura histórica precisa de contrato. |
| 9 | Observabilidade | Medidas úteis sem coletar conteúdo privado | **Pendente;** nenhum plano de telemetria aprovado. |

## Bloqueios conhecidos

- `main` estava vermelha por formatação em três probes — **resolvido**: Lote 0 e
  PR #19 mesclados em `2c62e30`, "QA Completo" `success` no run de `main`
  (`42088224910`).
- ~~Vault ainda não rastreado no Git~~ — versionado desde `eebb2b0`.
- **ADRs:** os 12 foram **aceitos em 2026-11-07**; a única decisão de produto
  ainda aberta no índice é a licença do app (ADR-0007). Aceitar não implementa:
  cada decisão continua exigindo tarefa própria autorizada.
- Persistência: as provas privadas **já são arquivo atômico** atrás de um port
  (`ExamPayloadStorage`, temp + flush + rename + backup); quatro stores seguem em
  `SharedPreferences` (rascunho, fila de sync, timer, buscas recentes).
  [[../06 - Decisões/ADR/ADR-0004 - Persistência local e durabilidade|ADR-0004]]
  foi **aceito em 2026-11-07**: estender o port, não SQLite agora. A
  implementação continua pendente de tarefa autorizada.
- Supabase remoto, políticas aplicadas e produção não foram verificados.
- Identidade dividida entre app, site e `AGENTS.md`: ADR-0001 e ADR-0012
  aceitos em 2026-11-07; implementação pendente.
- Release sem APK universal e site sem detecção de ABI: ADR-0005 aceito em
  2026-11-07; implementação pendente.
- Benchmark EPCAR/AFA carece de arquivos e ground truth autorizados.
- O fixture VUNESP permanece no repositório sob a política atual
  (`not-verified`, somente teste); o destino futuro e a licença do app seguem
  em aberto no ADR-0007.
- Licença do aplicativo: única decisão de produto ainda em aberto no ADR-0007.
- O contrato social (comunidades, denúncia, moderação) ainda não existe:
  ADR-0010 aceito em 2026-11-07 (moderação mínima primeiro; comunidades depois).

Atualizar esta nota após cada fase concluída e manter
[[../08 - Agentes/Progresso|Progresso]] sincronizado.
