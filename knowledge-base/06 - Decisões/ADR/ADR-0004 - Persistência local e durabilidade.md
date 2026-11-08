---
tipo: adr
area: persistência local
status: INTENÇÃO
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [lib/core/backend/local_exam_store.dart, lib/core/backend/local_exam_payload_store.dart, lib/core/backend/local_exam_payload_store_io.dart, lib/core/backend/local_exam_payload_store_stub.dart, lib/core/backend/attempt_draft_store.dart, lib/core/backend/attempt_sync_service.dart, pubspec.yaml]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: media
atualizado: 2026-11-07
---

# ADR-0004 — Persistência local: JSON/SharedPreferences vs SQLite transacional

- **Status:** aceito
- **Data:** 2026-11-07
- **Responsável pela aprovação:** NAGCODE-Dev (responsável pelo projeto)
- **Áreas:** 7, 8
- **Urgência:** Alta

## Contexto

**O título desta decisão no índice está desatualizado.** Provas privadas já
não são “JSON em SharedPreferences”: já existe escrita atômica em arquivo,
atrás de uma porta. O que continua em SharedPreferences são os outros quatro
armazenamentos e o caminho de legado.

- **Porta existente.** `abstract interface class ExamPayloadStorage`
  (`lib/core/backend/local_exam_payload_store.dart:4-10`) com `fileBacked`,
  `read`, `readBackup`, `write(payload, {backupPayload})` e `migrate`;
  export condicional io/stub em `:1-2`.
- **Escrita atômica já implementada.** `local_exam_payload_store_io.dart:7-8`
  documenta “flushed temporary file followed by a rename; the previous
  complete payload is retained as a backup”; `:34-53` escreve
  `backupTemporary` e `temporary` com `flush: true` e faz `rename` sobre o
  arquivo final. Usa `path_provider` (`:3`).
- **Web não tem durabilidade equivalente.** O stub devolve `fileBacked =>
  false`, `read/readBackup => null`, `write/migrate => false`
  (`local_exam_payload_store_stub.dart:7-16`), e o comentário em `:1-2` diz
  que no browser a representação continua sendo preferences.
- **Legado ainda vivo.** Chave `private_exams_v1`
  (`lib/core/backend/local_exam_store.dart:172`) e
  `private_exams_v1_backup` (`:197`, `:339-343`). Quando a escrita em arquivo
  falha, o código grava backup e payload em preferences e lança `StateError`
  se algum dos dois falhar (`:337-349`); quando tem sucesso, remove as duas
  chaves legadas e apenas loga se a limpeza falhar (`:351-360`).
- **Quatro armazenamentos seguem em preferences:** rascunho
  `attempt_draft_v1_$examId` (`lib/core/backend/attempt_draft_store.dart:72`,
  porta própria read/write/remove em `:33-35`), fila de sincronização
  `attempt_sync_queue_v1` (`lib/core/backend/attempt_sync_service.dart:58`),
  focus timer `focus_timer_settings_v1`
  (`lib/core/backend/focus_timer_settings.dart:24`) e buscas recentes
  `search_recent_queries_v1` (`lib/features/search/search_page.dart:191`).
- **Nenhum banco embarcado.** `grep -n "sqflite\|drift\|sqlite\|hive\|isar\|objectbox"
  pubspec.yaml` casa apenas `archive: ^4.3.0` (falso positivo de substring
  “hive”). Não há dependência de banco.
- **Reescrita integral do payload.** `_encode(items)` e
  `_packages.create({'schemaVersion': 1, 'exams': values})`
  (`local_exam_store.dart:264-265`); remover um download reencoda a lista
  inteira e reescreve (`:334-337`). Prefixo de compressão `PSGZ1|` (`:173`).
  Custo O(n) por edição de uma prova.
- **Estado global e fila estática.** `static final _packages`,
  `static Future<void>? _tail`, `static ExamPayloadStorage? storageOverride`
  (`local_exam_store.dart:174-176`); construtor
  `_storage = storage ?? storageOverride ?? LocalExamPayloadStore()` (`:180`);
  serialização por encadeamento de `Future` em `:183` e `:288-303`. O seam de
  teste é global, não injetado por instância.
- **Fila com 6 estados e default silencioso.** `enum AttemptSyncState
  { pendingSync, sending, waitingConnection, synced, requiresAttention,
  waitingAuthentication }` (`attempt_sync_service.dart:11-18`); estado
  desconhecido no JSON cai em `pendingSync` (`:453`) — uma entrada corrompida
  ou de versão futura vira pendência sem sinal.
- **Gabarito no mesmo JSON.** `correctIndex` entra no payload local e no hash
  de identidade (`local_exam_store.dart:120`); não há separação entre conteúdo
  e resposta no aparelho.

**Limites.** Não foi medido tamanho real de payload em uso, nem tempo de
escrita em aparelho de entrada — a complexidade O(n) é leitura de código, não
benchmark. Não há teste de queda de energia durante `rename`. O comportamento
web foi lido no stub, não executado em browser.

## Decisão

**Aprovada em 2026-11-07 pelo responsável pelo projeto (NAGCODE-Dev).**
Alternativa escolhida: **B — estender `ExamPayloadStorage` a rascunho e fila**,
sem adotar SQLite agora. A decisão é estender a porta que já existe aos dois
armazenamentos de maior risco (rascunho e fila de sincronização), manter
preferências para os dois de baixo risco (focus timer e buscas recentes), e
tratar o caminho de legado como migração com fim marcado. SQLite entra em
pauta apenas quando houver necessidade medida de transação multi-entidade ou
consulta — não como refactor preventivo.

