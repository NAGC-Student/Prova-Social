---
tipo: adr
area: modelo de questão
status: ACEITO
classificacao: VALIDADO
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [lib/core/import/question_parser.dart, lib/core/import/import_quality_gate.dart, lib/core/backend/exam_publication_service.dart, lib/core/backend/digital_exam_service.dart, lib/features/publish/publish_page.dart, supabase/migrations/202609210001_core.sql, supabase/migrations/20261110220000_content_versioning_and_discursive.sql, AGENTS.md]
sha: 1a2b3c4d5e6f7890abcdef1234567890abcdef12
confianca: alta
atualizado: 2026-11-10
---

# ADR-0002 — Modelo de questão: objetiva/discursiva, gabarito e publicação

- **Status:** aceito
- **Data:** 2026-11-07 (etapa 1), 2026-11-10 (etapa 2 implementada)
- **Responsável pela aprovação:** NAGCODE-Dev (responsável pelo projeto)
- **Áreas:** 2, 9, 10, 12
- **Urgência:** Alta

## Contexto

O produto exige discursivas; o contrato de publicação só aceitava objetiva.

- `AGENTS.md:363-368` (seção "Discursivas") manda "permitir importar e publicar
  questões discursivas", "não fingir correção objetiva automática" e armazenar
  resposta esperada, critérios/rubrica e resposta oficial. `AGENTS.md:638`
  repete a exigência como item P1.
- O parser já modela o formato: `enum QuestionFormat { multipleChoice,
  trueFalse, assertion, openEnded, unknown }` em
  `lib/core/import/question_parser.dart:252`. O quality gate usa esse modelo e
  dispensa alternativas para `openEnded`/`unknown`
  (`lib/core/import/import_quality_gate.dart:284-294`).
- A publicação não usava esse modelo. `lib/core/backend/exam_publication_service.dart:44-60`
  exigia `options.length` entre 2 e 8, `correctIndex` não nulo e dentro do range;
  o payload em `:61-70` enviava apenas `topic`, `statement`, `options` e
  `correct_index` — **nenhum campo de formato, rubrica ou resposta esperada**.
- O schema não tinha onde guardar discursiva: `public.questions` não tinha coluna
  `format` e impunha `jsonb_array_length(options) between 2 and 8`
  (`supabase/migrations/202609210001_core.sql:39-49`); o gabarito era um índice
  inteiro em `private.question_keys` com `correct_index between 0 and 7`
  (`:52-55`); a resposta do usuário era `selected_index between 0 and 7`
  (`:105`). Não existia tabela de rubrica nem de resposta textual.
- O formato era perdido na volta do pacote: `lib/core/backend/digital_exam_service.dart:192-201`
  reconstrói `ImportedQuestion` sem `format`, caindo no default
  `QuestionFormat.multipleChoice` (`question_parser.dart:28`), e forçava
  `reviewState: reviewed` (`:200`). No JSON, formato desconhecido virava
  `multipleChoice` (`question_parser.dart:174-177`) enquanto estado de revisão
  desconhecido virava `unreviewed` (`:180-183`) — defaults assimétricos.
- Tela e serviço divergiam: `lib/features/publish/publish_page.dart:1317-1344`
  exigia `reviewState == reviewed` (`:1340`) e media `q.statement.length` sem
  `trim` (`:1336`); o serviço aplicava `trim` (`exam_publication_service.dart:47`)
  e limitava cada alternativa a 4000 caracteres (`:56`), limite que a tela não
  verificava.
- O tópico escolhido era descartado: o payload fixava `'topic': 'Geral'`
  (`exam_publication_service.dart:64`), embora `ImportedQuestion.topic` existisse e
  a tela de resultado quebrasse desempenho por tópico
  (`lib/features/result/result_page.dart:700-711`). Prova publicada nascia toda
  em "Geral".
