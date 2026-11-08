---
tipo: adr
area: versionamento de conteúdo
status: INTENÇÃO
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [lib/core/backend/local_exam_store.dart, lib/core/backend/attempt_draft_store.dart, lib/core/backend/attempt_repository.dart, lib/core/import/question_parser.dart, supabase/migrations/202609210001_core.sql, supabase/migrations/202609210003_attempt_idempotency.sql, AGENTS.md]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: media
atualizado: 2026-11-07
---

# ADR-0003 — Versionamento de conteúdo e vínculo da tentativa à versão resolvida

- **Status:** aceito
- **Data:** 2026-11-07
- **Responsável pela aprovação:** NAGCODE-Dev (responsável pelo projeto)
- **Áreas:** 2, 6, 12
- **Urgência:** Alta

## Contexto

O trilho local já amarra a tentativa ao conteúdo; o trilho remoto não.

- **Existe binding local.** `lib/core/backend/local_exam_store.dart:117-120`
  define `attemptExamId` como `id` + `sha256` de
  `[{statement, options, correctIndex}]`, com o comentário explícito
  “Editing the question set starts a distinct attempt instead of restoring
  answers against different alternatives”. Em `:123-124`,
  `exam.id = downloaded ? id : attemptExamId`. Ou seja: prova local não
  baixada muda de identidade quando o conteúdo muda; prova baixada/remota
  mantém o UUID estável.
- **Não existe binding remoto.** `public.attempts`
  (`supabase/migrations/202609210001_core.sql:90-100`) guarda apenas
  `exam_id`, contagens e tempos. `grep -rn "version\|revision\|content_hash"
  supabase/migrations/*.sql` não retorna **nenhuma** linha: não há coluna de
  versão, revisão ou hash em lugar nenhum do schema migrado.
- **A entidade esperada não existe.** `AGENTS.md:452` lista `exam_versions`
  entre as entidades mínimas; `grep -rn "exam_versions" supabase/ lib/`
  retorna vazio. Também não existem `alternatives`, `answer_keys`, `sources`
  ou `bookmarks` como tabelas (o schema usa `options` jsonb,
  `private.question_keys`, `source_name`/`source_url` e `favorites`).
- **Histórico é deletável por cascade.** `public.questions.exam_id … on delete
  cascade` (`core.sql:41`), `public.attempts.exam_id … on delete cascade`
  (`:93`) e `public.attempt_answers.question_id … on delete cascade` (`:104`).
  Remover prova ou questão apaga respostas históricas sem registro do que foi
  resolvido.
- **Respostas são posicionais no aparelho.** `final Map<int, int> answers`
  (`lib/core/backend/attempt_draft_store.dart:15`), chave
  `attempt_draft_v1_$examId` (`:72`). A posição só é estável se a ordem e a
  quantidade de questões não mudarem.
- **A conversão posição → UUID usa a ordem atual.**
  `lib/core/backend/attempt_repository.dart:31-37` monta
  `payload[exam.questions[index].id] = submission.answers[index]`; `:58-61`
  reconstrói o mapa inverso; `:119-121` remontam as respostas posicionais a
  partir da correção. Nada compara o conteúdo resolvido com o conteúdo
  vigente.
- **Há rede, mas ela cobre outro risco.** `attempt_repository.dart:64-101`
  rejeita a correção do servidor se contagem, ids, `selected_index`,
  `marked_for_review` ou totais divergirem da entrega local, preservando as
  respostas no aparelho. Isso detecta divergência **servidor × entrega**, não
  deriva de conteúdo entre o momento da resposta e o momento do envio: o
  payload e a conferência usam a mesma ordem atual, então a troca passa.
- **Idempotência não é versionamento.** `p_client_attempt_id`
  (`supabase/migrations/202609210003_attempt_idempotency.sql:20`, tabela de
  dedupe em `:56`) evita entrega duplicada e guarda o payload da requisição,
  mas não identifica a revisão do conteúdo.
- **Dois conceitos de “versão” já em uso, ambos diferentes deste ADR:**
  `schemaVersion: 1` é a versão do **formato do pacote**
  (`lib/core/backend/digital_exam_service.dart:66,78,133-134`);
  `versionLabel`/`alternateVersions`
  (`lib/core/import/question_parser.dart:32-33,69-90`,
  `lib/features/publish/publish_page.dart:1642-1690,2006-2030`) são
  **variantes de banca** da mesma questão (ordens diferentes de alternativas),
  não histórico de revisão.

**Limites.** Não foi consultado o banco implantado — a ausência de coluna vem
dos arquivos de migration. Não há medição de quantas provas publicadas já
foram editadas após publicação (isso exigiria leitura em produção, que está
fora de alcance). `lib/` e `supabase/` idênticos entre `05a8fc1` e `e084ef6`.

## Decisão

**Aprovada em 2026-11-07 pelo responsável pelo projeto (NAGCODE-Dev).**
Alternativa escolhida para o passo imediato: **B — hash de conteúdo no
cliente, sem schema**; a criação de `exam_versions` no servidor (C/D) fica
para etapa posterior, com SQL autorizado. A decisão aprovada é:

1. **Nomear o conceito antes de criar tabela.** Registrar no vault que
   `schemaVersion` = formato, `versionLabel` = variante de banca, e que
   “revisão de conteúdo” é um terceiro conceito hoje inexistente. Sem isso,
   qualquer migration nasce com nome ambíguo.
2. **Estender o binding que já funciona.** Reusar a ideia do `attemptExamId`
   (hash de conteúdo) como identidade da revisão, em vez de inventar
   `exam_versions` do zero: a tentativa passa a carregar o hash/versão
   resolvida, e a restauração de rascunho recusa restaurar quando o hash
   difere — exatamente a regra que o trilho local já aplica.
