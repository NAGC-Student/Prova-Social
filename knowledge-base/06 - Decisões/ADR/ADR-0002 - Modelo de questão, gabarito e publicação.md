---
tipo: adr
area: modelo de questão
status: INTENÇÃO
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [lib/core/import/question_parser.dart, lib/core/import/import_quality_gate.dart, lib/core/backend/exam_publication_service.dart, lib/core/backend/digital_exam_service.dart, lib/features/publish/publish_page.dart, supabase/migrations/202609210001_core.sql, AGENTS.md]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: media
atualizado: 2026-11-07
---

# ADR-0002 — Modelo de questão: objetiva/discursiva, gabarito e publicação

- **Status:** aceito
- **Data:** 2026-11-07
- **Responsável pela aprovação:** NAGCODE-Dev (responsável pelo projeto)
- **Áreas:** 2, 9, 10, 12
- **Urgência:** Alta

## Contexto

O produto exige discursivas; o contrato de publicação só aceita objetiva.

- `AGENTS.md:363-368` (seção “Discursivas”) manda “permitir importar e publicar
  questões discursivas”, “não fingir correção objetiva automática” e armazenar
  resposta esperada, critérios/rubrica e resposta oficial. `AGENTS.md:638`
  repete a exigência como item P1.
- O parser já modela o formato: `enum QuestionFormat { multipleChoice,
  trueFalse, assertion, openEnded, unknown }` em
  `lib/core/import/question_parser.dart:252`. O quality gate usa esse modelo e
  dispensa alternativas para `openEnded`/`unknown`
  (`lib/core/import/import_quality_gate.dart:284-294`).
- A publicação não usa esse modelo. `lib/core/backend/exam_publication_service.dart:44-60`
  exige `options.length` entre 2 e 8, `correctIndex` não nulo e dentro do range;
  o payload em `:61-70` envia apenas `topic`, `statement`, `options` e
  `correct_index` — **nenhum campo de formato, rubrica ou resposta esperada**.
- O schema não tem onde guardar discursiva: `public.questions` não tem coluna
  `format` e impõe `jsonb_array_length(options) between 2 and 8`
  (`supabase/migrations/202609210001_core.sql:39-49`); o gabarito é um índice
  inteiro em `private.question_keys` com `correct_index between 0 and 7`
  (`:52-55`); a resposta do usuário é `selected_index between 0 and 7`
  (`:105`). Não existe tabela de rubrica nem de resposta textual.
- O formato é perdido na volta do pacote: `lib/core/backend/digital_exam_service.dart:192-201`
  reconstrói `ImportedQuestion` sem `format`, caindo no default
  `QuestionFormat.multipleChoice` (`question_parser.dart:28`), e força
  `reviewState: reviewed` (`:200`). No JSON, formato desconhecido vira
  `multipleChoice` (`question_parser.dart:174-177`) enquanto estado de revisão
  desconhecido vira `unreviewed` (`:180-183`) — defaults assimétricos.
- Tela e serviço divergem: `lib/features/publish/publish_page.dart:1317-1344`
  exige `reviewState == reviewed` (`:1340`) e mede `q.statement.length` sem
  `trim` (`:1336`); o serviço aplica `trim` (`exam_publication_service.dart:47`)
  e limita cada alternativa a 4000 caracteres (`:56`), limite que a tela não
  verifica.
- O tópico escolhido é descartado: o payload fixa `'topic': 'Geral'`
  (`exam_publication_service.dart:64`), embora `ImportedQuestion.topic` exista e
  a tela de resultado quebre desempenho por tópico
  (`lib/features/result/result_page.dart:700-711`). Prova publicada nasce toda
  em “Geral”.
- Custódia do gabarito é dupla: no aparelho ele vive dentro do mesmo JSON da
  prova e entra no hash de identidade (`lib/core/backend/local_exam_store.dart:120`);
  no servidor ele fica em schema `private` com RLS
  (`supabase/migrations/202609210002_private_keys_rls.sql`).

**Limites.** Nenhum levantamento de quantas questões discursivas existem nos
fixtures reais foi feito. Nada foi consultado no banco implantado: a evidência
de schema vem dos arquivos de migration, não de `\d public.questions` em
produção. `lib/` e `supabase/` estão idênticos entre `05a8fc1` e `e084ef6`
(`git diff --stat 05a8fc1 HEAD -- lib/ supabase/` vazio), então os números de
linha valem para os dois.

## Decisão

**Aprovada em 2026-11-07 pelo responsável pelo projeto (NAGCODE-Dev).**
Alternativa escolhida: **recomendação em duas etapas**, com a etapa 1
aprovada agora e a etapa 2 condicionada a autorização específica. Nenhum
contrato foi alterado e nenhum SQL foi escrito por este registro.

A decisão aprovada é, em duas etapas independentes:

1. **Curto prazo, sem schema:** declarar objetivamente o que é publicável hoje
   e unificar a validação. Uma única função de contrato compartilhada por tela
   e serviço (mesmos limites, mesmo `trim`, mesmo teto de alternativa, mesma
   exigência de revisão), e `openEnded`/`unknown` bloqueados na publicação com
   mensagem explícita em vez de virarem `multipleChoice` em silêncio. Corrigir
   o descarte de `topic` no payload. Isso remove a divergência sem tocar no
   banco.
