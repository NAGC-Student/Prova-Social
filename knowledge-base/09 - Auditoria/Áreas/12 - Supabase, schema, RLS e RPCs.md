---
tipo: area
area: Supabase, schema, RLS e RPCs
status: PARCIAL
classificacao: REFATORAR
nivel: {correcao: 4, testes: 3, acoplamento: 3, clareza: 3, seguranca: 4, robustez: 3, aderencia: 2, portabilidade: 4}
fonte_codigo: [supabase/migrations, supabase/tests, scripts/local_db_test.sh, docs/historico/sql]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: alta
atualizado: 2026-11-08
---

> **Atualização 2026-11-08.** O SQL social e o de pacotes foram promovidos a
> `supabase/migrations/202611070001_social_graph.sql` e
> `supabase/migrations/202611070002_content_delivery.sql`, aplicados e testados
> por `scripts/local_db_test.sh` com `supabase/tests/social_schema.sql`.
> `digitalization_v1.sql` não gerou migration nova porque `media_assets` e
> `exam_media` já existem em `20261101002428_exam_media_publication.sql`; o
> arquivo original está congelado em `docs/historico/sql/` como evidência.
> **Nenhuma migration foi aplicada no projeto Supabase remoto.** O texto de
> auditoria abaixo descreve o estado em `05a8fc1` e foi corrigido apenas nos
> caminhos e nos pontos marcados.

# Supabase, schema, RLS e RPCs

## Resumo

O núcleo do backend é sólido: chaves de gabarito separadas em schema privado,
RLS em todas as tabelas expostas, RPCs `security definer` com `search_path`
restrito, publicação validada no servidor, entrega idempotente com índice único e
testes SQL que exercitam RLS, privilégios e rollback. O problema é de
**organização e cobertura do domínio**: em `05a8fc1`, o repositório tinha três
SQLs soltos (`prova_social_backend_v1.sql`, `content_delivery_v1.sql`,
`digitalization_v1.sql`) fora das migrations. O social e os pacotes foram
promovidos em 2026-11-08; faltam entidades centrais (`exam_versions`, `sources`, comunidades,
denúncia); `exam_topics` nunca é alimentado; a procedência oficial é
autodeclarada; e os testes SQL não rodam no GitHub Actions. Classificação:
**REFATORAR** — o que existe é bom, mas o schema precisa ser consolidado e
versionado antes de crescer.

## Escopo e método

- Leitura das nove migrations em `supabase/migrations/` (1.506 linhas somadas),
  com foco em `202609210001_core.sql` (420), `20260926160028_secure_attempt_delivery.sql`
  (234), `202609210003_attempt_idempotency.sql` (212),
  `20260929110000_harden_exam_publication.sql` (159),
  `20261008181438_require_authenticated_attempts.sql` (203) e
  `20261101002428_exam_media_publication.sql` (209).
- Leitura dos SQLs históricos congelados em `docs/historico/sql/`:
  `prova_social_backend_v1.sql` (158), `content_delivery_v1.sql` (140) e
  `digitalization_v1.sql` (147, incluindo o banner de congelamento).
- Leitura dos testes `supabase/tests/attempt_idempotency.sql` (452),
  `deployed_attempt_smoke.sql` (139) e `legacy_attempt_schema.sql` (18), e do
  script `scripts/local_db_test.sh`.
- Não foi executado `supabase db reset`, nem os testes SQL, nem consulta ao
  projeto remoto. A análise é estática.

## O que faz de fato

