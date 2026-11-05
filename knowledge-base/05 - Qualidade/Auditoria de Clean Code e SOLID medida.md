---
tipo: area
area: qualidade de código
status: VALIDADO
classificacao: REFATORAR
nivel: {correcao: 3, testes: 2, acoplamento: 1, clareza: 2, seguranca: 3, robustez: 2, aderencia: 4, portabilidade: 4}
fonte_codigo: [lib/, analysis_options.yaml, test/, git log]
sha: 8ffbba4431fd1f26c677372fff545b2ff52beabb
confianca: alta
atualizado: 2026-11-05
---

# Auditoria de Clean Code e SOLID (medida)

Aplica a régua de [[Critérios de Qualidade de Código]] ao `lib/` atual (60
arquivos, 19.113 linhas, HEAD `8ffbba4`, árvore limpa). Números são reproduzíveis
pelos comandos do §7; casos qualitativos vieram de leitura de código e os
carregados de maior consequência foram re-confirmados por mim linha a linha
(marcados ✔). Não propõe refatoração aqui — só localiza e quantifica.

## 1. Números de cabeça

| Métrica | Valor | Leitura |
|---|---:|---|
| Diagnósticos com as 111 regras habilitadas | **0** | a dívida não é detectável pelo que está ligado |
| Diagnósticos com 33 regras de arquitetura extras | **901** | 796 são `public_member_api_docs` (ruído); os 105 restantes são reais |
| `avoid_catches_without_on_clauses` | **51** | 51 blocos que engolem qualquer exceção |
| `avoid_redundant_argument_values` | 19 | — |
| `discarded_futures` | **8** | chamadas async sem `await` em `home_page`, `auth_page`, `auth_gate`, `search_page`, `attempt_sync_service:319` |
| `avoid_slow_async_io` | 8 | `File.exists` etc. em caminho quente |
| `strict_raw_type` | 6 | `Map<dynamic, dynamic>` vindo de JSON (`attempt_sync_service.dart:541`, `digital_exam_service.dart:139,207`) |
| `parameter_assignments` | 4 | `question_parser.dart:511,512,522,523` |
| `avoid_classes_with_only_static_members` | 4 | `app_theme.dart:53,65`, `share_link_service.dart:8`, `home_page.dart:2405` |
| `only_throw_errors` / `avoid_positional_boolean_parameters` | 0 / 0 | duas frentes em que o repo já está limpo |
| Classes no `lib/` | 214 (60 arquivos) | 60 delas dentro dos 4 arquivos de tela |
| Portas (`abstract class`/`abstract interface class`) | **4** | 3 `abstract class` + 1 `abstract interface class` |
| Amplificação de mudança (média dos 40 últimos commits que tocaram `lib/`) | **7,03 arquivos/commit** (máx. 32) | métrica de Ousterhout: um requisito vira 7 edições |

## 2. DIP — o achado estrutural

- **3 `abstract class` de produção** no `lib/` inteiro: `AttemptSubmitter`
  (`lib/core/backend/attempt_submission.dart:35`), `DraftStorage`
  (`lib/core/backend/attempt_draft_store.dart:32`), `AttemptQueueStorage`
  (`lib/core/backend/attempt_sync_service.dart:52`) + `ExamPayloadStorage`
  (`lib/core/backend/local_exam_payload_store.dart:4`, na sintaxe
  `abstract interface class` — por isso `grep "abstract class"` devolve 3, não 4). Nenhum repositório de rede
  tem abstração (`AuthRepository`, `ExamRepository`, `ExamMediaRepository`,
  `ContentDeliveryRepository`, `DigitalExamService`, `ExamPublicationService`,
  `QuestionDiscussionRepository`).
- Abstração **vazada do módulo baixo-nível**: `attempt_sync_service.dart:8` importa
  o concreto e `:367` o instancia como default; `ExamPayloadStorage` vive no mesmo
  arquivo do `export` condicional das implementações de IO/stub
  (`local_exam_payload_store.dart:1-2`).
