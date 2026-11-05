---
tipo: area
area: fluxos reais
status: VALIDADO
classificacao: EVOLUIR
nivel: {correcao: 4, testes: 3, acoplamento: 2, clareza: 3, seguranca: 4, robustez: 4, aderencia: 3, portabilidade: 4}
fonte_codigo: [lib/features/publish/, lib/core/backend/, lib/core/import/]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: alta
atualizado: 2026-11-05
---

# Fluxos reais (medidos no código, não alvo)

[[Fluxos Propostos]] é INTENÇÃO e diz que "as fronteiras exatas, dados
transferidos e estados de falha precisam ser confirmados". Este arquivo confirma.
É o insumo direto para redesenhar o app: **o que já funciona tem contrato**, e o
contrato está descrito aqui com origem e destino.

## F1 — Importação de PDF

Executada **dentro da tela**, não por um serviço de pipeline:

| Etapa | Chamada real | Onde |
|---|---|---|
| 1. Escolha do arquivo | `FilePicker.pickFile` | `publish_page.dart:123,263` |
| 2. Extração de texto por página | `const PdfTextExtractor().extract(...)` | `publish_page.dart:472` |
| 3. Perfil de layout | `const ExamLayoutProfiler().profile(pageTexts)` | `publish_page.dart:488` |
| 4. Parser de questões | `const QuestionParser().parsePages(pageTexts)` | `publish_page.dart:480` |
| 5. Gabarito | `const AnswerKeyParser()` | `publish_page.dart:482` |
| 6. Quality gate | `const ImportQualityGate().assess(...)` | `publish_page.dart:489,691` |
| 7. Previews de página | `PdfTextExtractor().renderPages(...)` | `publish_page.dart:522` |
| 8. Revisão humana | `ImportReviewPage` (`publish_page.dart:997`) | — |
| 9. Rascunho local | `local_exam_store.dart` (`private_exams_v1`) | — |

Fatos que o desenho novo precisa respeitar:

- **Instanciação por construtor default** (`const X()`), 7 componentes sem injeção:
  não há como trocar OCR nem parser em teste sem `test/` cobrir a tela.
- OCR não é chamado aqui: `ocr_router.dart:30-38` decide por
  `minimumNativeTextLength = 20` caracteres dentro de `PdfTextExtractor`
  (`pdf_text_extractor.dart:179` chama `OcrService()` fixo).
- A composição do pipeline mora em `features/publish` → é a única fronteira
  medida em que a **UI é o orquestrador**
  (ver [[Mapa de Dependências]]: `features/publish → core/import` = 7 arestas).
- Perda medida na borda: `format` e `reviewState` reais são substituídos por
  default/`reviewed` (`digital_exam_service.dart:193-203`).

## F2 — Tentativa, rascunho e fila de entrega

O fluxo mais bem resolvido do app, com máquina de estados explícita.

```
QuizPage
  ├─ resposta → AttemptDraftStore.save(examId, draft)        [draft]
  │     └─ fila serial por _tail; status: saving|saved|failed (attempt_draft_store.dart:30,75-101)
  ├─ finalizar → flush() espera a última gravação; relança se falhou (:111-125)
  ├─ local: AttemptQueueStore.completeLocal(clientAttemptId, result)  (attempt_sync_service.dart:127)
  └─ remoto: AttemptSyncService.saveForSync(submission) → enqueue (:291-296)
              └─ prova local (isLocal) NUNCA entra na fila (throws :292-294)
```

Máquina de estados da fila (`attempt_sync_service.dart:11-18`):

| Estado | Entrada | Saída |
|---|---|---|
| `pendingSync` | `enqueue` | `sending` |
| `sending` | `_sync` marca e grava antes de chamar o backend | `synced` / `waitingConnection` / `waitingAuthentication` / `requiresAttention` |
| `waitingConnection` | erro **transiente** | `sending` após `nextAttemptAt` |
| `waitingAuthentication` | erro com `requiresAuthentication` | `sending` quando autenticar |
| `requiresAttention` | erro **não transiente** | `sending` apenas com `retryAttention: true` |
| `synced` | sucesso → `store.complete` remove do pendente e grava em `completed` | — |