| Comportamento | Estado | Evidência |
|---|---|---|
| Tabelas centrais com constraints | Funcional | `202609210001_core.sql:8-112` |
| RLS em todas as tabelas expostas do núcleo | Funcional | `202609210001_core.sql:125-210` |
| Gabarito em schema privado | Funcional | `202609210001_core.sql:6, 52-56`; `202609210002_private_keys_rls.sql` |
| Leitura pública só de prova publicada | Funcional | `202609210001_core.sql:142-145, 159-168` |
| Autor só altera a própria prova | Funcional | `202609210001_core.sql:146-158` |
| Favoritos só do dono | Funcional | `202609210001_core.sql:199-202` |
| Tentativas legíveis só pelo dono | Funcional | `202609210001_core.sql:204-210` |
| Publicação validada no servidor | Funcional | `20260929110000...sql:24-147` |
| Publicação com mídia transacional | Funcional | `202611...sql:98-168` |
| Entrega idempotente com índice único | Funcional | `202609210003...sql:7-13`; `20261008181438...sql:96-136` |
| Auth obrigatória na entrega | Funcional | `20261008181438...sql:27-29` |
| Contagem de tentativas só em insert real | Funcional | `20261008181438...sql:116-117` |
| Testes SQL de RLS e privilégios | Funcional | `supabase/tests/attempt_idempotency.sql:232-450` |
| Smoke test transacional | Funcional | `supabase/tests/deployed_attempt_smoke.sql:1-139` |
| Social em migration | Funcional (local) | `202611070001_social_graph.sql`; testado por `supabase/tests/social_schema.sql` |
| Pacotes em migration | Funcional (local) | `202611070002_content_delivery.sql`; bucket e políticas incluídos |
| Digitalização em migration | Funcional | `20261101002428_exam_media_publication.sql`; original congelado em `docs/historico/sql/` |
| `exam_versions` | Ausente | nenhuma tabela de versão |
| `sources` | Ausente | procedência em colunas de `exams` |
| Comunidades e denúncia | Ausente | nenhuma tabela |
| `exam_topics` alimentado | Ausente | nenhum insert no app ou RPC |
| Procedência oficial verificada | Ausente | `p_source_type` vem do cliente |
| Testes SQL no CI | Ausente | nenhum workflow chama `local_db_test.sh` |

## O que funciona

1. **Gabarito fora do alcance do cliente.** `questions` não tem `correct_index`;
   a chave vive em `private.question_keys`, schema sem grant para `anon` ou
   `authenticated`, com RLS sem política
   (`202609210001_core.sql:6, 52-56`; `202609210002_private_keys_rls.sql`).
   Apenas as RPCs `security definer` leem a chave. O teste verifica que
   `authenticated` não acessa o schema privado
   (`attempt_idempotency.sql:196-206`).
2. **RLS coerente no núcleo.** Provas públicas ou do autor, questões da prova
   visível, favoritos do dono, tentativas e respostas do dono. Visitante não vê
   rascunho alheio nem tentativa de outro usuário
   (`202609210001_core.sql:142-210`). O teste confirma que RLS não expõe
   tentativa/respostas de outra conta (`attempt_idempotency.sql:307-324`).
3. **Publicação validada no banco.** `publish_exam` recusa metadados inválidos,
   lista fora de 1–300, mais de 8 MB, campo desconhecido, enunciado curto,
   alternativas fora de 2–8, índice de resposta inválido e alternativa vazia
   (`20260929110000...sql:24-147`). O cliente é apenas conveniência.
4. **Publicação atômica com mídia.** `publish_exam_with_media` valida
   propriedade do asset, posição da questão, papel e alt text antes de publicar;
   insere as relações e confere se todas entraram (`202611...sql:128-166`). O
   teste cobre asset de outra conta e rollback sem prova parcial
   (`attempt_idempotency.sql:121-158`).
5. **Entrega idempotente.** Índice único parcial em `client_attempt_id`, `on
   conflict do nothing`, comparação de payload e rejeição de reutilização
   divergente (`202609210003...sql:7-13`; `20261008181438...sql:96-136`). O
   teste cobre primeira entrega, retry, payload diferente e acesso de outra conta.
6. **Privilégios mínimos em tentativas.** `revoke all` em `attempts` e
   `attempt_answers`, `grant select` só para autenticado, insert apenas via RPC
   (`20260926160028...sql:10-18`). O teste verifica que `PUBLIC` não executa a
   RPC e que não há escrita direta (`attempt_idempotency.sql:364-427`).
7. **`search_path` restrito e grants explícitos nas RPCs.** As funções usam
   `pg_catalog` (e `auth` onde necessário), e o execute é revogado de `public`,
   `anon` e `authenticated`, sendo devolvido só a `authenticated`
   (`20260929110000...sql:154-156`; `20261008181438...sql:191-200`;
   `202611...sql:169-173`). Isso reduz risco de sequestro de função.
8. **Constraints de domínio úteis.** `exams.status`, `source_type`, duração,
   ano, contagem de questões; `questions.position`; `attempt_answers.selected_index`;
   `media_assets.mime_type`, `byte_size`, `sha256`
   (`202609210001_core.sql:17-56`; `202611...sql:3-14`). O banco recusa lixo
   estrutural.
9. **Testes SQL relevantes.** `attempt_idempotency.sql` cobre publicação,
   mídia, origem, chave privada, RLS, idempotência, privilégios e rollback;
   `deployed_attempt_smoke.sql` valida o projeto de staging em transação. É uma
   base melhor que a média.
10. **Script local reproduz o núcleo.** `scripts/local_db_test.sh` sobe Postgres
    local, aplica migrations em ordem e roda os testes SQL, incluindo concorrência
    em duas sessões.

