---
tipo: checklist
area: prontidão para refatoração global
status: PARCIAL
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [knowledge-base/, lib/, test/, supabase/]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: alta
atualizado: 2026-11-05
---

# Critério de prontidão para a refatoração global

Pergunta que esta nota responde: **o conteúdo acumulado no vault já permite
planejar o app novo, ou ainda estamos coletando?** A resposta é uma lista com
evidência, não uma sensação.

A refatoração global é tratada aqui como "reconstruir o app sobre o que foi
aprendido", no espírito do [Plano Mestre](../00%20-%20Central/Plano%20Mestre.md)
— não como big-bang (risco 12 da [[../09 - Auditoria/Síntese da Refatoração|Síntese]]).

## Os 12 pré-requisitos e o estado hoje

| # | Pré-requisito | Onde está | Estado |
|---:|---|---|---|
| 1 | Baseline e esteira verde | [[../00 - Central/Estado Atual]], Lote 0 | **Feito e commitado** 2026-11-05 (`27403be`, `46eb9a0`): `qa/run_static.sh` exit 0 medido direto no script, 313 testes + 1 ignorado. **Falta:** chegar ao `main` do upstream por PR — o fork não roda Actions e `git push upstream main` foi recusado (403). |
| 2 | Modelo de domínio atual inventariado | [[../03 - Domínios/Modelo de Domínio Atual]] | **Feito** — entidades, campos, 4–5 sites de pontuação, formato perdido na borda. |
| 3 | Contratos alvo especificados (C1–C7) | [[../03 - Domínios/Contratos de Domínio Alvo]] | **Feito em nível de especificação**; **não aprovado** (ADR-0002/0003 pendentes). |
| 4 | Inventário de dados e persistência | [[../04 - Infraestrutura/Inventário de Persistência e Dados]] | **Feito** para o repo; **não resolvido**: 4 tabelas usadas pelo app só existem em SQL solto; `questions` não tem `format` e força 2–8 alternativas, então **discursiva não cabe no schema**; o estado remoto do Supabase segue não verificado. |
| 5 | Mapa de dependências medido | [[../02 - Arquitetura/Mapa de Dependências]] | **Feito** — arestas, fan-in/out, vendor por camada, 26 usos de `Supabase.instance` em 10 arquivos, 7 defaults de singleton. |
| 6 | Fluxos reais com estados de falha | [[../02 - Arquitetura/Fluxos Reais]] | **Feito** — F1 importação, F2 tentativa/sync (máquina de 6 estados, backoff, idempotência), F3 publicação, F4 consumo. |
| 7 | Inventário de telas e cobertura | [[../01 - Produto/Inventário de Telas e Cobertura]] | **Feito** — 17 destinos, 34 `MaterialPageRoute`, cobertura por tela, ausências. |
| 8 | ADRs estruturais aceitos | [[../06 - Decisões/ADR/README]] | **Bloqueado em você:** 12 ADRs propostos, 0 aceitos. A refatoração não começa sem 0002 (modelo), 0003 (versão) e 0004 (persistência). |
| 9 | Testes de caracterização do comportamento que vai mudar | `test/scoring_definitions_characterization_test.dart`, `test/publication_characterization_test.dart`, `test/draft_resume_characterization_test.dart` (`ff3be0c`) | **Parcialmente feito** — 23 expectativas novas congelam as cinco contagens de pontuação, a validação e o corpo da publicação, e a retomada posicional do rascunho. **Falta:** o que protege o Lote 4 da síntese — extração de controller de `QuizPage`/`PublishPage` ainda só tem os 7 widgets de `test/ux/`, que quebram por construção. |
| 10 | Teste ponta a ponta do fluxo do §21 | não há `integration_test/` | **Não existe** (ver área 14 e [[../09 - Auditoria/Síntese da Refatoração|síntese]]). |
| 11 | Orçamento não-funcional medido (APK, OCR tempo/memória, tamanho de payload, cobertura por arquivo) | — | **Não existe.** Só números pontuais (arm64 82,1 MB; universal local 248,1 MB). |
| 12 | Vault versionado com hierarquia documental | `eebb2b0` | **Feito no fork:** 76 arquivos versionados (70 notas + 6 `.obsidian/*.json`), 12.590 linhas. Estado por dispositivo (`workspace*.json`, cache, lixeira) fica fora do Git. Falta o PR para o `main` do upstream. |

## Leitura honesta

**O que já dá para fazer hoje:** desenhar o app novo. As notas 2, 3, 5, 6, 7
respondem "o que o app é, onde está, como flui e o que cobre" com evidência
`arquivo:linha`. Um plano de camadas, uma tabela de rotas e um contrato de
domínio podem ser escritos agora sem adivinhação.