- 8 serviços recebem o SDK concreto no construtor
  (`attempt_repository.dart:10-12`, `exam_repository.dart:25-28`,
  `exam_publication_service.dart:11-14`, `exam_media_repository.dart:32-44`,
  `content_delivery_repository.dart:10-17`, `digital_exam_service.dart:25-32`,
  `auth_repository.dart:7-10`, `question_discussion_repository.dart:27-33`) e
  resolvem `_client ?? Supabase.instance.client` — o default garante que a
  produção nunca injeta (ver [[../02 - Arquitetura/Mapa de Dependências]] §Singleton).
- **Contra-exemplos que já existem** e servem de molde: `SupabaseInitializer`
  (typedef estreito, `lib/core/backend/supabase_config.dart:12-15`, usado em
  `main.dart:18-22`), `currentUserId` como função (`question_discussion_repository.dart:29`),
  `search` como função (`search_page.dart:18`), e `AttemptRepository(client:,
  isAuthenticated:)`/`AttemptDraftStore(storage:)`, que foi o que permitiu os fakes
  de `test/draft_resume_characterization_test.dart:189-210`.
- UI tocando infraestrutura: `Supabase.instance.client` em 26 chamadas/10
  arquivos e `SharedPreferences.getInstance` em 18 chamadas; `HomePage` não tem
  **nenhum** parâmetro injetável (`home_page.dart:29-38,62`), por isso
  `test/ux/navigation_editor_test.dart:141-186` precisa do singleton global.
- Backdoor de teste virado estado global de produção ✔
  `lib/core/backend/local_exam_store.dart:174-176` (`static _packages`,
  `static Future? _tail` — fila que sobrevive entre instâncias — e
  `static ExamPayloadStorage? storageOverride` usado por
  `test/ux/local_exam_test.dart:60` e `navigation_editor_test.dart:181`).

## 3. SRP — atores por arquivo, não linhas

| Arquivo | Classes (privadas) | Atores/reasons-to-change observados |
|---|---:|---|
| `lib/features/home/home_page.dart` | 24 (22) | catálogo/rede `:85,:129`; rascunhos e tentativas `:155,:196`; retomada de publicação com push de rota `:163-185`; favoritos optimistas + rollback `:393`; download/média/remoção offline `:444,:463,:499`; auth direto `:62,:594`; diálogo de permissão `:616` |
| `lib/features/publish/publish_page.dart` | 12 (8) | `_ImportReviewPageState:1025` (1.277 linhas) tem edição, autosave com debounce `:1145,:1166`, ciclo de vida `:1191`, export e normalização de nome `:1276-1290`, gating `:1317`, publicação e montagem de mídia `:1451-1540`, UI `:1574-2245`; `_PdfProcessingPageState:437` roda o quality gate **dentro do build** `:691` e muta controllers no build `:700` |
| `lib/features/quiz/quiz_page.dart` | 16 (15) | hidratação do exame `:78`, redirect de resultado `:105`, ticker `:148`, rascunho/flush `:156,:177`, settings `:68`, clipboard `:245`, escolha local×remoto `:572-637` |
| `lib/core/import/question_parser.dart` | 9 (4) | 35 métodos: marcadores de página `:442`, seções `:579`, gabarito `:595`, variantes `:446`, alternativas `:1049`, confiança `:1327`, heurísticas de formato `:1349-1414` |

Métodos que misturam níveis de abstração: `publish_page.dart:621` (291 linhas),
`home_page.dart:1435` (282; assinatura com 18 params em `:1398`),
`publish_page.dart:1962` (214), `home_page.dart:1846` (188),
`question_parser.dart:752` (12 params, 158 linhas).

Modelos que também são serviço: `LocalExam` (`local_exam_store.dart:17-160`, DTO +
hash de identidade `:119` + mapper com montagem de mídia `:122-160`),
`ImportedQuestion` (`question_parser.dart:11`, mutável, decide o próprio
`reviewState` por threshold `:41-47,:91-95`), `ExamResult`
(`domain/models/exam.dart:114-236`, pontuação + fabrica exame de retry +
serialização) e `ImportDiagnosticEvent` (`import_diagnostic_event.dart:16-162`,
DTO + `collect()` + sha256 + regex).

## 4. OCP — discriminadores crus (prova da amplificação de 7 arquivos)