## O que está parcial

### Três subsistemas fora das migrations (histórico)

Em `05a8fc1`, o script local aplicava **apenas** `supabase/migrations/*.sql`
(`scripts/local_db_test.sh:72-78`). Ficavam de fora:

- `prova_social_backend_v1.sql` — tópicos, follows, coleções, comentários, votos;
- `content_delivery_v1.sql` — `content_files`, bucket e políticas de pacote;
- `digitalization_v1.sql` — tabelas auxiliares de digitalização.

Consequências naquele estado:

- um ambiente criado por migrations não tinha `question_comments`,
  `topic_follows` nem `content_files`;
- o app social e o pacote offline quebravam nesse ambiente;
- não havia histórico de quando/por que essas tabelas foram aplicadas em
  produção;
- `supabase db reset` não reproduzia o estado real;
- o teste local não cobria as partes que mais dependem de RLS.

**Resolvido em 2026-11-08 para o social e os pacotes.** O script local agora
aplica `202611070001_social_graph.sql` e `202611070002_content_delivery.sql` e
executa `supabase/tests/social_schema.sql`. A aplicação no remoto continua
pendente de autorização; `digitalization_v1.sql` permanece apenas como
evidência histórica porque seu conteúdo já está coberto pelas migrations de
mídia.

### `exam_topics` nunca é alimentado

A tabela existe, tem índice e política
(`docs/historico/sql/prova_social_backend_v1.sql:12-20, 82, 94`), mas nenhum código Dart ou RPC
insere nela. A publicação grava `questions.topic`, não `exam_topics`; a seed de
tópicos tem apenas seis linhas (`docs/historico/sql/prova_social_backend_v1.sql:157-165`). Portanto:

- seguir assunto não tem catálogo real;
- busca por tópico usa `questions.topic` diretamente;
- não há vínculo entre prova e tópico para feed ou recomendação.

### Procedência oficial é autodeclarada

`publish_exam` aceita `p_source_type` do cliente e o grava sem verificação
(`20260929110000...sql:36-41, 46-52`). O autor pode publicar como `official` sem
provar que é a banca. Não há:

- verificação de domínio da URL da fonte;
- papel de verificador;
- estado “oficial pendente de revisão”;
- auditoria de quem marcou como oficial.

O selo “Fonte oficial” é, hoje, uma escolha do usuário. Isso conflita com a
promessa de procedência confiável.

### Invariante de gabarito não é garantida para provas antigas

`publish_exam` exige chave para toda questão, mas o banco permite publicação por
update direto do autor (`exams_owner_update`) e mantém provas antigas sem chave.
A RPC de entrega faz `join private.question_keys` e simplesmente exclui questões
sem chave do total e do review (`20261008181438...sql:62-86`). O cliente espera
o mesmo número de questões e rejeita. Resultado: prova publicada sem gabarito
completo só falha na entrega, como erro permanente (área 8). O banco não tem
constraint nem trigger que impeça `status='published'` sem chave para todas as
questões.

### Entidades do domínio ausentes

O `AGENTS.md` §14 lista entidades mínimas esperadas. Comparando com o schema:

| Entidade esperada | Estado |
|---|---|
| profiles | Existe |
| topics | Migrado em `202611070001_social_graph.sql` |
| follows | `topic_follows` e `profile_follows` migrados; `exam_topics` sem uso |
| exams | Existe |
| exam_versions | **Ausente** |
| questions | Existe |
| alternatives | Embutidas em `questions.options` (jsonb) |
| answer_keys | Em `private.question_keys` |
| sources | **Ausente** (colunas em `exams`) |
| media | `media_assets` + `exam_media` |
| collections | Migrado; sem uso no app |
| collection_items | `collection_exams`, sem uso |
| attempts | Existe |
| attempt_answers | Existe |
| bookmarks | `favorites` |
| posts/discussions | `question_comments` |
| comments | `question_comments` |
| community_candidates | **Ausente** |
| communities | **Ausente** |
| community_members | **Ausente** |
| reports | **Ausente** |

A ausência de `exam_versions` é particularmente importante: a correção usa as
questões atuais, sem versão. A ausência de `reports` impede moderação. A
ausência de `sources` impede histórico de procedência e licença.

### Sem RLS para o que não existe

Não há política para comunidades, denúncia, notificação ou versão de prova
porque as tabelas não existem. Quando forem criadas, precisarão nascer com RLS,
testes e grants mínimos. O padrão atual do núcleo é bom, mas não há um checklist
automatizado que impeça uma tabela nova de ficar sem RLS.

