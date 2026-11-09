---
tipo: adr
area: social e comunidades
status: INTENÇÃO
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [AGENTS.md, lib/core/backend/question_discussion_repository.dart, lib/features/share/question_discussion.dart, lib/features/share/share_link_page.dart, supabase/migrations/202611070001_social_graph.sql, supabase/migrations/202611070002_content_delivery.sql, supabase/migrations/202609210001_core.sql]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: media
atualizado: 2026-11-08
---

# ADR-0010 — Comunidades, moderação e ciclo de vida

- **Status:** aceito
- **Data:** 2026-11-07
- **Responsável pela aprovação:** NAGCODE-Dev (responsável pelo projeto)
- **Áreas:** 11, 12
- **Urgência:** Média

## Contexto

> **Atualização 2026-11-08.** O SQL social e o de pacotes foram promovidos a
> `supabase/migrations/202611070001_social_graph.sql` e
> `supabase/migrations/202611070002_content_delivery.sql`, com teste local em
> `supabase/tests/social_schema.sql`. Os parágrafos abaixo descrevem o estado
> em `05a8fc1`; onde dizem “SQL solto”, leia-se “SQL hoje congelado em
> `docs/historico/sql/`”. **Nenhuma migration foi aplicada no Supabase
> remoto.** A moderação mínima é implementada em seguida, na migration
> `202611070003_moderation.sql`.

“Comunidade” no código é um rótulo de origem de prova, não uma entidade. O
normativo pede um sistema social inteiro que não existe.

- **O que o normativo exige.** `AGENTS.md:396-431` (seção 13, “Comunidades
  dinâmicas”): criação sugerida quando duas ou mais pessoas distintas
  demonstram intenção semelhante sobre o mesmo assunto/prova/questão;
  agrupamento por entidades (prova/instituição/ano, ID da questão, banca,
  disciplina/tópico, intenção), não por coincidência literal de texto;
  cinco estados (`suggested`, `active`, `dormant`, `archived`, `reopened`);
  “uma comunidade inativa não deve ser apagada automaticamente”; proteções:
  evitar duplicatas, fundir equivalentes preservando histórico, rate
  limiting, **denúncia e moderação**, regras contra spam, critérios
  configuráveis de inatividade, não expor perguntas privadas sem
  consentimento.
- **O que existe.** `ls lib/features` → `auth home onboarding publish quiz
  result search share`. `find lib -ipath "*communit*" -o -ipath
  "*comunidade*"` → vazio. Não há feature, tela, modelo ou repositório de
  comunidade.
- **“community” é só `source_type`.** As ocorrências estão em
  `lib/domain/models/exam.dart:58`, `lib/core/widgets/source_badge.dart:20-31`
  e `lib/core/backend/exam_publication_service.dart:80,187`; no SQL, é o
  check `source_type in ('official','community','unverified')`
  (`supabase/migrations/202609210001_core.sql:24-25`,
  `docs/historico/sql/prova_social_backend_v1.sql:4-5`). **Não existe tabela
  `communities`** em migration nem em SQL solto.
- **O social implementado é comentário + seguir tópico.**
  `lib/core/backend/question_discussion_repository.dart` (137 linhas) e
  `lib/features/share/question_discussion.dart` (278 linhas), usada só em
  `lib/features/share/share_link_page.dart:122`.
  `grep -niE "denunc|report|moder|admin|block"` nessa UI → **0** linhas.
- **Moderação não é alcançável nem pelo schema.**
  `docs/historico/sql/prova_social_backend_v1.sql:61` define
  `status … check (status in ('visible','hidden','deleted'))`, mas a política
  de update é só do autor e só permite `('visible','deleted')` (`:132-134`);
  a de delete é só do autor (`:135`). Não há papel de moderador, política
  administrativa, nem tabela de denúncia em nenhum SQL do repositório.
  `hidden` existe no check e **não é produzível** por nenhum caminho
  previsto — nem pelo app, nem pela RLS.
- **Ciclo de vida inexistente.** Não há código nem tabela para sair,
  arquivar, reabrir, fundir ou marcar inatividade. O `on delete cascade` de
  `question_comments.question_id` e `.author_id`
  (`docs/historico/sql/prova_social_backend_v1.sql:57-58`) faz o oposto do que o normativo pede
  para conteúdo inativo: apagar a questão ou o perfil apaga a discussão.