- ✔ `question_parser.dart:174-177`: `firstWhere(..., orElse: () =>
  QuestionFormat.multipleChoice)` contra `:180-183` que usa `unreviewed` — dois
  defaults **contraditórios** no mesmo objeto lido do JSON de rascunho: uma
  discursiva volta como múltipla escolha sem erro.
- `attempt_sync_service.dart:451` `orElse: pendingSync`: estado
  `requiresAttention` gravado por build novo volta a ser reenviado (loop).
- `result_page.dart:129` `_ =>` cobre `pendingSync` **e** `null`: estado novo
  mostra "aguardando correção" sem falha de compilação.
- Política de erro dividida em 3 sítios: transiente por prefixo Postgres em
  `attempt_repository.dart:142-153`, catch-all tratado como permanente em `:174`,
  e `'PGRST202'` repetido em `publish_page.dart:1561`.
- **Fluxo de controle por frase em prosa** (o pior caso de acoplamento por
  string): `imported_document.dart:287`, `publish_page.dart:496` e `:1889` testam
  `warning?.contains('conteúdo visual não foi extraído')`, gerado em
  `question_parser.dart:963`. Reescrever a frase desliga o bind de imagens em
  silêncio.
- Bom contra-exemplo: `import_quality_gate.dart:284` é `switch` exaustivo — formato
  novo quebra compilação (é assim que deve ser).

## 5. LSP e ISP

- `AttemptRepository.submit` lança `StateError` para exame local
  (`attempt_repository.dart:16-20`) e para não logado (`:9`), reforçando
  pré-condição de `AttemptSubmitter.submit` (`attempt_submission.dart:36`);
  `_sync` só trata `AttemptSubmissionException`
  (`attempt_sync_service.dart:375`), então esse `StateError` **escapa da máquina de
  estados** da fila.
- `scorePercent` devolve `0` quando não há corrigível
  (`domain/models/exam.dart:137-141`) — sentinela indistinguível de zero real — e
  pode passar de 100 (`:129-135`; 150% congelado em
  `test/scoring_definitions_characterization_test.dart:148-150`).
- `Question.copyWith` não permite limpar `correctIndex` (`exam.dart:91`), então
  `attempt_repository.dart:116` mantém gabarito obsoleto se o servidor omitir a
  questão; `exam_repository.dart:234` fixa `correctIndex: null` no mapa de exame
  publicado.
- Stub `LocalExamPayloadStore` devolve `false`/`null` sem gravar
  (`local_exam_payload_store_stub.dart:10-16`) e `LocalExamStore` trata `false`
  como sucesso parcial (`local_exam_store.dart:391-405`), enquanto o fake de teste
  prefere lançar (`navigation_editor_test.dart:74-76`): o contrato não define o
  que `false` significa.
- ISP: `ExamPayloadStorage.fileBacked` (`local_exam_payload_store.dart:5`) só é
  lido por `LocalExamStore:316,:368`, mas todo fake precisa implementar
  (`test/ux/local_exam_test.dart:32-34`). `AttemptQueueStore` mistura fila
  remoto-only (`:144,:225`) com operação local-only `completeLocal` (`:127-133`) e
  `saveForSync` que lança para locais (`:291-294`); quem escolhe a porta é a
  **tela** pelo flag (`quiz_page.dart:580-609`). `AuthRepository` expõe
  `currentUser` (`:12`) e `signOut` (`:46`) sem nenhum consumidor.

## 6. Clean Code: erros, duplicação de conhecimento, imutabilidade, nomes

**Erros [alto].** ✔ `exam_publication_service.dart:195-198`: falha do upload do
pacote digital virou `debugPrint` e `publish()` devolve o `examId` — a cópia
offline se perde sem sinal (já congelado em
`test/publication_characterization_test.dart:197-208`).
`focus_timer_settings.dart:84-86` usa `} on Object {` sem log e reseta o Modo Foco.
`result_page.dart:79-84` tem `catch (_)` que relê o store e deixa a tela presa em
"Entrega salva no aparelho". ✔ `quiz_page.dart:572-668`: `try` de 90 linhas
cobrindo persistir + enviar + sincronizar + navegar, com `catch (_):638` decidindo
a rota só pela sentinela `deliveryPersisted` (`:576,:589,:610`) e `catch (_) {}`
vazio em `:655`. Exceções nuas coexistem com tipos de domínio:
`FormatException` (`exam_publication_service.dart:41,59,74,93,171,219`;
`digital_exam_service.dart:123,142,170,190,229,248,262`), 17 `throw StateError`.

