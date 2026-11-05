---
tipo: area
area: testes, QA e benchmark
status: PARCIAL
classificacao: EVOLUIR
nivel: {correcao: 3, testes: 3, acoplamento: 3, clareza: 3, seguranca: 3, robustez: 2, aderencia: 2, portabilidade: 2}
fonte_codigo: [test/, qa/, scripts/pglite_test.mjs, scripts/local_db_test.sh, supabase/tests/, tool/, .github/workflows/flutter-ci.yml]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: alta
atualizado: 2026-11-04
---

# Testes, QA e benchmark

## Resumo

A suíte tem **volume real e boa cobertura de domínio**: 41 arquivos de teste na
raiz de `test/` (6.860 linhas) mais 7 arquivos em `test/ux/` (2.084 linhas), com
235 declarações de `test`/`testWidgets`. O núcleo de importação, parser,
normalização, gabarito, persistência local, sincronização e resultado é testado
com casos de regressão, incluindo dois benchmarks de prova real/sintética. O
baseline local é de **296 testes aprovados e 1 ignorado**, com
`flutter analyze` limpo.

O problema não é falta de testes unitários; é **qualidade operacional da
suíte**. Três arquivos de probe usam caminhos absolutos da máquina
(`/home/nikolas/...`), estão versionados, não têm `skip` e fazem
`dart format --set-exit-if-changed` falhar. O job `QA Completo` do GitHub
Actions falhou exatamente no passo `QA estático` no commit de merge atual
(`05a8fc1`), o que deixa a `main` vermelha e bloqueia `android-release`, que
depende de `qa-full`. Não há `integration_test/`, cobertura, golden tests,
teste nativo do Paddle nem teste de RLS social no CI; o Playwright cobre apenas
a abertura do canvas e as cores do shell.

Classificação: **EVOLUIR** — a base de testes é aproveitável e cobre o domínio,
mas a esteira precisa ser portátil, confiável e ligada aos fluxos que o produto
considera críticos.

## Escopo e método

- Inventário de `test/` (41 arquivos) e `test/ux/` (7 arquivos), com contagem de
  declarações e linhas por arquivo.
- Leitura dos testes de importação (`pdf_text_extractor_test.dart`,
  `question_parser_test.dart`, `answer_key_parser_test.dart`,
  `page_furniture_filter_test.dart`, `import_quality_gate_test.dart`,
  `synthetic_pdf_import_test.dart`, `vunesp_2024_import_test.dart`,
  `enem_2025_import_test.dart`, `local_corpus_benchmark_test.dart`).
- Leitura dos testes de persistência/sincronização
  (`attempt_draft_store_test.dart`, `attempt_repository_test.dart`,
  `attempt_sync_service_test.dart`, `quiz_offline_submission_test.dart`,
  `test/ux/local_exam_test.dart`).
- Leitura dos testes de UI (`test/ux/navigation_editor_test.dart`,
  `search_test.dart`, `search_filters_test.dart`, `onboarding_responsive_test.dart`,
  `focus_responsive_test.dart`, `prompt_redesign_test.dart`, `startup_test.dart`).
- Leitura de `qa/run_all.sh`, `run_static.sh`, `run_tests.sh`, `run_p0.sh`,
  `run_web.sh`, `run_browser.sh`, `run_corpus_benchmark.sh`.
- Leitura de `scripts/pglite_test.mjs` (72 linhas) e `scripts/local_db_test.sh`.
- Leitura de `qa/browser/tests/smoke.spec.js` (46 linhas),
  `qa/browser/playwright.config.js` e `qa/browser/package.json`.
- Leitura dos fixtures em `test/fixtures/` e de `test/fixtures/import_corpus.json`.
- Execução local de `flutter test`, `flutter analyze` e
  `dart format --output=none --set-exit-if-changed lib test tool packages`.
- Consulta ao histórico de execuções do GitHub Actions via `gh run list` e
  `gh run view`.
- Não foi executado teste em aparelho físico, emulador Android, iOS ou navegador
  real. O Playwright não foi rodado localmente nesta auditoria.

## O que faz de fato

