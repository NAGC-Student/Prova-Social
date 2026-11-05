---
tipo: area
area: persistência e dados
status: VALIDADO
classificacao: REFATORAR
nivel: {correcao: 4, testes: 3, acoplamento: 2, clareza: 3, seguranca: 4, robustez: 3, aderencia: 2, portabilidade: 4}
fonte_codigo: [lib/core/backend/, supabase/migrations/, supabase/, scripts/]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: alta
atualizado: 2026-11-05
---

# Inventário de persistência e contratos de dados (medido)

Este é o mapa do que **existe** entre app, disco e banco. [[Dados e Segurança]]
ficou como inventário de 42 linhas e nunca foi preenchido; esta nota o substitui
como insumo de engenharia. Não é auditoria de segurança e não afirma nada sobre o
Supabase remoto.

## 1. As três trilhas de SQL (a divergência estrutural)

| Trilha | Arquivos | Tabelas | Policies | Aplicada por |
|---|---|---:|---:|---|
| Migrations versionadas | `supabase/migrations/*.sql` (9) | 9 | 23 | `scripts/pglite_test.mjs:37-46` e `scripts/local_db_test.sh:72-75` |
| SQL solto | `prova_social_backend_v1.sql` (158 linhas), `content_delivery_v1.sql` (140), `digitalization_v1.sql` (146) | 11 | 38 | **ninguém** — nem teste, nem CI, nem script |
| Testes de banco | `supabase/tests/*.sql` (3) | — | — | aplicados sobre as migrations |

`create table if not exists` + nenhuma ferramenta aplicando os arquivos soltos
significa: o schema **não é reproduzível a partir do repositório**.

### Consequência medida no cliente

Tabelas que o Dart lê/grava e que **só** existem no SQL solto:

| Tabela | Uso no cliente | Criada em migration? |
|---|---|---|
| `topics` | `question_discussion_repository.dart:132` | **não** |
| `topic_follows` | `question_discussion_repository.dart:97,118,123` | **não** |
| `question_comments` | `question_discussion_repository.dart:41,78` | **não** |
| `content_files` | `content_delivery_repository.dart:53,98,108` | **não** |

Tabelas definidas **nas duas** trilhas (rascunho e migração), com colunas
idênticas e formatações diferentes: `media_assets`, `exam_media`
(`digitalization_v1.sql:1,16` × `20261101002428_exam_media_publication.sql:3,16`).

Existentes só no SQL solto e nunca usadas pelo app: `exam_topics`, `collections`,
`collection_exams`, `profile_follows`, `comment_votes`. O README já admite isto
(`README.md:151`), mas nenhuma migration as traz.

## 2. O schema atual vs o produto alvo (achado de 2026-11-05)

Lendo as definições, não só os usos:

| Necessidade do produto | Estado no schema | Evidência |
|---|---|---|
| Questão discursiva (sem alternativas) | **Impossível** | `questions.options` tem `check (jsonb_array_length(options) between 2 and 8)` — `202609210001_core.sql:44-46` |
| Coluna `format` na questão | **Não existe** | `questions` tem id, exam_id, position, topic, statement, options, created_at (`:39-50`) |
| Versão do conteúdo resolvido | **Não existe** | nem `exams` nem `questions` têm coluna de versão; `attempts` referencia `exam_id` |
| Procedência oficial/comunitária | **Já existe** | `exams.source_type check in ('official','community','unverified')` (`:24-25`) — quem joga fora é o app, que grava `'community'` fixo (`exam_publication_service.dart:80`) |
| Máquina de estados de publicação | **Já existe** | `exams.status in ('draft','processing','published','archived','rejected')` + `is_public` (`:32-34`) — sem correspondente no modelo Dart |
| Gabarito separado do enunciado | **Já existe** | `private.question_keys` (`:52-55`) com RLS própria |

Consequência direta: **ADR-0002 não é decisão de modelo Dart, é migration.** O
`check` de 2 a 8 alternativas está no banco; enquanto ele existir, nenhuma
combinação de tipos em Dart publica discursiva. E o app já tem dois contratos no
banco (`source_type`, `status`/`is_public`) que a camada Dart ignora — estes são
grátis de adotar.

## 3. Contratos de leitura/escrita (cliente × banco)

Select canônico do catálogo, em `exam_repository.dart:30-36`:

```
id,title,description,category,source_name,source_type,source_url,year,
duration_minutes,attempts_count,created_at,
profiles!exams_author_id_fkey(display_name),
questions(id,exam_id,position,topic,statement,options,created_at),
exam_media(asset_id,question_position,role,alt_text,
           media_assets(id,object_key,mime_type,sha256))
```

- O `select` de `questions` **não traz gabarito** — correto, o gabarito mora em
  `private.question_keys` (`202609210001_core.sql:52-55`) e volta por RPC.
- Nem `position` nem as colunas acima têm contrato em Dart: são strings literais
  repetidas em 4 chamadas do repositório. Um rename de coluna quebra o app sem
  que o analyzer perceba.

