---
tipo: area
area: contratos de domínio
status: INTENÇÃO
classificacao: REFATORAR
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [lib/domain/models/exam.dart, lib/core/import/, lib/core/backend/, lib/features/]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: media
atualizado: 2026-11-07
---

# Contratos de domínio alvo (especificação; ADRs aceitos em 2026-11-07)

Cada contrato abaixo fecha uma lacuna medida em [[Modelo de Domínio Atual]].
**Nenhum está implementado.** Os ADRs correspondentes foram **aceitos em
2026-11-07** ([[../06 - Decisões/ADR/README|ADRs]]); a implementação continua
pendente de tarefa autorizada. O nível de detalhe aqui é o
mínimo para que um lote de código possa ser escrito sem redefinir a regra durante
a implementação.

Convenção: `invariant` = violação deve falhar em teste, não em runtime silencioso.

## C1 — `Question`

```
id            : QuestionId        (obrigatório, único, sobrevive a reordenação)
format        : multipleChoice | trueFalse | assertion | openEnded | unknown
statement     : texto 1..20000
options       : lista 0..8 (>=2 se format != openEnded)
answerKey     : AnswerKey         (nunca dentro da Question pública)
topicIds      : lista não vazia    (hoje: string única `topic`)
media         : lista de MediaRef (sem bytes)
provenance    : Provenance
contentVersion: ContentVersion
```

- **Invariantes:** `openEnded` com `options.length > 0` é inválida; `id` vazio é
  inválido; `media` não carrega `Uint8List` (hoje `exam.dart:111` carrega).
- **Substitui:** `Question` em `exam.dart:68-94`; preserva `QuestionFormat` já
  existente em `question_parser.dart:252`, que hoje é descartado em
  `digital_exam_service.dart:193-203`.
- **Custo real medido:** isto **não é só Dart**. `public.questions` não tem coluna
  `format` e tem `check (jsonb_array_length(options) between 2 and 8)`
  (`202609210001_core.sql:45-47`), então `openEnded` com 0 alternativas é
  **rejeitada pelo banco**. Ver seção 2 de
  [[../04 - Infraestrutura/Inventário de Persistência e Dados]].
  O ADR-0002 precisa de migration, não de classe.
- **Testes exigidos:** 1 teste por formato; 1 teste provando que `format`
  sobrevive importação → rascunho → publicação → download → tentativa.

## C2 — `AnswerKey` (separação de gabarito)

```
questionId    : QuestionId
correctIndex  : int? | null (openEnded sem correção automática)
source        : official | community | unverified
confirmedBy   : confirmação humana explícita (id + timestamp) | null
```

- **Invariantes:** ausência de `AnswerKey` é estado **normal**, não erro; uma
  questão sem gabarito confirmado nunca entra em `PublicationPolicy.publicar`.
- **Substitui:** `correctIndex` dentro de `Question` (`exam.dart:74`), o
  `private.question_keys` do banco e o `'correct_index'` no payload de publicação
  (`exam_publication_service.dart:68`).
- **Já existe no backend:** tabela `private.question_keys`
  (`202609210001_core.sql:52-55`) com RLS `202609210002_private_keys_rls.sql`. O
  contrato novo alinha o modelo Dart ao que o banco já separa.
- **Rede já existente:** `test/scoring_definitions_characterization_test.dart:152`
  exige que o gabarito seja **legado no payload** do submit (`'answers'` com
  `correct_index`) — adotar `AnswerKey` separado é mudança deliberada, com um dos
  dois primeiros testes do repo como lista do que muda.

## C3 — `QuestionOutcome` (denominador único)

Estados, um por questão resolvida:

| Estado | Condição | Pontua? | Vai para “Prova de erros”? |
|---|---|---|---|
| `correct` | resposta == gabarito confirmado | sim | não |
| `wrong` | resposta != gabarito confirmado | não, mas conta no denominador | sim |
| `blank` | sem resposta | não, conta no denominador | decisão da pessoa ao finalizar |
| `unknownAnswer` | resposta dada, gabarito não confirmado | **fora** do denominador | sim, como “não sei/sem gabarito” |
| `excluded` | questão anulada/fora da prova | fora do denominador | revisão separada |