| Comportamento | Estado | Evidência |
|---|---|---|
| Suíte Flutter ampla | Funcional | 41 arquivos raiz + 7 em `test/ux/`; 235 declarações |
| Baseline local verde | Funcional | 296 aprovados, 1 ignorado |
| `flutter analyze` limpo | Funcional | execução local sem issues |
| Testes de parser e normalização | Funcional | `question_parser_test.dart` (32), `exam_text_normalizer_test.dart` (17) |
| Testes de gabarito | Funcional | `answer_key_parser_test.dart` (19) |
| Testes de mobília de página | Funcional | `page_furniture_filter_test.dart` (16) |
| Testes de quality gate | Funcional | `import_quality_gate_test.dart` (12) |
| Benchmark sintético de 80 questões | Funcional | `synthetic_pdf_import_test.dart`; fixture de 16 KB |
| Benchmark VUNESP com hash e snapshot | Funcional | `vunesp_2024_import_test.dart` |
| Benchmark ENEM opcional | Funcional | `enem_2025_import_test.dart`, `skip` quando o PDF falta |
| Testes de sync e idempotência | Funcional | `attempt_sync_service_test.dart` (18) |
| Testes de persistência local | Funcional | `attempt_draft_store_test.dart` (5), `test/ux/local_exam_test.dart` (9) |
| Testes de widget de navegação e editor | Funcional | `test/ux/navigation_editor_test.dart` (850 linhas) |
| Testes de busca e filtros | Funcional | `search_test.dart` (245), `search_filters_test.dart` (377) |
| Testes de onboarding e startup | Funcional | `onboarding_responsive_test.dart`, `startup_test.dart` |
| PGlite aplica migrations e testa idempotência | Funcional | `scripts/pglite_test.mjs:22-70` |
| Teste concorrente PostgreSQL local | Funcional (fora do CI) | `scripts/local_db_test.sh:85-150` |
| Playwright abre o app Web | Funcional | `qa/browser/tests/smoke.spec.js:3-21` |
| Playwright valida cores do shell | Funcional | `qa/browser/tests/smoke.spec.js:23-46` |
| `qa/run_all.sh` agrega estático, testes, P0, Web e browser | Funcional | `qa/run_all.sh:22-27` |
| CI roda QA em push, PR, tag e dispatch | Funcional | `flutter-ci.yml:131-200` |
| Suíte portátil | Quebrado | probes com caminho absoluto e sem `skip` |
| `dart format` no CI | Quebrado | 3 arquivos `_corpus_*_test.dart` |
| `main` verde no CI | Quebrado | run `41760190392`, job `QA Completo`, passo `QA estático` |
| `integration_test/` | Ausente | diretório não existe |
| Cobertura de código | Ausente | nenhuma referência a `coverage`/`lcov` |
| Golden tests | Ausente | nenhum `matchesGoldenFile` |
| Teste nativo do Paddle | Ausente | nenhum `src/test` ou `androidTest` |
| Teste de RLS social no CI | Ausente | PGlite cobre tentativas, não comunidades/posts |

## O que funciona

1. **Cobertura real do domínio de importação.** O parser tem 32 testes, a
   normalização 17, o gabarito 19, a mobília 16 e o quality gate 12. Isso cobre
   os pontos que mais quebram em provas reais: numeração, alternativas,
   cabeçalho/rodapé, gabarito e continuidade entre páginas.
2. **Benchmark sintético determinístico.** O PDF de 80 questões em duas colunas
   tem 16 KB, hash no manifesto e expectativa de ordem completa
   (`synthetic_pdf_import_test.dart`; `test/fixtures/README.md`). É o teste de
   regressão mais valioso do importador e pode rodar em qualquer máquina.
3. **Benchmark de prova real com snapshot.** O teste VUNESP valida SHA-256 do
   PDF, SHA-256 do snapshot do parser, número de páginas, questões, alternativas
   e distribuição (`vunesp_2024_import_test.dart:22-60`). É uma boa barreira
   contra regressão silenciosa.
4. **Benchmark ENEM opcional e honesto.** O teste de 90 questões/32 páginas é
   pulado quando o PDF não está presente e não finge cobertura
   (`enem_2025_import_test.dart:16, 74-75`).
5. **Sincronização testada em profundidade.** `attempt_sync_service_test.dart`
   cobre fila, retry, validação e idempotência; é o teste mais próximo do
   comportamento de rede real.