### Testes SQL fora do CI

Os testes SQL são bons, mas **nenhum workflow do GitHub Actions os executa**.
O CI roda `flutter analyze`, `flutter test`, builds e deploy; o banco é validado
apenas manualmente via `scripts/local_db_test.sh`. Isso significa que uma
migration que quebra RLS, grant ou RPC pode chegar à `main` sem falha. Também não
há `supabase db lint`, `pgTAP` nem verificação de que toda tabela pública tem RLS.

### Migrations não idempotentes em todos os casos

Algumas migrations usam `create table if not exists`, mas outras fazem
`alter table ... add column` sem `if not exists` ou recriam funções com
assinatura antiga. O histórico foi desenhado para rodar uma vez em ordem, não
para ser reaplicado. Isso é normal em migrations, mas dificulta recuperar um
ambiente com drift (que foi o caso dos SQLs soltos até 2026-11-08).

### `attempts_count` sem reconciliação

A contagem sobe apenas quando uma tentativa nova é inserida
(`20261008181438...sql:116-117`), o que é correto para idempotência. Mas não há
reconciliação com a quantidade real de `attempts` se uma linha for apagada por
cascade (exclusão de usuário ou prova). O número pode ficar maior que o real.

## O que está ausente ou quebrado

- `exam_versions`, `sources`, comunidades, membros, candidatos e denúncia.
- Alimentação de `exam_topics`.
- Verificação de procedência oficial.
- Invariante de gabarito completo para prova publicada.
- Testes SQL no CI.
- Checklist/lint de RLS por tabela.
- Reconcilição de `attempts_count`.
- Teste de RLS para mídia e pacotes no fluxo real.
- Teste de `content_files` update malicioso.
- Política de retenção e exclusão de dados do usuário no Storage.

## Divergências documentação × código

| Afirmação | Realidade no SHA | Evidência |
|---|---|---|
| “Toda tabela com dados de usuário tem RLS coerente” | Núcleo, social e pacotes testados no banco local; CI ainda não roda os testes SQL | `scripts/local_db_test.sh` |
| “Entidades mínimas incluem exam_versions, sources, communities, reports” | Nenhuma delas existe | schema |
| “Procedência oficial confiável” | `source_type` vem do cliente | `20260929110000...sql:36-41` |
| “Schema evolui por migrations” | Social e pacotes promovidos em 2026-11-08; nenhuma migration aplicada no remoto | `supabase/migrations/20261107000*.sql` |
| “Testes de RLS” | Existem, mas não rodam no CI | `.github/workflows` |
| “Gabarito completo para publicar” | Só a RPC garante; update direto e provas antigas não | `202609210001_core.sql:150-153` |
| “Tópicos e follows” | Migrados; `exam_topics` continua sem uso | `202611070001_social_graph.sql` |
| “Pacotes com metadados” | `content_files` migrado; update ainda não valida hash no servidor | `202611070002_content_delivery.sql` |

## Evidência de testes

- `supabase/tests/attempt_idempotency.sql:25-190` cobre validação de publicação,
  origem, mídia, asset de outra conta e rollback.
- `:196-206` cobre acesso ao schema privado.
- `:232-324` cobre entrega autenticada, retry idempotente, payload divergente e
  RLS entre contas.
- `:333-360` cobre visitante sem chave de gabarito.
- `:364-450` cobre privilégios de RPC, escrita direta e regressão legada.
- `supabase/tests/deployed_attempt_smoke.sql` cobre o projeto de staging em
  transação.
- `scripts/local_db_test.sh` cobre concorrência em duas sessões.
- Não há teste SQL para `question_comments`, `topic_follows`, `content_files`,
  `media_assets` (além da publicação), comunidades ou denúncia.
- Não há execução desses testes no CI.

## Riscos

1. **Ambiente irreprodutível.** `db reset` não recria o schema que o app usa.
2. **Migração quebrada passa.** Sem testes SQL no CI, RLS/grants podem regredir.
3. **Selo oficial falso.** Qualquer autor pode se declarar fonte oficial.
4. **Prova sem gabarito.** Publicação direta permite prova que nunca sincroniza.
5. **Comunidade sem base.** Criar comunidades sem tabelas, moderação e lifecycle
   tende a gerar duplicata e perda de histórico.
6. **Exclusão de conta incompleta.** Cascatas removem linhas, mas não objetos do
   Storage.
7. **Drift de bucket.** O `on conflict do nothing` pode manter bucket antigo com
   limites diferentes.
8. **Contagem inflada.** `attempts_count` não reconcilia exclusões.

## Plano de refatoração da área