3. **Só então decidir o schema.** Se a revisão precisa ser consultável e
   editável no servidor, isso é migration (`exam_versions` ou coluna
   `content_hash` + tabela de revisões) e exige SQL autorizado pelo
   responsável, com política explícita para o cascade de histórico.

## Alternativas

- **A — Não fazer.** Deixar o trilho remoto sem vínculo. Prós: custo zero,
  nenhuma migration, nenhum dado migrado. Contras: editar uma prova publicada
  reinterpretar respostas antigas em silêncio; `on delete cascade` continua
  apagando histórico; a assimetria local × remoto permanece e cada extração
  de fluxo herda o problema.
- **B — Hash de conteúdo no cliente, sem schema (escolhida para o passo imediato).** Gravar o hash resolvido
  junto do rascunho e da fila de sincronização (arquivos locais), bloquear
  restauração e envio quando o conteúdo remoto mudou. Prós: nenhuma migration;
  reaproveita `local_exam_store.dart:120`; reversível por `git revert`.
  Contras: o servidor continua sem histórico consultável; a conferência depende
  de o cliente buscar o conteúdo atual; não resolve o cascade.
- **C — `exam_versions` no servidor (como o `AGENTS.md` espera).** Tabela de
  revisões, `attempts.exam_version_id`, questões penduradas na revisão,
  cascade trocado por `restrict`/snapshot. Prós: histórico auditável,
  resultado reproduzível, atende à especificação normativa. Contras: migration
  grande, backfill das provas já publicadas (sem versão conhecida), RPC
  `submit_exam_attempt` e `publish_exam*` mudam de contrato, RLS nova. É a
  opção mais cara e a que mais exige caracterização antes.
- **D — Snapshot imutável por tentativa.** Copiar o conjunto resolvido
  (enunciado, alternativas, gabarito) para dentro da tentativa no momento da
  entrega. Prós: reprodução exata sem tabela de revisões; imune a edição
  posterior. Contras: duplica conteúdo por tentativa (custo de storage e
  bandwidth), expõe gabarito no cliente se o snapshot for local, e não permite
  “o que mudou entre a versão que fiz e a atual”.

## Consequências e reversão

- **Positivas:** respostas deixam de ser reinterpretadas após edição;
  resultado passa a ser reproduzível; a regra local e a remota convergem;
  o cascade destrutivo ganha uma política decidida em vez de implícita.
- **Negativas/custos:** rascunhos antigos sem hash gravado precisam de regra
  de compatibilidade (restaurar como hoje, ou descartar com aviso) — isso é
  decisão de produto, não detalhe técnico; backfill de provas publicadas sem
  versão conhecida é impossível de fazer com precisão e precisará de um
  valor sentinela assumido; a fila de sincronização ganha um campo e um
  estado de recusa.
- **Riscos:** bloquear restauração pode fazer o usuário perder progresso
  visível se a prova foi editada por outra pessoa. Mitigação: preservar as
  respostas no aparelho e oferecer exportação, como já faz
  `attempt_repository.dart:66-67`.
- **Reversão:** B é só cliente — `git revert` restaura o comportamento, e os
  hashes gravados viram campo ignorado (sem perda). C e D só são reversíveis
  com migration de descida escrita **antes** da subida e com backup
  verificado; trocar cascade de volta não recupera linhas já apagadas.

## Evidências e validação

- Áreas: [[../../09 - Auditoria/Áreas/02 - Domínio, modelos e regras|Área 02]],
  [[../../09 - Auditoria/Áreas/06 - Tentativas, resultados e pontuação|Área 06]],
  [[../../09 - Auditoria/Áreas/12 - Supabase, schema, RLS e RPCs|Área 12]].
- Código: [local_exam_store.dart](../../../lib/core/backend/local_exam_store.dart),
  [attempt_draft_store.dart](../../../lib/core/backend/attempt_draft_store.dart),
  [attempt_repository.dart](../../../lib/core/backend/attempt_repository.dart),
  [202609210001_core.sql](../../../supabase/migrations/202609210001_core.sql),
  [202609210003_attempt_idempotency.sql](../../../supabase/migrations/202609210003_attempt_idempotency.sql),
  [AGENTS.md](../../../AGENTS.md).
- Testes: [draft_resume_characterization_test.dart](../../../test/draft_resume_characterization_test.dart)
  (210 linhas), [attempt_draft_store_test.dart](../../../test/attempt_draft_store_test.dart)
  (163), [attempt_repository_test.dart](../../../test/attempt_repository_test.dart),
  [scoring_definitions_characterization_test.dart](../../../test/scoring_definitions_characterization_test.dart)
  (354), [quiz_offline_submission_test.dart](../../../test/quiz_offline_submission_test.dart)
  (441).
- **Exigido antes de implementar:** teste que edita o conjunto de questões de
  uma prova **baixada** e afirma o que acontece com o rascunho posicional
  (hoje não coberto); teste de rejeição da correção já existe em
  `attempt_repository.dart:64-101` e deve ser caracterizado antes de mexer;
  para C/D, schema conferido read-only em banco local via
  `scripts/local_db_test.sh` e SQL submetido ao responsável.
- Comandos de reprodução:
  `grep -rn "exam_versions" supabase/ lib/` (vazio);
  `grep -rn "version\|revision\|content_hash" supabase/migrations/*.sql` (vazio);
  `grep -n "attemptExamId" lib/core/backend/local_exam_store.dart`.
- Relacionados: [[ADR-0002 - Modelo de questão, gabarito e publicação|ADR-0002]],
  [[ADR-0004 - Persistência local e durabilidade|ADR-0004]],
  [[../../03 - Domínios/Contratos de Domínio Alvo|Contratos de Domínio Alvo]].