6. **Persistência local testada com migração.** `test/ux/local_exam_test.dart`
   cobre compressão, integridade, migração de preferências e remoção seletiva.
7. **Testes de UI com intenção de produto.** `navigation_editor_test.dart` cobre
   saída do editor, login como rota inicial, perfil de visitante, falha de
   catálogo, filtros da home e confirmação de publicação. Não são apenas smoke
   tests.
8. **QA local executável.** `qa/run_all.sh` encadeia estático, testes Flutter,
   PGlite, build Web e Playwright, com logs em `build/qa/` e código de saída
   agregado.
9. **PGlite reduz dependência de infraestrutura.** Aplicar todas as migrations
   em memória e testar a RPC de tentativa sem Postgres externo é uma escolha
   pragmática para CI e para máquina sem Docker.
10. **Teste concorrente existe.** `scripts/local_db_test.sh` abre duas sessões
    psql e verifica que a mesma `client_attempt_id` não cria tentativas
    duplicadas. É o único teste de concorrência real do projeto.
11. **Playwright protege a marca.** O teste de fundo e `theme-color` impede
    regressão para o branco padrão do Flutter Web
    (`smoke.spec.js:23-46`).
12. **Artefatos de QA são preservados.** O CI publica `build/qa/**`,
    `test-results/**` e `playwright-report/**` mesmo em falha
    (`flutter-ci.yml:194-200`).

## O que está parcial

### A `main` está vermelha por formatação

`qa/run_static.sh` executa:

```sh
run "Dart format" dart format --output=none --set-exit-if-changed lib test tool packages
```

A execução local retorna **exit 1** e lista três arquivos:

- `test/_corpus_bench_probe_test.dart`;
- `test/_corpus_detail_probe_test.dart`;
- `test/_corpus_probe_test.dart`.

Os três estão versionados (`git ls-files` confirma) e sem modificação local.
O run `41760190392` (merge `05a8fc1`, push em `main`) falhou no job
`QA Completo`, passo `QA estático`; os demais jobs passaram. Como
`android-release` tem `needs: [qa-full, ...]`, uma tag `v*` hoje não publica
release.

Isso é uma falha de processo, não de produto: o gate existe, mas foi contornado
ou não foi observado antes do merge. Também mostra que o `dart format` do CI
não é o mesmo comando que o desenvolvedor roda por hábito (muitos rodam apenas
`dart format lib`, que não cobre `test`).

### Probes de corpus não são portáveis

Os quatro arquivos `test/_corpus_*_probe_test.dart` são ferramentas de
diagnóstico pessoal, não testes de produto:

- `_corpus_probe_test.dart` usa `const folder = '/home/nikolas/Downloads/Provas'`
  e chama `Directory(folder).listSync()` sem verificar existência nem `skip`
  (`:12, :22`);
- `_corpus_bench_probe_test.dart`, `_corpus_detail_probe_test.dart` e
  `_corpus_page_probe_test.dart` dependem de corpus/configuração local e têm
  timeouts de 30–60 minutos;
- `_corpus_probe_test.dart` passou localmente (2 testes), mas em um runner
  limpo `listSync` lança `FileSystemException` e o teste falha;
- os arquivos imprimem texto extraído de provas no log, o que pode vazar
  conteúdo de terceiros em artefato de CI.

Eles devem sair da suíte padrão. O lugar correto é `tool/` ou um diretório
`test/manual/` excluído por tag/`--exclude-tags`, com `skip` explícito quando o
corpus não existe.

### Cobertura de fluxo crítico incompleta

O `AGENTS.md` §21 pede teste de integração para
**importar → revisar → publicar → fazer → finalizar**. Não existe
`integration_test/` e nenhum teste percorre esse caminho completo. O que existe
são testes de partes:

- importação: `synthetic_pdf_import_test.dart`, `vunesp_2024_import_test.dart`;
- publicação: trechos de `navigation_editor_test.dart` (ex.: “publication waits
  for human confirmation below 99%”);
- resolução: `quiz_offline_submission_test.dart`, `focus_responsive_test.dart`;
- finalização: `result_review_test.dart`, `exam_result_test.dart`.