Garantias medidas:

- **Idempotência por `clientAttemptId`** — chave da fila e parâmetro
  `p_client_attempt_id` da RPC (`attempt_repository.dart:51`); dedupe de chamada
  em voo por `coordinator.inFlight[clientAttemptId]`
  (`attempt_sync_service.dart:304,314`), serialização global por
  `coordinator.tail` (`:306-313`).
- **Backoff fixo:** 30, 120, 600, 1800, 3600 s, saturando no último
  (`attempt_sync_service.dart:416-419`).
- **Agendamento respeitado** por `nextAttemptAt`, ignorável só com
  `ignoreSchedule: true` (`:300,356-359`); `syncDue()` varre a fila (`:405-415`).
- **Storage serializado** por `Expando<Future<void>>` por instância de storage
  (`:81-90`), com uma chave JSON única `attempt_sync_queue_v1` regrava por
  inteiro.

Lacunas que o redesenho precisa herdar como requisito, não como bug:

1. Estado de "resposta perdida" não é testado em kill de processo — a fila é
   escrita por inteiro, sem transação.
2. Não há resolução de conflito: `_sameSubmission` compara `exam.id`,
   `durationSeconds` e afins (`:422-424`) mas não há política quando duas
   versões existem.
3. O resultado sincronizado referencia **só `exam.id`** — sem
   [[../03 - Domínios/Contratos de Domínio Alvo|ContentVersion]] (C5).

## F3 — Publicação

```
PublishPage._valid (publish_page.dart:1317-1344)
  └─ ExamPublicationService.publish (exam_publication_service.dart:45-69)
        ├─ valida 2..8 opções e correctIndex válido em TODAS as questões
        ├─ escolhe RPC por condição de runtime:
        │     publish_exam | publish_exam_with_source_url | publish_exam_with_media
        │     (:99-137)
        ├─ monta payload com 'topic': 'Geral' (:64)
        ├─ grava 'community' como source_type (:80)
        └─ Storage: media_assets/exam_media via ExamMediaRepository
```

Divergência medida: a tela e o serviço validam regras **semelhantes e não
idênticas**, e o serviço não verifica `reviewState` — o único ponto que faria a
revisão humana ser obrigatória na escrita.

## F4 — Consumo e entrega offline

```
ExamRepository.fetch (select canônico, exam_repository.dart:30-36)
  └─ DigitalExamService → ImportedQuestion com reviewState=reviewed (:200)
ContentDeliveryRepository:
  ├─ objeto gzip em Storage: {userId}/exams/{examId}/content/{sha256}.json.gz
  │     (content_delivery_repository.dart:38)
  ├─ metadados: object_key, sha256, compressed_bytes, uncompressed_bytes (:109)
  └─ verificação: sha256 do bytes baixados != metadata ⇒ rejeita (:113-128)
LocalExamStore: private_exams_v1 (prefs) + private_exams_v1.json (disco, .bak/.tmp)
```

A verificação de integridade por hash **existe e funciona** — é o contrato que um
app novo deve manter literalmente.

## Resumo para o redesenho

| Fluxo | Estado do contrato | Preservar como está | Reescrever |
|---|---|---|---|
| F1 Importação | funcional, mas orquestrado na UI | extração→perfil→parser→gabarito→gate | composição do pipeline para `application/`; preservar `format` |
| F2 Tentativa/sync | contrato explícito e maduro | máquina de estados, backoff, idempotência, dedupe | chave posicional → `QuestionId`; transação; `ContentVersion` |
| F3 Publicação | divergente (tela × serviço) | separação de gabarito no banco | validação única em `PublicationPolicy`; `source_type` e `topic` reais |
| F4 Consumo | bom | hash + gzip + verificação | `reviewState` falso na descarga |

## Links

[[Fluxos Propostos]] · [[Mapa de Dependências]] · [[Arquitetura Alvo]] ·
[[../03 - Domínios/Fluxos Principais]] ·
[[../04 - Infraestrutura/Inventário de Persistência e Dados]] ·
[[../03 - Domínios/Contratos de Domínio Alvo]]