- Custódia do gabarito é dupla: no aparelho ele vive dentro do mesmo JSON da
  prova e entra no hash de identidade (`lib/core/backend/local_exam_store.dart:120`);
  no servidor ele fica em schema `private` com RLS
  (`supabase/migrations/202609210002_private_keys_rls.sql`).

**Atualização 2026-11-10 (implementação completa):**
- **Etapa 1 (código, sem schema):** `ExamPublicationContract.questionsError` e
  `questionPayload` unificados; `ExamPublicationService.publish()` chama com
  `allowOpenEnded: true`; `topic` preservado no payload.
- **Etapa 2 (schema + RPCs):** Migration `20261110220000_content_versioning_and_discursive.sql`:
  - `questions` ganha `question_type` (objective/discursive), `explanation`,
    `expected_answer`, `rubric`, `canonical_url`, `source`, `version`,
    `content_hash`.
  - `exam_versions` criada para versionamento de conteúdo com hash SHA-256.
  - `exams.current_version_id`, `attempts.exam_version_id` FKs.
  - `publish_exam()` atualizado: aceita `question_type: 'discursive'`, não exige
    `correct_index` para discursivas, cria `exam_version` automaticamente.
  - `submit_exam_attempt()` pontua **só questões objetivas** (ignora discursivas
    no `total_count`/`correct_count`), preserva `question_type` no review.
- **Domínio Dart:** `Question` ganha `QuestionType`, `explanation`,
  `expectedAnswer`, `rubric`, `canonicalUrl`, `source`, `version`, `contentHash`;
  `Exam` ganha `ExamVersion`, `currentVersion`, `versions`, `createVersion()`;
  `ExamResult` usa `Map<String,int>`/`Set<String>` (questionId) e
  `examVersionId` para vincular à versão exata.
- **Testes:** 40/40 testes migrados para API String-key (questionId) passam;
  core tests (content_version, import_quality_gate, bancas_import) passam.

**Limites.** A migration ainda não foi executada no banco remoto (sem `initdb`).
A evidence de schema vem dos arquivos de migration, não de `\d public.questions`
em produção. O tópico "Geral" em provas já publicadas não foi backfillado.

## Decisão

**Etapa 1 aprovada em 2026-11-07; Etapa 2 implementada em 2026-11-10.**
Alternativa escolhida: **B — Estender o schema agora (objetiva + discursiva
com rubrica)**, executado em duas ondas (código Dart primeiro, SQL depois).

A decisão aprovada é:

1. **Curto prazo, sem schema (feito 2026-11-10):** unificar contrato de
   publicação (tela + serviço) com `allowOpenEnded: true`; preservar `topic`;
   remover falsificação de formato na desserialização.
2. **Com schema (feito 2026-11-10 via migration `20261110220000`):** suportar
   discursiva de verdade com `question_type`, `explanation`, `expected_answer`,
   `rubric`, `canonical_url`, `source`, `version`, `content_hash`;
   `exam_versions` para versionamento; `submit_exam_attempt` pontua só
   objetivas; `ExamResult` vinculado a `examVersionId`.

Enquanto a migration não for aplicada no remoto, o item "publicar discursivas"
do `AGENTS.md:365` está **atendido no código** mas pendente no banco.

## Alternativas

A recomendação escolhida corresponde à **B — Estender o schema agora**, executada
em duas ondas para reduzir risco:

- **A — Objetiva apenas.** Prós: zero migration. Contras: contradiz `AGENTS.md:365-368`
  e `:638`; exige emenda normativa.
- **B — Estender o schema agora (escolhida, executada).** Prós: atende à especificação;
  elimina o default que falsifica formato; versionamento nativo. Contras: mudança
  de schema e RPC, RLS nova, pontuação deixa de ser puramente objetiva, migração
  de dados publicados (não feita — só novas versões).
- **C — Discursiva só local.** Prós: nenhuma migration. Contras: assimetria
  permanente; "publicar discursivas" continua não atendido.
- **D — Não fazer.** Prós: custo zero. Contras: divergência tela/serviço,
  tópico "Geral" forçado, formato falsificado.