Nenhum teste monta o fluxo inteiro com o mesmo documento. Uma regressão na
passagem de `ImportedDocument` para `Exam` para `Attempt` para resultado pode
passar por todos os testes unitários.

### Focus Mode tem um único teste de widget

`test/ux/focus_responsive_test.dart` tem **1 teste**: “Focus Mode fits a narrow
phone with larger system text” (53 linhas). Não há teste de:

- seleção de alternativa e persistência imediata;
- navegação anterior/próxima;
- marcação para revisão;
- cronômetro total e por questão;
- ocultar/revelar cronômetro;
- modal de finalização com questões em branco/marcadas;
- retomada exata do ponto salvo;
- sincronização em segundo plano durante a prova;
- estado offline e falha de entrega.

O Focus Mode é declarado a interface mais importante do produto no `AGENTS.md`
§8, mas é a tela com menos cobertura proporcional.

### Login contextual sem teste dedicado

`navigation_editor_test.dart` cobre “Agora não fecha o login quando ele é a rota
inicial”, “sair da conta atualiza o perfil para visitante” e “visitor can open a
truthful profile”. Não há teste de:

- abrir modal de login a partir de uma ação autenticada;
- retornar à ação original depois do login;
- deep link de confirmação de e-mail;
- OAuth Google no Android/Web;
- erro de credencial e recuperação de senha.

A `AuthPage` não tem teste de widget próprio.

### Playwright é quase um smoke test de marca

`qa/browser/tests/smoke.spec.js` tem 2 testes:

1. o canvas do Flutter Web aparece e não há erro fatal;
2. o fundo é `rgb(5, 9, 7)`, o `theme-color` é `#050907` e o manifest declara
   `#050907`.

Não há teste de:

- onboarding e navegação de visitante;
- busca e abertura de prova;
- Focus Mode no navegador;
- resultado;
- PWA instalada/service worker;
- responsividade em viewport móvel;
- acessibilidade por teclado.

O teste também depende de `flt-glass-pane canvas`, um detalhe interno do
renderer; uma mudança de engine pode quebrá-lo sem regressão de produto.

### PGlite cobre tentativas, não o restante do schema

`scripts/pglite_test.mjs` aplica **todas** as migrations, mas só executa
asserções sobre:

- `legacy_attempt_schema.sql`;
- `attempt_idempotency.sql` (retry, bloqueio anônimo, RLS, grants, rollback);
- `deployed_attempt_smoke.sql`.

Não testa:

- RLS de `profiles`, `comments`, `bookmarks`, `collections`, `posts`,
  `communities`, `reports`;
- `publish_exam` e `exam_media_publication`;
- catálogo keyset;
- Storage e políticas de arquivo;
- `content_files`;
- funções dos SQLs soltos fora das migrations.

O próprio script declara as limitações
(`pglite_test.mjs:68-70`): concorrência entre conexões, `pgcrypto`, Auth/JWT e
Supabase remoto não são testados. `scripts/local_db_test.sh` cobre
concorrência, mas **não é chamado por `qa/run_p0.sh` nem pelo CI**; só roda
manualmente.

### Benchmarks não são comparáveis entre execuções

`local_corpus_benchmark_test.dart` e os probes medem o corpus local, mas não
registram baseline histórico. Não há:

- número de acurácia por questão;
- tempo por página;
- memória;
- comparação entre Paddle e ML Kit;
- limite de regressão que falhe o CI.

`qa/run_corpus_benchmark.sh` existe, mas não está em `qa/run_all.sh`
(`run_all.sh:22-27`). O benchmark é opt-in e depende de
`PROVA_SOCIAL_CORPUS_ROOT`; ninguém é obrigado a rodá-lo antes de um merge.

### Fixtures reais com licença não verificada

`test/fixtures/vunesp_2024_pm_sp.pdf` tem 2,1 MB, está versionado e é usado por
`vunesp_2024_import_test.dart`. O manifesto marca
`licenseStatus: not-verified` e `allowedForProductContent: false`
(`import_corpus.json`; `test/fixtures/README.md`), o que é correto. O risco é
operacional:

- o arquivo aumenta o clone e o artefato de CI;
- um teste depende de conteúdo de terceiros;
- não há política para removê-lo se a licença for contestada;
- o PDF ENEM de 90 questões está no `.gitignore` (`.gitignore:64`) e por isso
  o teste correspondente é sempre pulado no CI.

### Testes de acessibilidade pontuais

Há **1** teste de semântica (`question_media_gallery_test.dart:8-36`) e 18 usos
de `Semantics` no app. Não há varredura de acessibilidade, teste com
`textScaler` ampliado além do Focus, contraste ou navegação por teclado.

### Testes de tema e redução de movimento não cobrem o app inteiro

`onboarding_responsive_test.dart` e `focus_responsive_test.dart` exercitam
tamanhos de tela; `prompt_redesign_test.dart` cobre parte da identidade. Não há
teste que renderize as telas principais em light/dark e com
`MediaQuery.disableAnimations = true`.

## O que está ausente ou quebrado

- `integration_test/` e fluxo ponta a ponta importar → publicar → fazer →
  finalizar.
- Cobertura de código (`flutter test --coverage`) e limite mínimo.
- Golden tests para componentes e telas.
- Teste nativo Kotlin do `paddleocr_android`.
- Teste Flutter com `MethodChannel` mockado para o Paddle.
- Teste de RLS social, publicação e comunidades.
- Teste de concorrência no CI (`local_db_test.sh`).
- Teste do site (`site/tests/site.test.cjs`) no CI.
- Teste de atualização do app com release real e ABI errada.
- Teste de deep link Android/Web.
- Teste de importação por câmera (função não existe).
- Teste de performance/memória do Focus e do OCR.
- Teste de retomada após morte do processo.
- Teste de migração de schema local entre versões do app.
- Teste de acessibilidade sistemático.
- Teste de tema claro/escuro em todas as telas.
- Baseline de benchmark com alerta de regressão.
- `dart format` verde em `main`.
- Probes fora da suíte padrão.
- Política de fixture real e licença.

## Divergências documentação × código

| Afirmação | Realidade no SHA | Evidência |
|---|---|---|
| “Antes de declarar conclusão, `dart format` sem alterações pendentes” | `dart format` falha em 3 arquivos versionados | execução local; `qa/run_static.sh:15` |
| “`flutter test` aprovado” | 296/1 localmente; CI falha antes, no estático | `flutter test`; run `41760190392` |
| “Teste de integração importar → revisar → publicar → fazer → finalizar” | Não existe `integration_test/` | `ls integration_test` |
| “Teste de widget para Focus Mode” | Existe 1 teste de responsividade | `test/ux/focus_responsive_test.dart:9` |
| “Teste de widget para estados vazios e login contextual” | Cobertura parcial em `navigation_editor_test.dart` | `:299-390` |
| “Verificação light/dark” | Não há teste sistemático de tema | nenhum teste de `themeMode` |
| “Verificação com fonte ampliada e redução de movimento” | Só Focus tem `textScaler`; nenhum teste de `disableAnimations` | `focus_responsive_test.dart` |
| “Verificação offline e retomada” | Há teste de submissão offline; não há morte de processo | `quiz_offline_submission_test.dart` |
| “QA cobre o fluxo real” | PGlite cobre tentativas; Playwright cobre canvas e cores | `pglite_test.mjs`; `smoke.spec.js` |

## Evidência de testes

### Inventário

| Grupo | Arquivos | Declarações aproximadas |
|---|---:|---:|
| Importação, parser e gabarito | 8 | 95 |
| Persistência e sincronização | 6 | 43 |
| Domínio e resultado | 4 | 10 |
| UI e navegação | 8 | 45 |
| Backend/config | 2 | 12 |
| Probes de corpus | 4 | 8 |
| Total | 41 + 7 ux | 235 |

### Baseline local

- `flutter test`: **296 aprovados, 1 ignorado**.
- `flutter analyze`: sem issues.
- `dart format --output=none --set-exit-if-changed lib test tool packages`:
  **exit 1**, 3 arquivos.
- `test/_corpus_probe_test.dart`: passou localmente (2 testes), mas depende de
  `/home/nikolas/Downloads/Provas`.

### O que os testes cobrem bem

- Parser de questões e alternativas, incluindo casos de numeração e
  continuidade.