- `scorePercent = correct / (correct + wrong + blank)`.
- **Substitui as quatro regras medidas:** `exam.dart:129-150`, `exam.dart:152-158`,
  `exam.dart:192-213` (`byTopic`) e `result_page.dart:280` (“Revisar” = total −
  acertos). `attempt_repository.dart:96-99` passa a comparar `QuestionOutcome`,
  não inteiros recomputados.
- **Requisito de produto já decidido** ([[../01 - Produto/Fluxo de Entrada e Criação|Progresso]]):
  “Não sei” separado de erro confirmado; branco não vira rótulo de erro;
  denominação única. Isto ainda é intenção, não spec aprovada.
- **Testes exigidos:** 1 asserção por estado; 1 teste de contradição
  local × servidor; 1 teste de que `unknownAnswer` não reduz percentual.
- **Rede já existente:** a contradição que C3 resolve está congelada em
  `test/scoring_definitions_characterization_test.dart` (`ff3be0c`). Ao adotar C3,
  aqueles 10 testes são a lista deliberada de expectativas que **mudam** — reescrevê-los
  é ato de projeto, não ajuste para passar.

## C4 — `Attempt` (entidade que não existe)

```
clientAttemptId : UUID (já existe: attempt_draft_store.dart:19)
examId          : QuestionSet referência
contentVersion  : ContentVersion  ← o que falta hoje
answers         : Map<QuestionId, int?>  ← hoje Map<int,int> posicional
markedForReview : Set<QuestionId>        ← hoje Set<int>
elapsedSeconds  : int
pauseAllowed    : bool (escolhido antes da prova)
startedAt/finishedAt
state           : draft | finalizing | queued | delivered | discarded
```

- **Invariantes:** `state` só avança; `delivered` é idempotente por
  `clientAttemptId` (mecânica já existe em `attempt_sync_service.dart:57-62`);
  excluir uma tentativa remove local e sincronizado e **não** reaparece após
  sincronizar (regra de produto já registrada).
- **Substitui:** `AttemptDraft` (`attempt_draft_store.dart:6-28`) e a serialização
  JSON solta; mantém `DraftStorage` como porta.
- **Testes exigidos:** retomada após recriar widget; retomada após kill do
  processo; entrega em fila sem rede; não-duplicação em retry.

## C5 — `ContentVersion`

```
contentVersionId : UUID
questionsHash    : SHA-256 do conjunto resolvido (enunciado+alternativas+ordem)
answerKeyHash    : SHA-256 do gabarito confirmado
examId, revision : int
```

- **Por que:** hoje a tentativa referencia só `exam.id`
  (`attempt_draft_store.dart:72` usa a chave `attempt_draft_v1_$examId`), então
  editar o conteúdo depois muda a interpretação de uma tentativa antiga.
- **Não confundir:** `ImportedQuestionVersion` (`question_parser.dart:206`) é
  versão de **enunciado dentro da importação**, com `label/statement/options/
  correctIndex/format/confidence/warning`. Não serve como versão de conteúdo
  publicado.
- **Risco medido:** o hash de baseline do benchmark identifica arquivos por
  caminho (`test/local_corpus_benchmark_test.dart:47`); a chegada de
  `contentVersion` deve coexistir com ele, não substituí-lo às pressas.
- **Testes exigidos:** duas versões da mesma prova produzem resultados não
  comparáveis entre si; versão do conteúdo resolvido fica gravada na tentativa.

### Estado em 2026-11-08 (ADR-0003, alternativa B)

O passo imediato **não cria** `contentVersions` no servidor nem migration. A
revisão de conteúdo é um hash SHA-256 calculado no cliente em
`lib/core/content/content_version.dart`:

- `ContentVersion.ofQuestions` cobre posição, enunciado, alternativas, gabarito
  e tópico; `ofImportedQuestions` inclui também `format`. Resposta esperada e
  rubrica entram quando o modelo discursivo existir (ADR-0002, etapa 2).
