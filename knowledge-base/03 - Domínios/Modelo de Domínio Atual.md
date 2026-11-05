---
tipo: area
area: domínio atual
status: VALIDADO
classificacao: REFATORAR
nivel: {correcao: 3, testes: 2, acoplamento: 2, clareza: 3, seguranca: 3, robustez: 2, aderencia: 2, portabilidade: 4}
fonte_codigo: [lib/domain/models/exam.dart, lib/core/import/, lib/core/backend/, lib/features/]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: alta
atualizado: 2026-11-05
---

# Modelo de domínio atual (medido, não proposto)

Inventário do que o código **já é** hoje. É o insumo para
[[Contratos de Domínio Alvo]]; nenhuma linha daqui autoriza mudança. Medidas no
worktree de 2026-11-05 (Lote 0 aplicado, ainda não commitado).

## Dimensão real

- `lib/domain/` tem **1 arquivo**: `lib/domain/models/exam.dart`, 236 linhas.
- Ele é importado por **15 arquivos** (maior fan-in do projeto), sendo 10 em
  `lib/features/` e 5 em `lib/core/backend/`.
- As outras 19.000 linhas do app vivem fora do domínio: 9.581 em `lib/features/`,
  3.160 em `lib/core/backend/`, 4.476 em `lib/core/import/`.

## Entidades e campos

| Entidade | Onde | Campos | Observação medida |
|---|---|---|---|
| `Exam` | `exam.dart:3-54` | id, category, title, description, author, uploaderName?, durationMinutes, attempts, year?, questions, sourceType, sourceUrl?, isLocal | `copyWith` só aceita `questions` e `year` (`exam.dart:39`): não há como atualizar versão ou procedência. |
| `ExamSourceType` | `exam.dart:56-66` | official, community, unverified | `fromDatabase` cai em `unverified` para qualquer valor desconhecido — silencioso. |
| `Question` | `exam.dart:68-94` | id (default `''`), topic, statement, options, correctIndex?, media | **Sem** formato, **sem** versão, **sem** estado de revisão, **sem** confiança de importação. `id` default vazio permite questão sem identidade. |
| `QuestionMedia` | `exam.dart:96-112` | id, objectKey, mimeType, sha256, altText, localBytes? | `Uint8List localBytes` dentro da entidade: o domínio carrega binário. |
| `ExamResult` | `exam.dart:114-236` | exam, answers `Map<int,int>`, markedForReview `Set<int>`, durationSeconds, finishedAt | Chaves do mapa são **índices positionais**, não ids de questão. `toJson` (`exam.dart:215`) grava `'question': index + 1`. |
| `AttemptDraft` | `attempt_draft_store.dart:6-28` | answers, review, current, elapsedSeconds, clientAttemptId | Fica em `core/backend/`, não no domínio. É o estado persistido da tentativa. |
| — | — | — | **Não existe** `Attempt`, `ContentVersion`, `PublicationPolicy`, `Provenance`, `QuestionOutcome` como tipos. |

## Onde a política de pontuação está hoje (5 lugares, não 3)

| Local | Regra efetiva |
|---|---|
| `exam.dart:129-150` | `correct` sobre `correctableCount` (questões com gabarito válido). |
| `exam.dart:152-158` | `wrongQuestionIndices`: exige resposta não nula **e** gabarito não nulo. |
| `exam.dart:197-213` | `byTopic`: ignora questão sem gabarito **e** tema vazio — outro denominador. |
| `result_page.dart:280` | "Revisar" = `questions.length - correct`: conta em branco e sem gabarito como a revisar. |
| `attempt_repository.dart:96-99` | Recomputa `correctCount` no cliente e **compara** com o servidor; divergência vira exceção. |
| `exam.dart:192-195` | `unanswered`: `answers[index] == null` — inclui questão sem gabarito, que `byTopic` e `correctableCount` excluem. |

Executado desde `ff3be0c` em `test/scoring_definitions_characterization_test.dart`:
sobre uma única tentativa de 5 questões os números são `correct` 2,
`correctableCount` 3, `scorePercent` 67, `wrongQuestionIndices` 1, `unanswered` 2,
soma de `byTopic.total` 3, "Revisar" 3 e `total` do JSON 5. Com um gabarito fora do
intervalo das alternativas, `scorePercent` passa de 100 (medido: 150). O
`score_percent` devolvido por `submit_exam_attempt` é descartado pelo cliente, e a
entrega é recusada inteira quando o gabarito remoto não cabe nas alternativas — o
`CHECK (correct_index between 0 and 7)` de `private.question_keys` não cruza com o
tamanho de `options`.

O par local/servidor em `attempt_repository.dart:98` é o único ponto onde a
diferença entre as definições se torna visível — e ela se manifesta como falha
de sincronização, não como regra divergente.

## Formato de questão: parseado e depois perdido

- `QuestionFormat` existe em `question_parser.dart:252` com
  `multipleChoice, trueFalse, assertion, openEnded, unknown`.
- O parser preenche o formato (`question_parser.dart:174-177`) e o gabarito o usa
  (`answer_key_parser.dart:354`).
- A borda **descarta**: `digital_exam_service.dart:193-203` constrói
  `ImportedQuestion` sem `format`, então o default `multipleChoice`
  (`question_parser.dart:28`) se aplica; e fixa
  `reviewState: QuestionReviewState.reviewed` (`:200`).
- Consequência medida: uma discursiva importada é reetiquetada como objetiva, e
  qualquer questão baixada volta como "revisada".

## Publicação: validação e apagamento de metadados

- `exam_publication_service.dart:45-59` exige `options.length` entre 2 e 8 e
  `correctIndex` dentro do intervalo em **todas** as questões → prova sem gabarito
  e discursiva são bloqueadas.
- O mesmo serviço grava `'topic': 'Geral'` (`exam_publication_service.dart:64`),
  apagando o tema por questão que o parser preservou.
- `p_source_type` é fixo em `'community'` (`exam_publication_service.dart:80`),
  então oficial/não verificada não sobrevivem à escrita.
- A validação equivalente está duplicada na tela
  (`publish_page.dart:1317-1344`), e a tela é o caminho que o usuário vê.

## O que isto significa para uma refatoração global

1. Positional index como chave de resposta (`answers[int]`) impede vínculo a
   versão de conteúdo: reordenar questões reordena respostas.
2. Sem `ContentVersion`, a comparação de evolução entre tentativas não tem
   referência estável.
3. O formato já existe no import e morre na borda: o modelo novo não precisa
   inventar nada, precisa **parar de descartar**.
4. Cinco definições de pontuação convivem (seis contando `unanswered`); qualquer
   redesenho de UI de resultado herda a contradição até existir `QuestionOutcome`
   único. As seis estão congeladas por teste desde `ff3be0c`.

## Links

[[Contratos de Domínio Alvo]] · [[Fluxos Principais]] ·
[[../02 - Arquitetura/Mapa de Dependências]] ·
[[../02 - Arquitetura/Arquitetura Alvo]] ·
[[../09 - Auditoria/Áreas/02 - Domínio, modelos e regras|área 2]] ·
[[../05 - Qualidade/Critério de Prontidão para Refatoração Global]]