- Normalização de texto e remoção de mobília.
- Gabarito oficial e aplicação.
- Quality gate e motivos de revisão.
- Importação de PDF sintético de 80 questões e VUNESP real.
- Fila de sincronização, retry e idempotência.
- Persistência local, compressão, hash e migração de preferências.
- Navegação, filtros, onboarding, perfil de visitante e confirmação de
  publicação.
- Resultado, revisão e prova dos erros.
- Release do GitHub e seleção de APK (unitário).

### O que os testes não cobrem

- O fluxo completo com um único documento.
- Focus Mode operacional (timer, seleção, revisão, finalização, retomada).
- Login OAuth/deep link.
- Câmera e importação por imagem.
- Motor Paddle nativo e timeout.
- RLS social, publicação, comunidade e denúncia.
- Storage e mídia.
- Concorrência no CI.
- Performance, memória e tamanho de APK.
- Acessibilidade e temas em todas as telas.
- Site e PWA além do shell.

## Riscos

1. **Release bloqueada.** `android-release` depende de `qa-full`; com
   `dart format` vermelho, nenhuma tag publica APK.
2. **CI não protege `main`.** O merge atual entrou vermelho; o gate existe, mas
   não foi respeitado.
3. **Teste que passa na máquina e falha no runner.** Probes com caminho
   absoluto criam falso negativo/positivo e minam a confiança na suíte.
4. **Regressão de fluxo invisível.** Sem teste ponta a ponta, uma quebra entre
   importação, publicação e tentativa pode chegar ao usuário.
5. **Focus Mode sem rede de segurança.** É a tela mais crítica e a menos
   testada.
6. **RLS social não verificada.** Um erro de política pode expor ou bloquear
   dados sem o CI perceber.
7. **Benchmark sem baseline.** O importador pode piorar acurácia sem falhar
   nenhum teste.
8. **Fixture real no repositório.** Licença não verificada e peso no clone.
9. **Vazamento de conteúdo em log.** Probes imprimem texto de provas.
10. **Falsa sensação de cobertura.** 296 testes verdes não significam fluxo
    pronto; a distribuição é desigual.

## Plano de refatoração da área

### Lote 1 — Desbloquear o CI e separar probes

- Formatar os três arquivos ou removê-los da suíte padrão.
- Mover `test/_corpus_*` para `tool/` ou `test/manual/` com tag
  `manual`/`corpus` e `skip` quando o caminho não existir.
- Garantir que `qa/run_static.sh` rode exatamente o mesmo comando do
  desenvolvedor e documentar `dart format lib test tool packages`.
- Critério de aceite: `main` verde; `dart format` exit 0; `flutter test` não
  depende de `/home/nikolas`; nenhum probe imprime conteúdo de prova no log do
  CI.

### Lote 2 — Integração ponta a ponta

- Criar `integration_test/` com um documento sintético pequeno.
- Cobrir: importar → revisar → publicar (ou manter privada) → iniciar →
  responder → marcar → finalizar → resultado → prova dos erros.
- Rodar em Android/emulador e, se possível, Web.
- Critério de aceite: um teste único percorre o fluxo e falha se qualquer
  etapa perder dados; roda no CI em job separado com timeout próprio.

### Lote 3 — Focus Mode e offline

- Testes de widget para seleção, persistência imediata, navegação, revisão,
  timer total/por questão, ocultar/revelar e modal de finalização.
- Teste de retomada após recriar o widget/processo.
- Teste de fila offline e entrega posterior.
- Critério de aceite: cada requisito do `AGENTS.md` §8 tem ao menos um teste
  nomeado; teste de timer não reconstrói o enunciado.

### Lote 4 — Banco e RLS no CI

- Levar `scripts/local_db_test.sh` ou um equivalente PGlite para o CI.
- Testar RLS de `profiles`, `comments`, `bookmarks`, `collections`, `posts`,
  `communities`, `reports` e Storage.
- Testar `publish_exam`, catálogo keyset e mídia.
- Critério de aceite: usuário A não lê/escreve dado privado de B; anônimo não
  publica; publicação oficial exige intenção explícita; testes rodam em todo PR.

### Lote 5 — Cobertura, goldens e acessibilidade

- Adicionar `flutter test --coverage` com limite mínimo por diretório, não
  global.