- `AttemptDraft.examContentHash` grava o hash no rascunho. Rascunho sem o campo
  (formato anterior) continua sendo restaurado; rascunho com hash diferente do
  conteúdo atual não restaura respostas e mostra “O conteúdo desta prova mudou.
  Comece uma nova tentativa.”.
- `LocalExam.attemptExamId` mantém o hash legado de
  `{statement, options, correctIndex}` para não invalidar rascunhos já gravados.
  Ele **não** é o `ContentVersion`.
- `schemaVersion` continua sendo o formato do pacote (`1` em
  `digital_exam_service.dart`) e `versionLabel` continua sendo a variante de
  banca. Nenhum dos dois é revisão de conteúdo.
- **Ainda fora de escopo:** coluna/tabela de revisão no Supabase, backfill de
  provas publicadas, recusa de envio no servidor e UI de exportação do rascunho
  antigo.

## C6 — `PublicationPolicy`

Decisão única, hoje duplicada em `publish_page.dart:1317-1344` e
`exam_publication_service.dart:45-59`:

| Situação | Resultado |
|---|---|
| objetiva com gabarito confirmado e revisada | publicável |
| objetiva sem gabarito confirmado | rascunho privado; **não** publicável |
| discursiva (`openEnded`) | publicável sem correção automática |
| qualquer questão com `reviewState != reviewed` real | bloqueio |
| `provenance == unverified` | exige intenção explícita confirmada |

- **Bug de borda a fechar:** `digital_exam_service.dart:200` marca
  `reviewState: reviewed` na **descarga**, ou seja, a revisão humana some no
  caminho download → republicação.
- **Testes exigidos:** serviço recusa não revisado; discursiva passa; sem gabarito
  fica privada; `p_source_type` preservado (hoje fixo em `'community'`,
  `exam_publication_service.dart:80`).
- **Rede já existente:** o estado atual deste contrato é executado por
  `test/publication_characterization_test.dart` (`ff3be0c`) — rejeição de
  `openEnded` antes de qualquer RPC, reprovação da prova inteira por uma questão,
  `topic` → `Geral`, `p_source_type` fixo, troca de RPC pela URL de origem e
  publicação devolvida mesmo com o pacote digital falhando.

## C7 — `Provenance`

```
sourceType : official | community | unverified   (não colapsar em default)
sourceUrl  : Uri?                                 (https obrigatório p/ official)
banca      : referência canônica                 (hoje `category` string livre)
concurso   : referência canônica
year       : int?
```

- Hoje `ExamSourceType.fromDatabase` converte valor desconhecido em `unverified`
  sem aviso (`exam.dart:61-65`) e a publicação grava `'community'` fixo
  (`exam_publication_service.dart:80`). A taxonomia decidida em conversa — banca,
  concurso/instituição, disciplina/tópico e temas como campos distintos — ainda
  não tem tipo no código.
- **Testes exigidos:** round-trip official → servidor → cliente preserva
  `sourceType`; URL obrigatória quando `official`.

## Sequência mínima para valer uma refatoração global

1. Aprovar ADR-0002 (C1/C2/C6) e ADR-0003 (C5) — sem eles qualquer extração de
   tela recongela a regra errada.
2. Escolher chave estável (`QuestionId`) antes de mexer em `answers` — é
   pré-condição de C4 e C5.
3. Escrever testes de caracterização das 4 regras de pontuação **antes** de
   unificá-las, para provar que o `QuestionOutcome` não muda o resultado do
   usuário em nenhum caso hoje existente.
4. Só então os passos 1–3 da [[../02 - Arquitetura/Arquitetura Alvo|ordem de
   migração]] fazem sentido.

## Links

[[Modelo de Domínio Atual]] · [[Fluxos Principais]] ·
[[../02 - Arquitetura/Arquitetura Alvo]] ·
[[../04 - Infraestrutura/Inventário de Persistência e Dados]] ·
[[../06 - Decisões/ADR/README]] ·
[[../05 - Qualidade/Critério de Prontidão para Refatoração Global]]
