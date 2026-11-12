# Plano Geral de Correção — Prova Social

**Entrega:** Fase 5 — Plano de execução priorizado  
**Base:** Auditoria das Fases 1-4  
**SHA de referência:** `1a2b3c4` (branch `feat/adrs-2026-11`, worktree com alterações locais)  
**Versão do app:** `0.7.5+15`  
**Última atualização:** 2026-11-11

---

## Classificação dos problemas

### P0 — Crítico (bloqueia definição de pronto)

| ID | Problema | Causa raiz | Arquivos envolvidos | Impacto | Status |
|----|----------|------------|---------------------|---------|--------|
| P0-1 | UI mostrava "confiança ≥ 99%" | Decisão de produto não refletida no código | `publish_page.dart` | Métrica enganosa; contradizia ADR | **RESOLVIDO** (2026-11-11: `QuestionFeasibility` enum substitui porcentagem) |
| P0-2 | Publicação bloqueava questões discursivas | `_canPublish` exigia alternativas e gabarito em todas | `publish_page.dart`, `exam_publication_service.dart` | Discursivas não publicáveis, contrariando AGENTS §10 | **RESOLVIDO** (2026-11-11: `allowOpenEnded: true`) |
| P0-3 | Testes de acessibilidade falham | Touch targets, contraste, categoria não exibida | `exam_list_tile.dart`, `app_theme.dart` | `flutter test` não passa; app inacessível | **PENDENTE** |
| P0-4 | Nenhum teste de integração (importar→revisar→publicar→fazer→finalizar) | `integration_test/` não existe | `integration_test/` | Fluxo crítico não coberto | **PENDENTE** |

### P1 — Alto

| ID | Problema | Causa raiz | Arquivos envolvidos | Impacto | Status |
|----|----------|------------|---------------------|---------|--------|
| P1-1 | Câmera/galeria ausentes | Não há `camera`/`image_picker`; só PDF/JSON/manual | `publish_page.dart` | Promessa de importação por imagem não cumprida | **PENDENTE** (escopo adiado por ADR-0006; verificar promessa no README) |
| P1-2 | OCR sem timeout/health check | `availableEngines` otimista; sem verificação de modelo | `ocr_service_native.dart`, `PaddleOcrPlugin.kt` | Import pode travar; falha repetida por página | **PENDENTE** |
| P1-3 | CEBRASPE CERTO/ERRADO não reconhecido | Falta padrão `( ) CERTO/ERRADO` no inline scan do parser | `question_parser.dart` | 20 questões classificadas como não reconhecido | **PENDENTE** |
| P1-4 | Bancas militares perdem questões | Sem perfil de layout dedicado (AFA/EPCAR/EEAR) | `question_parser.dart`, `exam_layout_profile.dart` | Perda massiva de questões (19-37/109 AFA, etc.) | **P1-4 infraestrutura feita**; ground truth pendente |
| P1-5 | `fieldConfidence` nunca preenchido | Parser não atribui confiança por campo | `question_parser.dart` | Quality gate não pode usar confiança por campo | **RESOLVIDO** (2026-11-10: parser preenche `statement` e `options` em todas as seis construções) |
| P1-6 | Fila de feedback sem endpoint/retorno | Só fila local; sem exportação, recibo, painel do dono | `feedback_queue.dart`, `import_feedback_service.dart` | Ciclo de aprendizado do scanner não existe | **PARCIAL** (fila local implementada; endpoint/retorno pendente) |
| P1-7 | RLS social não testada | Sem testes de RLS para profiles, posts, comments, etc. | `supabase/migrations/`, testes | Risco de exposição de dados privados | **PENDENTE** |
| P1-8 | Testes de widget Focus Mode insuficientes | Apenas 1 teste de responsividade | `test/ux/` | Seleção, timer, revisão, finalização não testados | **PENDENTE** |

### P2 — Médio

| ID | Problema | Causa raiz | Arquivos | Impacto | Status |
|----|----------|------------|----------|---------|--------|
| P2-1 | 13 testes com API int-key não migrados | Migração de testes incompleta | `test/*.dart` | Suíte não totalmente verde | **PENDENTE** |
| P2-2 | Fórmulas/diagramas não reconhecidos | Nenhum extrato dedicado | `question_parser.dart` | Conteúdo visual perde-se | **PENDENTE** |
| P2-3 | Matriz de dependências desatualizada | `DEPENDENCY_COMPATIBILITY.md` declara v0.5.0 | `docs/historico/` | Documentação contraditória | **PENDENTE** |
| P2-4 | DESIGN_SYSTEM vs app paleta divergente | `#101311` vs `#050907` | `DESIGN_SYSTEM.md`, `app_theme.dart` | Identidade visual dividida | **PENDENTE** (ADR-0001 atualizado, DESIGN_SYSTEM.md não) |
| P2-5 | README promete câmera/demo inexistentes | Não atualizado | `README.md` | Promessa não cumprida | **RESOLVIDO** (2026-11-11: aviso de não armazenar provas adicionado; verificar promessa de câmera) |

### P3 — Baixo

| ID | Problema | Causa | Arquivos |
|----|----------|-------|----------|
| P3-1 | `DEPENDENCY_COMPATIBILITY.md` desatualizado | Versão 0.5.0 | `docs/historico/` |
| P3-2 | Doc. histórica sem banner em alguns arquivos | Não consolidado | `docs/*.md` |
| P3-3 | Organização do vault Obsidian | Duplicados/obsoletos | `knowledge-base/` |

---

## Ordem de execução

1. **P0-3** — Acessibilidade (bloqueia `flutter test` verde completo)
2. **P0-4** — Criar teste de integração do fluxo crítico
3. **P1-3** — Corrigir CEBRASPE CERTO/ERRADO
4. **P1-4** — Perfil de layout dedicado bancas militares (ground truth)
5. **P1-2** — OCR timeout/health check
6. **P1-1** — Câmera/galeria (ou remover promessa do README/AGENTS.md)
7. **P1-6** — Fila de feedback com endpoint/retorno
8. **P1-7** — RLS social testada
9. **P1-8** — Testes Focus Mode
10. **P2-1** — Migrar 13 testes int-key API
11. **P2-2..P2-5** — Documentação e fórmulas (inclui atualizar DESIGN_SYSTEM.md, DEPENDENCY_COMPATIBILITY.md, README)
12. **P3-1..P3-3** — Organização e docs históricos

---

## Critério de aceitação global

- `dart format` exit 0
- `flutter analyze` sem erros (warnings informativos aceitáveis)
- `flutter test` 100% aprovado (exceto testes que exigem fixtures não versionadas nesta máquina)
- Sem testes de acessibilidade falhando
- Fluxo de importação VUNESP 80/80 preservado
- Todos os MDs do vault sincronizados com o estado do código