- Goldens para `ExamCard`, `SourceBadge`, `Skeleton*`, alternativas do Focus e
  estados vazios.
- Varredura de acessibilidade nas telas principais, com `textScaler` 1.3 e
  `disableAnimations`.
- Critério de aceite: cobertura de `lib/core/import` e `lib/core/sync` acima do
  limite; nenhum golden quebrado sem revisão; nenhum erro de contraste/tamanho
  de alvo.

### Lote 6 — Benchmark e performance

- Transformar o corpus em benchmark com baseline versionado (acurácia, tempo,
  memória).
- Comparar Paddle vs ML Kit, escala de renderização e JPEG.
- Rodar benchmark em job noturno, não em todo PR.
- Critério de aceite: relatório com números; regressão acima do limite falha o
  job noturno e abre issue.

### Lote 7 — Fixtures e licenças

- Definir política para fixture real: manter apenas com licença verificada,
  ou remover e usar corpus externo opt-in.
- Remover `.backup` desnecessário.
- Critério de aceite: nenhum conteúdo de terceiros no repositório sem licença
  registrada; clone e CI não carregam PDF de 2,1 MB sem justificativa.

## Classificação por critério

| Critério | Nota | Justificativa |
|---|---:|---|
| Correção | 3 | A suíte encontra regressões de domínio, mas o CI está vermelho e o fluxo crítico não é coberto. |
| Testes | 3 | Volume e profundidade bons em parser/sync; lacunas em Focus, integração e nativo. |
| Acoplamento | 3 | Testes usam stores e serviços reais; alguns dependem de caminhos e fixtures externas. |
| Clareza | 3 | Nomes bons; probes pessoais misturados à suíte oficial confundem o contrato. |
| Segurança | 3 | RLS de tentativas testada; RLS social e Storage não. |
| Robustez | 2 | `main` vermelha, probes não portáveis e ausência de baseline de benchmark. |
| Aderência | 2 | §21 pede integração, Focus, light/dark, fonte ampliada e offline; só parte existe. |
| Portabilidade | 2 | Caminhos absolutos, dependência de corpus local e Playwright frágil. |

Classificação resultante: **EVOLUIR** — há uma suíte valiosa e testável, mas a
esteira precisa ser desbloqueada, tornada portátil e ligada aos fluxos que o
produto declara críticos.

## Dependências

- Área 5 para Focus Mode, timer e finalização.
- Área 7 e 8 para persistência, offline, retomada e sincronização.
- Área 9 e 13 para corpus, OCR e benchmark.
- Área 12 para RLS, migrations e RPCs.
- Área 15 para CI, release e site.
- Área 16 para goldens, temas e acessibilidade.
- Área 17 para dependências e vulnerabilidades.
- Decisão de produto sobre manter fixture real no repositório.

## O que não foi verificado

- Execução do CI após correção do `dart format`.
- Execução do Playwright localmente nesta auditoria.
- Teste em Android/iOS reais.
- Cobertura real de linhas por arquivo.
- Desempenho da suíte em runner limpo.
- Comportamento dos probes em máquina sem `/home/nikolas`.
- Teste de RLS social (não existe).
- Teste de integração (não existe).
- Teste nativo do Paddle (não existe).
- Golden tests (não existem).
- Benchmark com baseline (não existe).
- Licença do PDF VUNESP.

## Links

- [[05 - Focus Mode, timer, navegação e finalização|Área 5 — Focus Mode]]
- [[07 - Persistência local, backups e provas locais|Área 7 — Persistência local]]
- [[08 - Sincronização, offline, idempotência e conflitos|Área 8 — Sincronização]]
- [[09 - Importação, OCR, parser e quality gate|Área 9 — Importação e OCR]]
- [[12 - Supabase, schema, RLS e RPCs|Área 12 — Backend]]
- [[13 - OCR Android, PaddleOCR e digitalização|Área 13 — OCR Android]]
- [[15 - CI-CD, releases, site, Web e PWA|Área 15 — CI/CD]]
- [[16 - Design system e componentes|Área 16 — Design system]]
- [[17 - Dependências e manutenção|Área 17 — Dependências]]
- [[Mapa das Áreas|Mapa das Áreas]]