**Duplicação de conhecimento [alto].** Seis predicados de "questão válida" e três
pontuações convivendo:
1. ✔ `publish_page.dart:1317-1344` vs `exam_publication_service.dart:32-62` —
   divergem em `:1336` (enuncia testado **sem** trim, contra `:48` com trim), a UI
   não aplica o teto de 4.000 por alternativa, e a UI exige
   `reviewState == reviewed` (`:1340`) que o serviço não exige → a tela libera e o
   serviço lança "Revise todas as questões" (`:59`).
2. Cópias lenientes: `local_exam_store.dart:76-91`,
   `digital_exam_service.dart:177-190` (sem `correctIndex`),
   `import_quality_gate.dart:276-293`, `publish_page.dart:1346-1356`.
3. Pontuação: `exam.dart:129-150` × `attempt_repository.dart:63-101` ×
   `result_page.dart:707-710` (números congelados em
   `test/scoring_definitions_characterization_test.dart`).
4. Payload de questão escrito à mão em 4 sítios:
   `exam_publication_service.dart:61-72`, `digital_exam_service.dart:159-166`,
   `attempt_sync_service.dart:480-515`, `exam.dart:215-235`.
5. Cache LRU + dedupe duas vezes com tetos diferentes:
   `exam_media_repository.dart:229-256` (24 MB) ×
   `content_delivery_repository.dart:75-92` (16 MB).
6. Limites divergentes: comentário
   (`question_discussion.dart:77` × `question_discussion_repository.dart:74`),
   guarda local (`attempt_repository.dart:18-20` × `attempt_sync_service.dart:291-294`).

**Imutabilidade.** `ImportedQuestion` expõe `statement`, `options`, `correctIndex`,
`warning`, `reviewState`, `format`, `confidence`, `versionLabel` mutáveis
(`question_parser.dart:50-70`) e eles são escritos de fora em
`import_quality_gate.dart:74-79,316-324` e `publish_page.dart:1108,1160-1162,1989,2156,2192`.
Listas entregues sem cópia em `exam.dart:30,81-83,124-125,184-186`. 19 usos de
`late`, dois deles relevantes: `quiz_page.dart:37-47` (`late Exam exam`
reatribuído em `:80`) e `home_page.dart:2194` (`late bool downloaded =
widget.downloaded` sem `didUpdateWidget` → dessincroniza).

**Nomes e comentários.** `result_page.dart:278-282`: o rótulo "Revisar" mostra
`questions.length - correct` (erradas + em branco), contradizendo `:312`.
`publish_page.dart:1166-1169`: `_save({bool? pending})` com três estados.
`share_link_page.dart:22`: campo chamado `exam` que é `Future<Exam?>`.
`local_exam_store.dart:17,122-160`: `LocalExam` não é um `Exam`. Política de
comentário misturada (EN em `exam_publication_service.dart:129-131,160-161`,
`text_normalizer.dart:1-13`; PT em `quiz_page.dart:90-91`,
`attempt_draft_store.dart:74,110`). Nenhum TODO/FIXME e nenhum bloco comentado —
nesses dois itens o repo está limpo.

## 7. Grafo: correção ao [[../02 - Arquitetura/Mapa de Dependências]]

A nota de dependências conclui "o problema não é ciclo". Medido agora, com SCC
sobre as 144 arestas internas, **existem 2 ciclos**:

- `features/quiz/quiz_page.dart` ↔ `features/result/result_page.dart`
- `features/publish/publish_page.dart` → `features/home/home_page.dart` →
  `features/auth/auth_page.dart` → (volta a `publish`)

