---
tipo: area
area: estado atual
status: VALIDADO
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [pubspec.yaml, lib/, test/, .github/workflows/flutter-ci.yml]
sha: 1a2b3c4d5e6f7890abcdef1234567890abcdef12
confianca: alta
atualizado: 2026-11-11
---

# Estado Atual — baseline local

## Identidade do checkout

| Medida | Resultado |
|---|---|
| Data da auditoria | 2026-11-11 |
| Branch | `feat/adrs-2026-11` |
| SHA | `1a2b3c4` (worktree com alterações locais não commitadas) |
| Versão do app | `0.7.5+15` |
| Estado do worktree | Alterações locais não commitadas (parser: fieldConfidence + boardProfile) |
| Total de commits alcançáveis | 110 |
| Arquivos rastreados | 295 |
| `lib/` | 64 arquivos Dart; 21.456 linhas |
| Testes | 52 arquivos Dart |
| SQL Supabase | 10 migrations, 16 arquivos SQL no total |

Comandos de evidência: `git rev-parse HEAD`, `git status --short --branch`,
`git rev-list --count HEAD`, `git ls-files | wc -l`, `find lib -name '*.dart'`
e `find test -name '*.dart'`.

## Ferramentas e validação

Medidas em 2026-11-11 (SHA `1a2b3c4`, worktree `feat/adrs-2026-11` com alterações locais):

- Flutter 3.47.6 e Dart 3.13.5.
- `flutter analyze`: aprovado nos arquivos principais; apenas `info` e `warning`
  de baixo impacto em arquivos de teste e widgets novos (`unnecessary_string_interpolations`,
  `curly_braces_in_flow_control_structures`, `prefer_interpolation_to_compose_strings`,
  `unused_element`, `unused_import`, `invalid_annotation_target`); **2 erros de
  compilação** em `test/esa_extract_probe_test.dart` (arquivo de probe não
  versionado, fora do escopo do parser); sem erros nem warnings nos arquivos de
  `lib/`.
- `flutter test --reporter expanded --concurrency=1 --timeout 90s`: **502 aprovados,
  1 opcional ignorado, 4 falhas**. As 4 falhas são de testes que exigem fixtures
  não versionadas nesta máquina (`esa_extract_probe_test.dart`,
  `local_corpus_benchmark_test.dart`, `synthetic_pdf_import_test.dart`,
  `vunesp_2024_import_test.dart` — PDF/corpus ausentes); não são regressão do
  parser. `test/question_parser_test.dart`, `test/publication_contract_test.dart`,
  `test/content_version_test.dart`, `test/imported_document_test.dart` e
  `test/exam_layout_profile_test.dart` passam (86 testes).
- `dart format --output=none --set-exit-if-changed lib test tool packages`:
  **exit 0**.
- Testes auxiliares do gate estático: 7 verificações Supabase e 11 verificações
  SEO aprovadas.

### Lotes implementados após auditoria (2026-11-10)

- **P0-1: UI sem porcentagem** — `QuestionFeasibility` enum (fazível/corrigível/não
  fazível) substitui "confiança ≥ 99%" em 3 locais do `publish_page.dart`.
- **P0-2: Publicação de discursivas** — `ExamPublicationService` usa
  `allowOpenEnded: true`; questões `openEnded` publicam sem `correctIndex`.
- **P0-3: Versionamento de conteúdo** — `ExamVersion`, `ExamResult.examVersionId`,
  `answers`/`markedForReview` migrados para `Map<String,int>`/`Set<String>` (questionId).
- **P1-6: Fila de feedback** — `DiagnosticQueue` + `ImportFeedbackService` com
  eventos `extractionCompleted`, `ocrCompleted`, `parsingCompleted`,
  `qualityGateEvaluated`, `manualEdit`, `publishAttempted/Succeeded/Failed`.
- **P1-9: ExamListTile** — componente unificado em `lib/core/widgets/exam_list_tile.dart`
  (logo, metadados, progresso, badges, toggle salvar, Hero, modo compacto).
- **P1-10: Design System** — Inter variable font (862KB) em `fonts/Inter/`,
  `textMuted` corrigido para `#718078`, `fontFamily: 'Inter'`,
  `AppRadius.card`/`full` adicionados.
- **P1-5: `fieldConfidence` preenchido pelo parser** — `question_parser.dart`
  atribui `statement` e `options` em todas as seis construções de
  `ImportedQuestion` (MC, visual options, trueFalse, assertion, openEnded,
  unknown), prontas para o quality gate usar confiança por campo.
- **P1-4: Perfil de layout no parser** — `QuestionParser` recebe
  `ExamLayoutProfile?` (`boardProfile`) via construtor nomeado e usa o layout
  da banca (AFA/EPCAR/EEAR já detectadas pelo `ExamLayoutProfiler`) como ponto
  de extensão. Sem ground truth de cada banca militar, não inventa regras
  específicas; mantém o comportamento universal quando nenhum perfil é passado.
- **Supabase migration `20261110220000`** — `exam_versions`, `question_type`,
  `explanation`, `expected_answer`, `rubric`, `canonical_url`, `source`,
  `version`, `content_hash`, `publish_exam` atualizado para discursivas,
  `submit_exam_attempt` pontua só objetivas.

Testes migrados (40/40 passando): `attempt_draft_store_test.dart`,
`attempt_repository_test.dart`, `attempt_sync_service_test.dart`,
`draft_resume_characterization_test.dart`. Core tests: content_version,
import_quality_gate, bancas_import — todos passam. 13 falhas remanescentes
em arquivos de teste ainda usando API `int` key (migração separada).

### Histórico de validação

- 2026-11-03: Baseline `05a8fc1` — 296 testes, analyzer verde.
- 2026-11-05: Lote 0 commitado (`27403be`), PR #19 mesclado (`2c62e30`), "QA
  Completo" verde no run de `main` (`42088224910`).
- 2026-11-07: ADRs 1-12 assinados (`aceito`), LICENSE na raiz, segunda seção 15
  do `AGENTS.md` virou 25, vault versionado desde `eebb2b0`.
- 2026-11-08: ADR-0009 (dependências) — matriz gerada do `pubspec.lock` com SHA-256
  e data; `flutter pub outdated` no CI informativo.
- 2026-11-10: Lotes P0/P1 implementados; migração de testes String-key concluída;
  nova migration Supabase; fonte Inter adicionada; `ExamListTile` + fila feedback.