2. **Depois, com schema:** suportar discursiva de verdade exige migration
   (`format`, alternativas opcionais, resposta esperada/rubrica, resposta
   textual do usuário) e uma definição de pontuação que **não** invente
   correção automática. Esse passo só entra em execução com SQL autorizado
   pelo responsável e vira ADR próprio ou emenda a este.

Enquanto a etapa 2 não for aprovada, o item “publicar discursivas” do
`AGENTS.md:365` permanece **não atendido** e deve ser registrado como tal, não
como implementado.

## Alternativas

A recomendação escolhida não corresponde a uma única alternativa A–D: ela
executa a unificação de contrato sem schema (próxima de A/D) e deixa a
extensão de schema (B) para etapa posterior, condicionada.

- **A — Objetiva apenas, assumir o requisito como cortado.** Manter o schema,
  remover ou ignorar `openEnded`/`assertion` no parser. Prós: zero migration,
  contrato único e simples. Contras: contradiz `AGENTS.md:365-368` e `:638`;
  exige emenda normativa explícita do responsável, senão a documentação passa a
  mentir. Importações de provas mistas continuariam convertidas em objetiva.
- **B — Estender o schema agora (objetiva + discursiva com rubrica).** Adicionar
  `format`, tornar `options` opcional, criar resposta esperada/rubrica e
  resposta textual, adaptar `submit_exam_attempt` e o cálculo de pontuação.
  Prós: atende à especificação; elimina o default que falsifica formato.
  Contras: mudança de schema e de RPC, RLS nova para rubrica, pontuação deixa
  de ser puramente objetiva, migração de dados publicados. É o caminho mais
  caro e o que mais exige testes de caracterização antes.
- **C — Discursiva só local, objetiva só remota.** Importar e resolver
  discursiva no aparelho (onde o JSON já é livre) e bloquear publicação.
  Prós: nenhuma migration; atende “importar discursivas” e “não fingir
  correção”. Contras: assimetria permanente entre os dois trilhos, botão de
  publicar precisa explicar por que está desabilitado, e “publicar discursivas”
  continua não atendido.
- **D — Não fazer.** Deixar como está. Prós: custo zero imediato. Contras: o
  sistema continua aceitando na tela o que o serviço rejeita (e vice-versa),
  continua marcando questão não revisada como revisada na volta do pacote, e
  continua publicando todo tópico como “Geral”. Cada extração de controller
  prevista no plano strangler carregaria essa divergência adiante.

## Consequências e reversão

- **Positivas da etapa 1:** uma regra de aceitação só, testável; o quality gate
  e a publicação passam a concordar; tópicos publicados deixam de ser todos
  “Geral”; o formato para de ser falsificado na desserialização.
- **Negativas/custos:** provas já publicadas com `topic = 'Geral'` não são
  corrigidas retroativamente (backfill é decisão separada, com SQL); usuários
  que hoje publicam sem revisar todas as questões passariam a ser bloqueados
  pela tela — ou o serviço passaria a exigir revisão, endurecendo o contrato;
  a etapa 2 adiciona superfície de RLS e de pontuação.
- **Riscos:** endurecer a validação compartilhada pode reprovar pacotes que
  hoje passam (falso positivo de regressão). Mitigação: caracterizar o conjunto
  aceito/rejeitado atual antes de unificar.
- **Reversão:** a etapa 1 é só código Dart — `git revert` do commit restaura o
  comportamento anterior, sem dado migrado. A etapa 2 é reversível apenas com
  migration de descida escrita antes da subida; se não houver descida viável,
  a reversão é restaurar backup, e isso precisa estar decidido antes de
  aplicar.

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
  [AGENTS.md](../../../AGENTS.md).
- Testes que já sustentam parte do contrato:
  [publication_characterization_test.dart](../../../test/publication_characterization_test.dart)
  (210 linhas), [import_quality_gate_test.dart](../../../test/import_quality_gate_test.dart),
  [question_parser_test.dart](../../../test/question_parser_test.dart),
  [answer_key_parser_test.dart](../../../test/answer_key_parser_test.dart).
- **Exigido antes de implementar:** caracterização da validação **na tela**
  (`publish_page.dart:1317-1344`), que hoje não tem teste — é a tarefa #11 em
  aberto; teste que afirma que tela e serviço aceitam e rejeitam o mesmo
  conjunto; confirmação read-only do schema em banco **local**
  (`scripts/local_db_test.sh`), nunca no banco “Prova Social”.
- Comandos de reprodução:
  `grep -n "topic': 'Geral'" lib/core/backend/exam_publication_service.dart`;
  `grep -n "enum QuestionFormat" lib/core/import/question_parser.dart`;
  `grep -n "between 2 and 8" supabase/migrations/202609210001_core.sql`.
- Relacionados: [[ADR-0003 - Versionamento de conteúdo e vínculo da tentativa|ADR-0003]]
  (rubrica e resposta esperada são conteúdo versionável),
  [[../../03 - Domínios/Contratos de Domínio Alvo|Contratos de Domínio Alvo]].