- **Quatro tabelas lidas pelo app não estavam migradas (histórico).** Em
  `05a8fc1`, o app lia `topics`, `topic_follows`, `question_comments`
  (`prova_social_backend_v1.sql:9,22,55`) e `content_files`
  (`content_delivery_v1.sql:2`) de SQL solto. As migrations criavam 9 tabelas
  (`profiles`, `exams`, `questions`, `private.question_keys`, `favorites`,
  `attempts`, `attempt_answers`, `media_assets`, `exam_media`);
  `digitalization_v1.sql:2,17` duplicava as duas últimas. **Em 2026-11-08, as
  quatro tabelas passaram a ser criadas por migrations locais**, e o script
  local passou a aplicá-las e testá-las.
- **RPCs existem e são usados.** `grep -rn "\.rpc" lib/ --include=*.dart`
  → **6** chamadas: `attempt_repository.dart:40` (`submit_exam_attempt`) e
  `exam_publication_service.dart:101,102,119,133,134` (`publish_exam*`).
  Nenhuma RPC social.

**Limites.** Se o SQL solto foi aplicado ao banco implantado é
**não verificável** daqui: o banco “Prova Social” está fora de alcance e
nenhuma consulta read-only foi feita nele. A ausência de tabela de
moderação foi verificada nos arquivos do repositório, não no catálogo de
produção. Não foi medido volume de comentários nem necessidade real de
moderação (não há dado de uso).

## Decisão

**Aprovada em 2026-11-07 pelo responsável pelo projeto (NAGCODE-Dev).**
Alternativa escolhida: **A — moderação mínima + SQL versionado, comunidades
depois.** A decisão é não construir comunidades agora, fechar primeiro o que
já está exposto e sem proteção, e registrar o resto como fase posterior:

1. **Moderação mínima do que existe:** decidir como um comentário abusivo
   sai do ar hoje. Sem isso, a única via é o autor apagar o próprio
   comentário — o que não resolve denúncia de terceiro. Isso exige papel
   de moderador e política RLS, ou seja, SQL autorizado pelo responsável.
2. **Promover o SQL solto a migration** (ou removê-lo do caminho de
   execução), para que `topics`, `topic_follows`, `question_comments` e
   `content_files` tenham origem única e versionada. Hoje o app depende de
   tabelas que nenhuma migration cria.
3. **Trocar o cascade destrutivo por política explícita** para conteúdo
   social, coerente com “não apagar automaticamente” (`AGENTS.md:420`).
4. **Comunidades dinâmicas ficam como fase posterior**, com ADR próprio
   quando houver decisão de produto sobre agrupamento, rate limiting e
   moderação — não como refactor do que existe.

## Alternativas

- **A — Moderação mínima + SQL versionado, comunidades depois
  (escolhida).** Prós: protege o que já está no ar; custo concentrado em
  RLS e migration, não em feature nova; elimina a dependência de SQL solto.
  Contras: exige SQL e decisão de papel de moderador; não entrega a seção
  13 do normativo.
- **B — Construir comunidades conforme `AGENTS.md:396-431`.** Tabela de
  comunidades, estados, agrupamento por entidades, fusão com histórico,
  rate limiting, denúncia, moderação, inatividade configurável. Prós:
  cumpre o normativo; é o diferencial social do produto. Contras: é a
  maior feature não implementada do documento, exige detecção de intenção
  semelhante (não trivial), política de privacidade e consentimento, e
  superfície de abuso muito maior. Sem moderação pronta, lançar isso
  aumenta risco em vez de reduzir.
- **C — Desligar o social existente.** Remover comentários e seguir tópico
  até haver moderação. Prós: risco de abuso vai a zero; menos tabelas
  dependendo de SQL solto. Contras: remove funcionalidade que está no ar e é
  usada pela tela de compartilhamento; contradiz `AGENTS.md:382-394`
  (“Questão como objeto social”).
- **D — Não fazer.** Prós: custo zero. Contras: comentário abusivo não tem
  como ser removido por ninguém além do autor; `hidden` é estado morto;
  quatro tabelas continuam sem migration; o normativo continua descrevendo
  um sistema que não existe.