16 arestas ligam features vizinhas entre si. Instabilidade por área (I = Ce/(Ce+Ca),
0 = estável): `domain` **0,00** (Ce=0, Ca=15 — puro), `core/theme` 0,00,
`core/backend` 0,43, `core/import` 0,39, `features/publish` **0,94**,
`features/home` 0,84, `features/result` 0,77, `features/quiz` 0,69. Isso **confirma**
a recomendação da Arquitetura Alvo (dependências estáveis apontando para o domínio)
e **refuta** a ideia de que dá para extrair `quiz` sem tocar `result`: pelo ADP, os
dois são um módulo só hoje.

Comandos reproduzíveis (rodam no repo, sem escrever nada):

```bash
cd /home/nikolas/Prova-Social
grep -rn "catch (" lib | wc -l                                   # 69 blocos
grep -rn "catch (_" lib | wc -l                                   # 32 descartando o erro
grep -rn "Supabase.instance.client" lib | wc -l                   # 26
grep -rn "SharedPreferences.getInstance" lib | wc -l              # 18
grep -rhcE "^\s*(final\s+)?(abstract\s+)?(class|mixin|enum)\s" lib --include="*.dart" | paste -sd+ | bc  # 214
grep -rn "abstract class\|abstract interface class" lib | wc -l                     # 4 portas
git log -40 --pretty=format:"%h" --name-only -- lib | awk '/^[0-9a-f]{7,}$/{if(n>0)print n;s+=n;c++;n=0;next} NF{n++} END{printf "commits=%d media=%.2f\n",c,s/c}'
```

Os 901 diagnósticos do §1 vêm de habilitar temporariamente 33 regras extras +
`strict-casts`/`strict-raw-types` em `analysis_options.yaml` e rodar
`dart analyze --no-fatal-warnings lib`. **A config foi restaurada na sequência** —
`git status` limpo em `8ffbba4`, nada foi commitado com as regras extras; ativá-las
na esteira é mudança de gate e precisa de aval.

## 8. Limites desta medição

- Os contadores (§1, §7) são determinísticos e reproduzíveis. As listas de casos
  (§2–§6) vêm de leitura de código; as oito alegações de maior consequência foram
  reconfirmadas por mim em `file:line` (marcas ✔), o resto é forte mas não
  reaberto individualmente.
- Não há métrica oficial de complexidade ciclomática em Dart — nada de "função
  grande" sai de ferramenta; os maiores métodos listados foram achados por leitura.
- O post da Datadog (métrica de blast radius) não pôde ser lido na janela desta
  pesquisa (404 nas duas URLs conhecidas), então a métrica está adotada por
  definição, não citada. `public_member_api_docs` foi medido mas não recomendado.
- Nada de `analysis_options.yaml` foi alterado no commit, e nenhum código de app
  foi tocado nesta etapa.

## Recomendação

1. A camada nova nasce dentro das 10 regras de porta do
   [[Critérios de Qualidade de Código|§8]] — elas são verificáveis em review sem
   ferramenta nova.
2. Ligar `avoid_catches_without_on_clauses`, `discarded_futures`,
   `avoid_slow_async_io`, `parameter_assignments` + `strict-casts`/`strict-raw-types`
   como `warning` e zerar os 105 diagnósticos reais **antes** do Lote 2 (mudança de
   gate: pede aval).
3. Ordem de custo para a dívida: primeiro as 6 definições de "questão válida" e as
   3 de pontuação (viram C1–C3 dos [[../03 - Domínios/Contratos de Domínio Alvo|contratos]),
   depois as portas de `core/backend` (8 construtores com default concreto), depois
   os 2 ciclos de import, e por último a divisão dos arquivos de tela — que só vale
   se a métrica do §3 da nota de critérios provar que o total de arestas não sobe.
4. Os 51 `catch` sem `on` e as 8 chamadas sem `await` são o único débito desta
   auditoria que dá para pagar **sem nenhuma decisão de produto**: são
   mechanical, localizados e hoje invisíveis ao gate.

## Links

[[Critérios de Qualidade de Código]] ·
[[../02 - Arquitetura/Mapa de Dependências]] ·
[[../02 - Arquitetura/Arquitetura Alvo]] ·
[[../03 - Domínios/Modelo de Domínio Atual]] ·
[[Critério de Prontidão para Refatoração Global]] ·
[[../09 - Auditoria/Áreas/16 - Design system e componentes]]