RPCs efetivamente chamadas pelo Dart:

| RPC | Chamada | Definida em |
|---|---|---|
| `submit_exam_attempt` | `attempt_repository.dart:41` | `202609210001_core.sql:319` |
| `publish_exam` | `exam_publication_service.dart:101,133` | `20260929110000_harden_exam_publication.sql:3` |
| `publish_exam_with_source_url` | `exam_publication_service.dart:103,135` | `20261009120000_publish_exam_source_url.sql:4` |
| `publish_exam_with_media` | `exam_publication_service.dart:120` | `20261101002428_exam_media_publication.sql:98` |

Parâmetros de entrega: `p_exam_id`, `p_answers`, `p_review_question_ids`,
`p_duration_seconds`, `p_client_attempt_id` (`attempt_repository.dart:43-51`).
Os três `publish_exam*` coexistem como variações com assinatura diferente — o
servico escolhe qual chamar por condições de runtime
(`exam_publication_service.dart:99-137`).

## 4. Persistência local (o que está no aparelho)

| Chave / arquivo | Onde | Conteúdo | Formato |
|---|---|---|---|
| `attempt_draft_v1_$examId` | `attempt_draft_store.dart:72` | answers, review, current, elapsedSeconds, clientAttemptId | JSON em `SharedPreferences` (`:78-87`) |
| `attempt_sync_queue_v1` | `attempt_sync_service.dart:58` | fila de entregas com `clientAttemptId` | JSON único, regravado por inteiro |
| `private_exams_v1` | `local_exam_store.dart:172` | provas locais completas + `importedDocument` | JSON; espelho em `private_exams_v1_backup` (`:197`) |
| `private_exams_v1.json` (+ `.bak`, `.tmp`) | `local_exam_payload_store_io.dart:10-12` | payload grande fora das prefs | escrita com backup temporário em `path_provider` |
| `focus_timer_settings_v1` | `focus_timer_settings.dart:24` | timer total/por questão com limites 5–480 min, 15–600 s | JSON |
| `search_recent_queries_v1` | `search_page.dart:191` | histórico de buscas | JSON |

- Respostas são mapa **posicional** `Map<int,int>` (`attempt_draft_store.dart:15`),
  gravado com chaves transformadas em string (`:81`).
- O gabarito local fica **dentro** do mesmo JSON do enunciado:
  `local_exam_store.dart:120` serializa `{statement, options, correctIndex}` para
  calcular o id de conteúdo. No servidor há separação (`private.question_keys`);
  no aparelho não.
- O id de conteúdo calculado por sha256 (`local_exam_store.dart:120`) é o
  embrião de `ContentVersion` — mas hoje serve para deduplicar prova, não para
  versionar tentativa.

## 5. Cobertura de teste real desta superfície

| Superfície | Coberta por | Lacuna |
|---|---|---|
| `attempts`, idempotência, RLS de entrega | `supabase/tests/attempt_idempotency.sql`, `deployed_attempt_smoke.sql` via PGlite e `local_db_test.sh` | `local_db_test.sh` **não roda no CI** |
| `profiles`, `favorites`, `questions`, `exam_media`, Storage | — | sem asserção de RLS |
| `topics`, `topic_follows`, `question_comments`, `content_files` | — | nem existem na trilha aplicada |
| Migração local de prefs (`_backup`, payload em disco) | testes em `test/` para compressão/hash/migração | crash no meio da regravação do JSON inteiro não testado |

## 6. Por que isto trava a refatoração global

1. Sem uma única trilha de schema, não há como escrever o `ContentVersion` do
   C5 nem a migração de `answers` de posicional para `QuestionId` — não se sabe
   qual é o estado autoritativo do banco.
2. Quatro tabelas usadas pelo app não são reproduzíveis a partir do repo; um app
   novo "descobriria" o schema em produção.
3. Literais de colunas espalhados (4 select em `exam_repository.dart`, mais os
   repositórios) significa que contratos de dados não têm definição testável.
4. A decisão SharedPreferences × SQLite (ADR-0004) não pode ser tomada sem este
   inventário — agora ele existe.

## 7. Ações que este inventário destrava (não autorizadas)

- Promover o SQL solto a migrations nomeadas (ou declarar oficialmente que o
  schema social está adiado) — Lote 2.
- Escolher **uma** definição para `media_assets`/`exam_media`.
- Extrair os selects para um único módulo de contrato de dados.
- Levar `scripts/local_db_test.sh` ao CI junto com as novas migrations.

## Links

[[Dados e Segurança]] · [[../03 - Domínios/Modelo de Domínio Atual]] ·
[[../03 - Domínios/Contratos de Domínio Alvo]] ·
[[../09 - Auditoria/Áreas/12 - Supabase, schema, RLS e RPCs|área 12]] ·
[[../02 - Arquitetura/Mapa de Dependências]] ·
[[../06 - Decisões/ADR/README|ADR-0004]]