- **E — Moderação só por serviço (sem RLS de moderador).** Backend separado
  com service role apagando/ocultando conteúdo. Prós: não expõe papel
  privilegiado ao cliente. Contras: `publish_to: none` e arquitetura atual
  são cliente → Supabase direto; introduz um servidor a operar, monitorar e
  proteger, o que é mais custo que uma política RLS.

## Consequências e reversão

- **Positivas de A:** conteúdo social passa a ter um caminho de remoção por
  terceiro; tabelas lidas pelo app passam a existir na trilha de migration;
  histórico para de ser apagado por cascade; o vault passa a refletir o que
  é produto e o que é fase posterior.
- **Negativas/custos:** papel de moderador é superfície privilegiada e
  exige decidir quem o tem e como é concedido; migration de RLS em tabela
  com dados precisa de teste de política (não só de schema); comunidades
  adiadas significam que a seção 13 continua não atendida.
- **Riscos:** política de update/delete mal escrita pode permitir que
  usuário comum oculte comentário alheio (escalação de privilégio) ou que
  moderador apague histórico sem rastro. Mitigação: teste de RLS por papel
  antes de aplicar, em banco local.
- **Reversão:** política RLS é reversível com migration de descida, mas
  conteúdo apagado por cascade **não** é recuperável — por isso o item 3
  vem antes de qualquer limpeza. Código Dart é reversível por `git revert`.

## Evidências e validação

- Áreas: [[../../09 - Auditoria/Áreas/11 - Social, discussões, comunidades e denúncia|Área 11]],
  [[../../09 - Auditoria/Áreas/12 - Supabase, schema, RLS e RPCs|Área 12]].
- Código e SQL: [question_discussion_repository.dart](../../../lib/core/backend/question_discussion_repository.dart),
  [question_discussion.dart](../../../lib/features/share/question_discussion.dart),
  [share_link_page.dart](../../../lib/features/share/share_link_page.dart),
  [docs/historico/sql/prova_social_backend_v1.sql](../../../docs/historico/sql/prova_social_backend_v1.sql),
  [docs/historico/sql/content_delivery_v1.sql](../../../docs/historico/sql/content_delivery_v1.sql),
  [202609210001_core.sql](../../../supabase/migrations/202609210001_core.sql),
  [AGENTS.md](../../../AGENTS.md).
- Testes: [question_discussion_repository_test.dart](../../../test/question_discussion_repository_test.dart),
  [source_badge_test.dart](../../../test/source_badge_test.dart),
  [share_link_service_test.dart](../../../test/share_link_service_test.dart).
- **Exigido antes de implementar:** teste de RLS por papel (autor, leitor
  anônimo, moderador) em banco local via `scripts/local_db_test.sh`;
  inventário das tabelas realmente existentes no banco local comparado com
  as migrations; teste de que `hidden` é alcançável só por quem deve;
  para B, decisão de produto sobre agrupamento e consentimento antes de
  qualquer schema. **Parcialmente cumprido em 2026-11-08:** o schema social
  foi migrado e `social_schema.sql` cobre autor, outro usuário e anônimo; a
  moderação e a denúncia entram na tarefa seguinte. A decisão de produto
  sobre comunidades (alternativa B) continua pendente.
- Comandos de reprodução:
  `find lib -ipath "*communit*" -o -ipath "*comunidade*"` (vazio);
  `grep -rniE "communit|comunidade" supabase/*.sql supabase/migrations/*.sql`
  (só `source_type`); `grep -rn "\.rpc" lib/ --include=*.dart | wc -l` → 6;
  `sed -n '129,136p' docs/historico/sql/prova_social_backend_v1.sql`.
- Relacionados: [[ADR-0002 - Modelo de questão, gabarito e publicação|ADR-0002]],
  [[ADR-0003 - Versionamento de conteúdo e vínculo da tentativa|ADR-0003]]
  (cascade e histórico), [[ADR-0007 - Licença do app e fixtures de terceiros|ADR-0007]],
  [[../../03 - Domínios/Contratos de Domínio Alvo|Contratos de Domínio Alvo]].