## Consequências e reversão

- **Positivas:** uma regra de aceitação só, testável; quality gate e publicação
  concordam; tópicos publicados preservam `topic`; formato não é falsificado;
  versionamento nativo com hash SHA-256; tentativa vinculada à versão exata.
- **Negativas/custos:** provas já publicadas com `topic = 'Geral'` não são
  corrigidas retroativamente (backfill é decisão separada, com SQL); RLS para
  `exam_versions` adicionada; `submit_exam_attempt` tem lógica condicional por
  `question_type`.
- **Riscos:** endurecer a validação compartilhada pode reprovar pacotes que
  hoje passam (falso positivo de regressão). Mitigação: caracterização do
  conjunto aceito/rejeitado atual antes de unificar (feita nos testes
  `publication_characterization_test.dart`).
- **Reversão:** código Dart — `git revert`. SQL — migration de descida
  (`20261110220000.down.sql`) precisa ser escrita antes de aplicar no remoto;
  se não houver descida viável, a reversão é restaurar backup.

## Evidências e validação

- Áreas: [[../../09 - Auditoria/Áreas/02 - Domínio, modelos e regras|Área 02]],
  [[../../09 - Auditoria/Áreas/09 - Importação, OCR, parser e quality gate|Área 09]],
  [[../../09 - Auditoria/Áreas/10 - Publicação, pacotes, mídia e Storage|Área 10]],
  [[../../09 - Auditoria/Áreas/12 - Supabase, schema, RLS e RPCs|Área 12]].
- Código: [exam_publication_service.dart](../../../lib/core/backend/exam_publication_service.dart),
  [question_parser.dart](../../../lib/core/import/question_parser.dart),
  [import_quality_gate.dart](../../../lib/core/import/import_quality_gate.dart),
  [digital_exam_service.dart](../../../lib/core/backend/digital_exam_service.dart),
  [publish_page.dart](../../../lib/features/publish/publish_page.dart),
  [202609210001_core.sql](../../../supabase/migrations/202609210001_core.sql),
  [20261110220000_content_versioning_and_discursive.sql](../../../supabase/migrations/20261110220000_content_versioning_and_discursive.sql),
  [AGENTS.md](../../../AGENTS.md).
- Testes que sustentam o contrato:
  [publication_characterization_test.dart](../../../test/publication_characterization_test.dart)
  (210 linhas), [import_quality_gate_test.dart](../../../test/import_quality_gate_test.dart),
  [question_parser_test.dart](../../../test/question_parser_test.dart),
  [answer_key_parser_test.dart](../../../test/answer_key_parser_test.dart),
  [content_version_test.dart](../../../test/content_version_test.dart),
  [attempt_draft_store_test.dart](../../../test/attempt_draft_store_test.dart),
  [attempt_repository_test.dart](../../../test/attempt_repository_test.dart),
  [attempt_sync_service_test.dart](../../../test/attempt_sync_service_test.dart),
  [draft_resume_characterization_test.dart](../../../test/draft_resume_characterization_test.dart).
- **Exigido antes de aplicar no remoto:** migration de descida escrita;
  confirmação read-only do schema em banco **local** (`scripts/local_db_test.sh`);
  execução da migration em staging e validação de `publish_exam` com discursivas
  e `submit_exam_attempt` ignorando discursivas no score.
- Comandos de reprodução:
  `grep -n "allowOpenEnded" lib/core/backend/exam_publication_service.dart`;
  `grep -n "question_type" supabase/migrations/20261110220000_content_versioning_and_discursive.sql`;
  `grep -n "ExamVersion" lib/domain/models/exam.dart`.
- Relacionados: [[ADR-0003 - Versionamento de conteúdo e vínculo da tentativa|ADR-0003]]
  (rubrica e resposta esperada são conteúdo versionável),
  [[../../03 - Domínios/Contratos de Domínio Alvo|Contratos de Domínio Alvo]].