Motivo: a durabilidade que SQLite traria para provas privadas **já foi
construída** (temp + flush + rename + backup). O ganho remanescente é
transacionalidade entre entidades diferentes, e hoje cada armazenamento é
uma chave independente.

## Alternativas

- **A — Não fazer.** Prós: custo zero; nenhum risco de migração de dados do
  usuário. Contras: rascunho e fila continuam sujeitos a escrita parcial de
  preferences; o legado em duplicata permanece por tempo indefinido; o seam
  global continua impedindo teste de concorrência entre instâncias.
- **B — Estender `ExamPayloadStorage` a rascunho e fila (escolhida).** Uma porta por
  armazenamento (ou a mesma com chave), escrita atômica com backup, fallback
  de preferences explícito. Prós: reusa código testado; sem dependência nova;
  melhora o pior caso de perda de progresso; permite trocar `storageOverride`
  global por injeção. Contras: mais um arquivo por armazenamento; no web o
  stub continua não durável (decisão separada para IndexedDB); não dá
  transação entre rascunho e fila.
- **C — SQLite transacional (sqflite ou drift).** Entidades para provas,
  rascunhos, fila e configurações; transações cobrindo “salvar rascunho +
  enfileirar entrega”. Prós: atomicidade real entre entidades, consulta e
  índice, migração de schema versionada, escala melhor que reescrita integral.
  Contras: dependência nativa nova (impacta ADR-0005 e ADR-0011), camada de
  migração própria, reescrita dos quatro armazenamentos e de seus testes,
  risco de perda de dados durante a conversão, e drift/sqflite precisam de
  decisão de pin (ADR-0009). É a opção mais cara.
- **D — Voltar tudo para SharedPreferences.** Prós: um mecanismo só, simples.
  Contras: regride a garantia atômica já construída; aumenta chance de payload
  corrompido; contradiz o caminho de migração já em curso no código.

## Consequências e reversão

- **Positivas de B:** rascunho e fila passam a ter a mesma garantia de prova
  privada; o legado ganha data para sair; o seam deixa de ser global, o que
  destrava teste de concorrência (hoje impossível com `_tail` estático).
- **Negativas/custos:** três representações coexistindo durante a transição
  (arquivo, preferences atual, preferences backup); mais código de migração;
  web continua sem durabilidade de arquivo e isso precisa estar escrito como
  limite conhecido, não como surpresa.
- **Riscos:** migração de dados do usuário é o ponto de falha — se a leitura
  do legado falhar depois de o novo caminho assumir, o progresso some.
  Mitigação: manter o legado intacto até confirmação de leitura bem-sucedida,
  como já faz `_decodeWithBackup` (`local_exam_store.dart:214-229`).
- **Reversão:** B é reversível por `git revert` enquanto o legado não for
  removido; depois da limpeza das chaves (`:351-360`), reverter exige
  reimportar do arquivo. C é reversível apenas com exportação completa antes
  da conversão e migration de descida; remover a dependência nativa depois de
  dados convertidos não é reversão, é perda.

## Evidências e validação

- Áreas: [[../../09 - Auditoria/Áreas/07 - Persistência local, backups e provas locais|Área 07]],
  [[../../09 - Auditoria/Áreas/08 - Sincronização, offline, idempotência e conflitos|Área 08]].
- Código: [local_exam_store.dart](../../../lib/core/backend/local_exam_store.dart),
  [local_exam_payload_store.dart](../../../lib/core/backend/local_exam_payload_store.dart),
  [local_exam_payload_store_io.dart](../../../lib/core/backend/local_exam_payload_store_io.dart),
  [local_exam_payload_store_stub.dart](../../../lib/core/backend/local_exam_payload_store_stub.dart),
  [attempt_draft_store.dart](../../../lib/core/backend/attempt_draft_store.dart),
  [attempt_sync_service.dart](../../../lib/core/backend/attempt_sync_service.dart),
  [pubspec.yaml](../../../pubspec.yaml).
- Testes: [attempt_draft_store_test.dart](../../../test/attempt_draft_store_test.dart)
  (163 linhas), [attempt_sync_service_test.dart](../../../test/attempt_sync_service_test.dart)
  (566), [quiz_offline_submission_test.dart](../../../test/quiz_offline_submission_test.dart)
  (441), [draft_resume_characterization_test.dart](../../../test/draft_resume_characterization_test.dart)
  (210), e os dois que exercitam a porta:
  [test/ux/local_exam_test.dart](../../../test/ux/local_exam_test.dart),
  [test/ux/navigation_editor_test.dart](../../../test/ux/navigation_editor_test.dart).
- **Exigido antes de implementar:** teste de payload corrompido com backup
  válido e com backup inválido (hoje só logado em `:214-229`); teste de
  duas instâncias escrevendo em paralelo (o `_tail` estático precisa ser
  caracterizado antes de virar injetado); teste de migração legado → arquivo
  com falha no meio; para C, benchmark de escrita com N provas antes de
  decidir.
- Comandos de reprodução:
  `grep -rn "_v1'\|_v1\"" lib/ --include=*.dart`;
  `grep -n "static " lib/core/backend/local_exam_store.dart`;
  `grep -n "rename\|flush" lib/core/backend/local_exam_payload_store_io.dart`.
- Relacionados: [[ADR-0003 - Versionamento de conteúdo e vínculo da tentativa|ADR-0003]],
  [[ADR-0009 - Política de dependências e pins|ADR-0009]],
  [[ADR-0011 - Tamanho de APK, modelos e componentes nativos|ADR-0011]],
  [[../../02 - Arquitetura/Mapa de Dependências|Mapa de Dependências]].