### Lote 1 — Consolidar migrations

- ~~Converter os SQLs soltos em migrations idempotentes.~~ **Feito em 2026-11-08**
  para o social e os pacotes; a digitalização já estava coberta pela migration
  de mídia.
- Fazer `scripts/local_db_test.sh` aplicar exatamente o que produção aplica.
  **Feito para as migrations locais; falta aplicar no remoto.**
- Adicionar verificação que toda tabela em `public` tem RLS e pelo menos uma
  política, exceto as explicitamente privadas.
- Critério de aceite: `supabase db reset` reproduz o app completo; nenhuma
  tabela pública sem RLS; script local passa.

### Lote 2 — CI de banco

- Rodar `scripts/local_db_test.sh` (ou `supabase test db`) no GitHub Actions.
- Rodar `supabase db lint` e um teste de drift entre migrations e schema remoto.
- Critério de aceite: PR com migration que quebra RLS falha no CI; tempo de
  execução aceitável.

### Lote 3 — Procedência e versão

- Criar `sources` com URL, autoria, licença, verificação e histórico.
- Criar `exam_versions` e vincular tentativas à versão resolvida.
- Adicionar estado de verificação de procedência e papel de verificador.
- Critério de aceite: prova oficial exige fonte verificada; submissão carrega
  versão; teste cobre versão antiga.

### Lote 4 — Invariantes de publicação

- Trigger/constraint que impede `status='published'` sem chave para todas as
  questões e sem posição única.
- Reconciliação de `attempts_count` por contagem real.
- Critério de aceite: update direto para publicado sem chave falha; contagem
  confere após exclusão.

### Lote 5 — Entidades sociais e moderação

- Criar `communities`, `community_members`, `community_candidates`, `reports` e
  notificações com RLS e lifecycle.
- Alimentar `exam_topics` na publicação.
- Critério de aceite: cada tabela nova tem política, teste de RLS e grant mínimo;
  publicação cria vínculo de tópico.

### Lote 6 — Exclusão e retenção

- Definir o que acontece com mídia e pacotes ao excluir conta/prova.
- Criar rotina de limpeza de Storage e metadados órfãos.
- Critério de aceite: excluir conta remove dados relacionais e objetos; auditoria
  confirma que nada público permanece.

## Classificação por critério

| Critério | Nota | Justificativa |
|---|---:|---|
| Correção | 4 | Núcleo correto e validado; faltam invariantes e entidades. |
| Testes | 3 | Testes SQL fortes, mas fora do CI e sem cobertura social/pacotes. |
| Acoplamento | 3 | Funções coesas; schema agora em migrations, com histórico congelado. |
| Clareza | 3 | Nomes e comentários bons; drift e ordem pouco claros. |
| Segurança | 4 | Chave privada, RLS, definer e grants; procedência e update de pacote frágeis. |
| Robustez | 3 | Idempotência e constraints; migrations não reprodutíveis. |
| Aderência | 2 | Faltam versões, fontes, comunidades, denúncia e tópicos reais. |
| Portabilidade | 4 | Postgres/Supabase padrão. |

Classificação resultante: **REFATORAR** — a base de segurança é boa e deve ser
preservada, mas o schema precisa ser reunificado em migrations, coberto no CI e
completado com as entidades que o produto exige.

## Dependências

- Área 2 para versões, fontes e tipos.
- Área 8 para contrato de entrega e conflito.
- Área 10 para pacotes e mídia.
- Área 11 para comunidades, denúncia e moderação.
- Área 14 para CI, testes SQL e caos.
- Decisão de produto sobre verificação de fonte, retenção e exclusão de conta.

## O que não foi verificado

- Estado real do projeto Supabase (quais migrations foram aplicadas no remoto).
- `supabase db reset` e `supabase test db` neste repositório.
- Execução dos testes SQL no ambiente local.
- Performance das consultas com volume real.
- Limites e quotas do plano Supabase.
- Drift entre migrations e schema remoto.
- Exclusão de conta e limpeza de Storage.

## Links

- [[02 - Domínio, modelos e regras|Área 2 — Domínio]]
- [[08 - Sincronização, offline, idempotência e conflitos|Área 8 — Sincronização]]
- [[10 - Publicação, pacotes, mídia e Storage|Área 10 — Publicação]]
- [[11 - Social, discussões, comunidades e denúncia|Área 11 — Social]]
- [[14 - Testes, QA e benchmark|Área 14 — Testes]]
- [[../../02 - Arquitetura/Mapa de Módulos|Mapa de Módulos]]
- [[Mapa das Áreas|Mapa das Áreas]]
