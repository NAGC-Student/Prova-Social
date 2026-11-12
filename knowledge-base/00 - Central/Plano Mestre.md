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

# Plano Mestre de reconstrução orientada por auditoria

Fonte do plano: [[Fontes/Plano de Ação Mestre - fonte original]], fornecido
pelo responsável. O plano original é referência de execução; suas afirmações
precisam de evidência. O SHA abaixo é a baseline, não uma afirmação de que o
plano foi aprovado em todos os detalhes. Ver também [[Roadmap]].

## Princípios de execução

- Um lote pequeno por vez; preservar comportamento e contratos.
- Testes de caracterização antes de refatorações.
- Não apagar persistência antiga antes de provar migração e fallback.
- Nenhum gabarito inferido; separar gabaritos oficiais.
- Fazer da Fase 1 uma fotografia mensurável antes de arquitetura/código.
- Código, dados privados e segredos não entram como anexos do vault.
- Mudanças, commits, pushes, releases e decisões jurídicas dependem de
  autorização explícita.

## Fases e estado

| Fase | Objetivo | Estado em 2026-11-11 |
|---|---|---|
| 1. Auditoria e congelamento | Estado real, testes, CI, documentação e licença | **Concluída:** baseline medida, 18 áreas auditadas, 18 notas e síntese global. Licença **decidida em 2026-11-07** (distribuição restrita, todos os direitos reservados — ADR-0007, `LICENSE` na raiz); ground truth autorizado continua pendente de decisão externa. |
| 2. Obsidian e arquitetura | Vault, fluxos, módulos e ADRs | **Concluída:** vault funcionando, auditoria profunda concluída e 12 ADRs **aceitos em 2026-11-07** ([[../06 - Decisões/ADR/README|índice]]); arquitetura-alvo especificada, implementação em ondas autorizada. |
| 3. Fundação e confiabilidade | Persistência transacional SQLite, migração gradual e testes | **Não iniciada;** [[../06 - Decisões/ADR/ADR-0004 - Persistência local e durabilidade|ADR-0004]] aceito em 2026-11-07 (estender o port, sem SQLite agora); implementação pendente de tarefa autorizada. |
| 4. Refatoração modular | Separar responsabilidades preservando API | **Não iniciada;** depende dos contratos de domínio e dos testes de caracterização. |
| 5. Importação e OCR | Métricas e fixtures autorizadas e transversais | **Parcial (P1.0 concluído):** auditoria profunda concluída e escopo P1.0–P1.3 fechado; benchmark nativo de texto existe, mas ground truth autorizado, OCR nativo e feedback remoto não foram validados; câmera saiu do escopo por decisão (ADR-0006). UI sem porcentagem implementada (P0-1). |
| 6. Modelo de questões e publicação | Tipos, questões sem gabarito e tópico preservado | **Concluído (código):** objetiva/discursiva (`question_type`), `exam_versions`, `expected_answer`, `rubric`, `canonical_url`, `source`, `version`, `content_hash` (migration `20261110220000`); `allowOpenEnded: true` permite publicação de discursivas; `topic` preservado no payload. Pendente de aplicação no banco remoto. |
| 7. Versionamento de conteúdo | Tentativa vinculada à versão resolvida | **Concluído (código):** `ExamVersion`, `ExamResult.examVersionId`, `answers`/`markedForReview` migrados para `Map<String,int>`/`Set<String>` (questionId). Pendente de aplicação no banco remoto. |
| 8. Motor de aprendizagem | Revisões determinísticas e evolução | **Parcial:** prática local de erros já está implementada; cobertura sincronizada e histórica requer auditoria. |
| 9. Observabilidade | Medidas agregadas sem conteúdo sensível | **Pendente;** nenhum plano de telemetria aprovado. |

## Sequência recomendada após a auditoria

1. **Lote 0 — destravar a esteira:** formatar ou retirar os probes da suíte,
   remover caminhos absolutos, ligar testes do site e conferir `main` verde.
2. **Lote 1 — fonte única e decisões:** corrigir a numeração do `AGENTS.md`,
   versionar o vault, marcar documentos históricos e decidir a licença do app
   (ADR-0007). Os 12 ADRs de identidade, domínio, persistência e distribuição
   foram **aceitos em 2026-11-07**.
3. **Lote 2 — contratos de domínio, publicação e backend:** objetiva/discursiva,
   gabarito, versão, tema/procedência, RLS social e `publish_exam`.
4. **Lote 3 — tentativa, Focus e offline:** teste ponta a ponta, timer, revisão,
   retomada após crash e conflito.
5. **Lote 4 — importação e OCR:** P1.1–P1.3, timeout/health check do Paddle,
   benchmark com ground truth (UI sem porcentagem e discursivas já feitas).
6. **Lote 5 — identidade e componentes:** paleta única, Inter, `ExamListTile`
   (já implementado), breakpoints, goldens, contraste e alvo de 48 px.
7. **Lote 6 — distribuição e supply chain:** APK universal, checksums, SBOM,
   site por ABI, tag/changelog, CSP e orçamento de tamanho.
8. **Lotes 7 e 8 — social e observabilidade:** comunidades, denúncia, moderação,
   RLS e métricas de performance sem conteúdo sensível.

A ordem completa, com pré-condições e critérios de saída, está em
[[../09 - Auditoria/Síntese da Refatoração|Síntese da Refatoração]].

## Critérios de parada por tarefa

- Analyzer e testes necessários passam; formatação não pode ser contornada.
- Nenhuma resposta se perde em modo offline nem é enviada duas vezes.
- RLS e separação de gabaritos permanecem.
- Reversão e dependências documentadas.
- Sem segredos, conteúdo privado ou decisões não aprovadas no log/vault.

## Links

- [Diretrizes de produto e desenvolvimento](../../AGENTS.md)
- [[Estado Atual]]
- [[../09 - Auditoria/Síntese da Refatoração|Síntese da Refatoração]]
- [[../09 - Auditoria/Hipóteses|Hipóteses a confirmar]]