**O que ainda não dá:** executar a refatoração global. Os motivos, em ordem de
causa — não são burocracia, são três coisas que uma refatoração *precisa* saber e
hoje não sabe:

1. **Não existe resposta para "mudou o comportamento?" na camada de tela** (itens 9
   e 10). A caracterização das regras de negócio foi escrita em 2026-11-05 e hoje
   congela pontuação, publicação e rascunho — mas os 7 testes de widget em
   `test/ux/` pumpam a tela-mãe: ao extrair controllers de `QuizPage`
   (1.501 linhas, 16 classes, 15 privadas), eles **vão quebrar por construção**, e
   continua sem como distinguir "quebrei o teste" de "quebrei o app". Falta a
   caracterização que sobrevive à mudança de estrutura.
2. **A refatoração é obrigada a escolher uma regra que é decisão de produto**
   (item 8). `blank` conta no denominador? `unknownAnswer` entra na prova de
   erros? discursiva é publicável? Hoje cada lugar do código responde diferente
   ([[../03 - Domínios/Modelo de Domínio Atual]] mede cinco definições, seis
   contando `unanswered`; os números estão congelados por teste desde `ff3be0c`,
   o que torna a contradição visível sem resolvê-la). Um refactor não pode "manter
   o comportamento" porque o comportamento é contraditório — escolher é escrever
   ADR-0002/0003/0004, e isso cabe ao responsável, não ao agente.
3. **O destino dos dados é desconhecido** (item 4). `answers` é mapa posicional
   (`attempt_draft_store.dart:15`); convertê-lo para `QuestionId` é migração de
   dados, e o schema autoritativo não existe no repo: 4 tabelas lidas pelo app só
   aparecem em SQL solto que nenhum script aplica, `media_assets`/`exam_media`
   estão definidos nas duas trilhas, e `questions` **não tem coluna `format` e
   impõe 2–8 alternativas** (`202609210001_core.sql:45-47`) — ou seja, o produto
   alvo não cabe no banco atual sem migração. Migração sobre schema desconhecido
   é chute.

Agravante operacional que permanece: o trabalho está em `NAGC-Student/main`
(`27403be` → `ff3be0c`), não no `main` do upstream. `git push upstream main`
retorna 403 — `NAGC-Student` não tem escrita em `NAGCODE-Dev` — e o fork não roda
Actions (`gh run list -R NAGC-Student/Prova-Social` vazio). Enquanto o PR não
entrar, o baseline publicado continua vermelho (schedule de 2026-11-05 falhou em
"Resolver dependências Android" por 504 do download do `kotlin-compiler-embeddable`,
e o push do PR #18 falhou em "QA estático" por `dart format`), e uma falha nova
de refatoração não é atribuível.

## O que NÃO está validado (limite honesto desta etapa)

- **Tudo que está escrito aqui vem de leitura estática** de imports, SQL, Dart e
  testes no worktree, mais testes Dart executados localmente. Nada foi executado
  em Android/iOS, navegador real, leitor de tela ou Supabase remoto — e as
  migrations nunca foram rodadas nesta máquina (sem `initdb`; o runner PGlite pede
  um módulo instalado fora do repo).
- **O worktree está limpo e commitado** desde `ff3be0c`; as medidas valem para
  `05a8fc1` + `27403be` + `eebb2b0` + `46eb9a0` + `ff3be0c`, que só existem no fork.
- **Números que eu errei e corrigi nesta verificação:** chamadas de
  `Supabase.instance` são **26** em 10 arquivos (eu havia escrito 24); destinos em
  classe privada são **4** (havia dito 5); a queda 296 → 290 testes foi conferida
  (os 4 probes movidos continham 6 `test()`), e hoje é 290 → 313 com os 23 testes
  novos.
- **Erro de método que eu cometi e corrigi:** declarei o gate estático verde
  lendo `$?` de um pipeline (`bash qa/run_static.sh | tail`), que devolve o código
  do `tail`. O `flutter analyze` tinha 1 issue — `unused_local_variable` em
  `test/manual/corpus_probe.dart:182` — introduzida quando movi a saída do probe
  para buffer. Corrigido em `46eb9a0` e revalidado com exit 0 medido no próprio
  script.
- **Agora verificado por teste** (era inferência de leitura): o `format` importado
  não chega ao corpo publicado, o tópico vira `Geral` e `p_source_type` é sempre
  `community` — `test/publication_characterization_test.dart`.
- **Continua inferência, não teste:** se `format` sobrevive ao ciclo completo
  importação → publicação → download no servidor real.

## Gatilho sugerido para encerrar esta etapa de investigação

Encerrar "investigar e acumular" e abrir "planejar o app novo sobre o atual"
(strangler por fluxo, sem big-bang) quando:

- [ ] ADR-0002, 0003 e 0004 existirem como arquivos com status `aceito`.
- [x] Houver caracterização nomeada das cinco contagens de pontuação, da validação
      e do corpo da publicação (serviço), e da retomada posicional do rascunho —
      `ff3be0c`, 23 expectativas.
- [ ] Faltar só isso: a validação de publicação **da tela** (`publish_page.dart`) e
      uma caracterização que sobreviva à extração de controller de `QuizPage`.
- [ ] As migrations reproduzirem 100 % das tabelas que o cliente toca (nenhuma
      dependência de SQL solto), com `local_db_test.sh` no CI.
- [x] O vault estiver commitado — `eebb2b0`, 76 arquivos versionados.
- [ ] Houver um `integration_test/` mínimo (documento sintético) percorrendo
      importar → revisar → publicar → fazer → finalizar.

Restam, portanto, três itens de produto e de teste — não mais "coletar conteúdo".

## O que a caracterização congelou (`ff3be0c`)

Uma única tentativa sobre uma prova de 5 questões (1 certa, 1 errada, 1 sem
gabarito, 1 com gabarito `5` fora de 2 alternativas, 1 com tópico vazio) produz:

| Grandeza | Onde é calculada | Valor |
|---|---|---:|
| `correct` | `exam.dart:129-135` | 2 |
| `correctableCount` | `exam.dart:143-150` | 3 |
| `scorePercent` | `exam.dart:137-141` | 67 |
| `wrongQuestionIndices` | `exam.dart:152-158` | 1 |
| `unanswered` | `exam.dart:192-195` | 2 |
| soma de `byTopic.total` | `exam.dart:197-213` | 3 |
| "Revisar" na tela | `result_page.dart:280` | 3 |
| `total` do JSON | `exam.dart:220` | 5 |

Três consequências que hoje só existiam como leitura e agora são executadas:

- gabarito fora do intervalo faz `scorePercent` passar de 100 % (medido: 150).
- `score_percent` devolvido por `submit_exam_attempt` é descartado pelo cliente; o
  número da tela vem de `correctableCount`.
- a mesma tentativa remota só é aceita se as duas definições coincidirem — o
  cliente recusa a entrega inteira quando o gabarito do servidor não cabe nas
  alternativas (`attempt_repository.dart:84-86`), e o `CHECK` do banco
  (`correct_index between 0 and 7`) não cruza com o tamanho de `options`.

Publicação: questão `openEnded` aceita pelo parser é rejeitada antes de qualquer
RPC; uma questão inválida reprova a prova inteira; `topic` vira `Geral` no Dart
(`exam_publication_service.dart:64`) **e** o `default 'Geral'` já existe no banco
(`202609210001_core.sql:43`), então corrigir só o cliente não recupera o tópico;
`p_source_type` é sempre `community`; a prova volta como publicada mesmo quando o
pacote digital falha.

Rascunho: as respostas são índices posicionais, então retomar sobre uma versão
reordenada da prova transforma 2 corretas em 0; respostas fora do novo tamanho
desaparecem sem aviso; o `clientAttemptId` é preservado na retomada e a fila local
recusa payload diferente sob o mesmo ID.

## O que esta etapa já produziu (2026-11-05)

| Nota | Conteúdo | Status |
|---|---|---|
| [[../03 - Domínios/Modelo de Domínio Atual]] | domínio real, 236 linhas, políticas espalhadas | VALIDADO |
| [[../03 - Domínios/Contratos de Domínio Alvo]] | C1–C7 com invariantes e testes exigidos | INTENÇÃO |
| [[../04 - Infraestrutura/Inventário de Persistência e Dados]] | 3 trilhas de SQL, chaves locais, RPCs | VALIDADO |
| [[../02 - Arquitetura/Mapa de Dependências]] | arestas, vendor, singletons, classes por arquivo | VALIDADO |
| [[../02 - Arquitetura/Fluxos Reais]] | F1–F4 com estados de falha | VALIDADO |
| [[../01 - Produto/Inventário de Telas e Cobertura]] | 17 telas, navegação, cobertura | VALIDADO |

## Links

[[../00 - Central/Roadmap]] · [[../09 - Auditoria/Síntese da Refatoração]] ·
[[../06 - Decisões/ADR/README]] · [[../00 - Central/Estado Atual]] ·
[[Validação Atual]]
