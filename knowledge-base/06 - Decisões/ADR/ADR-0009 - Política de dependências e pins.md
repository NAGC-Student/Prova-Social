---
tipo: adr
area: dependências e manutenção
status: INTENÇÃO
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [pubspec.yaml, pubspec.lock, .github/dependabot.yml, .github/workflows/flutter-ci.yml, docs/historico/DEPENDENCY_COMPATIBILITY.md, packages/paddleocr_android/android/build.gradle]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: media
atualizado: 2026-11-07
---

# ADR-0009 — Política de dependências, pins e cadência de atualização

- **Status:** aceito
- **Data:** 2026-11-07
- **Responsável pela aprovação:** NAGCODE-Dev (responsável pelo projeto)
- **Áreas:** 17
- **Urgência:** Média

## Contexto

Já existe política escrita e automação; o que falta é a matriz estar viva e a
regra de pin ser explícita.

- **Inventário medido.** `pubspec.yaml:10-28`: **15** entradas diretas —
  **5** pinos exatos (`crypto 3.0.7` `:12`, `file_picker 13.1.0` `:13`,
  `google_mlkit_text_recognition 0.17.1` `:18`, `http 1.6.0` `:19`,
  `image 4.10.1` `:20`), **7** com caret (`archive`, `package_info_plus`,
  `path_provider`, `pdfrx`, `shared_preferences`, `supabase_flutter`,
  `url_launcher`), **1** por caminho (`paddleocr_android`,
  `packages/paddleocr_android`, `:22-23`) e **2** de SDK (`flutter`,
  `flutter_web_plugins`). Dev: **4** (`:30-35`), incluindo
  `flutter_lints ^6.0.0` e `pdfium_flutter ^0.3.0`. Nenhum `any`, nenhum
  `git`. SDK: `">=3.13.0 <4.0.0"` e Flutter `">=3.47.0"` (`:6-8`).
- **Lock commitado e enforced.** `git ls-files pubspec.lock` →
  `pubspec.lock`. O CI usa `flutter pub get --enforce-lockfile` em quatro
  pontos (`.github/workflows/flutter-ci.yml:92,159,263,671`). Ou seja: a
  resolução é reprodutível e uma mudança de lock sem intenção falha a
  esteira.
- **Automação de atualização já configurada.** `.github/dependabot.yml:2-25`:
  quatro ecossistemas (`github-actions` na raiz, `npm` em `/qa/browser`,
  `pub` na raiz, `gradle` em `/packages/paddleocr_android/android`), todos
  semanais com limite de 5 PRs abertos. Não há `renovate.json`
  (`find . -name "renovate*"` vazio).
- **Nada mede defasagem.** `grep -rn "pub outdated\|pub upgrade" .github/ qa/
  scripts/ tool/` não retorna nada: nenhuma esteira verifica quão velhas
  estão as dependências. A cadência real é a do dependabot, não uma decisão
  registrada.
- **A matriz está congelada duas versões atrás.**
  `docs/historico/DEPENDENCY_COMPATIBILITY.md:1` declara “Prova Social
  **0.5.0**”, verificado em 17/09/2026 (`:3`), e lista `pdfrx 2.6.1`,
  `supabase_flutter 2.10.0`, `package_info_plus 10.2.1` (`:8-12`). O atual
  é `0.7.5+15` (`pubspec.yaml:4`) com `pdfrx ^2.6.5`,
  `supabase_flutter ^2.18.0`, `package_info_plus ^10.2.2`. O documento foi
  movido para `docs/historico/` em `e084ef6`, mas continua sendo a única
  matriz de compatibilidade do projeto.
- **A regra de ouro já está escrita nesse documento.**
  `DEPENDENCY_COMPATIBILITY.md:25-27`: “Não execute
  `flutter pub upgrade --major-versions` no pipeline. Alterações de
  dependências devem atualizar esta matriz e passar por `flutter pub get`,
  análise e testes no GitHub Actions.” A primeira metade é cumprida; a
  segunda (“atualizar esta matriz”) não é.
- **Dependências nativas são o risco concentrado.** Versões resolvidas no
  lock: `google_mlkit_text_recognition 0.17.1`, `pdfrx 2.6.6` (com
  `pdfium_flutter 0.3.1` no par de dev), `file_picker 13.1.0`, e o plugin
  local `paddleocr_android 0.1.0`, que embarca
  `onnxruntime-android:1.31.1`, `opencv:4.5.3` e
  `kotlinx-coroutines-android:1.9.0`
  (`packages/paddleocr_android/android/build.gradle:32-34`, com
  `lockAllConfigurations()` em `:28`). Essas não são cobertas pelo
  `--enforce-lockfile` do Dart: o Gradle tem seu próprio lock.
- **Histórico de atualização.** `git log -- pubspec.yaml pubspec.lock`
  mostra “chore: modernize Flutter dependencies” em 2026-10-07 e bumps de
  release em 2026-11-01 — cadência irregular, por lote, não periódica.

**Limites.** `flutter pub outdated` **não foi executado** nesta auditoria; a
defasagem real das 15 dependências não está medida. Não foi verificado se o
dependabot está de fato ativo no repositório upstream (isso é configuração
de plataforma, não arquivo). O lock do Gradle foi lido no `build.gradle`,
não resolvido em build limpo.

> **Correção datada (2026-11-08).** A primeira frase acima está errada e foi
> preservada como estava: a
> [[../../09 - Auditoria/Áreas/17 - Dependências e manutenção|Área 17]] registrou
> `flutter pub outdated` em **2026-11-05** (4 diretas + 1 dev atrasadas, 7
> constrainadas, 16 presas no lock). O que não existia era medição **na
> esteira** — aí o contexto acima continua correto. A defasagem foi remedida em
> 2026-11-08 na Tarefa 1.5: 5 diretas + 1 dev, 9 constrainadas, 17 presas no
> lock. O ML Kit não aparecia na tabela de 2026-11-05 e aparece agora; a causa
> da diferença não foi verificada. Números e saída em
> [[../../03 - Domínios/Dependências e pins]].

## Decisão

**Aprovada em 2026-11-07 pelo responsável pelo projeto (NAGCODE-Dev).**
Alternativa escolhida: **A — formalizar o estado atual**. A decisão é:

1. **Escrever a regra de pin que já é praticada:** pino exato para o que
   toca nativo ou contrato externo (ML Kit, `file_picker`, `http`, `crypto`,
   `image`, plugin PaddleOCR e seus artefatos Gradle); caret para o resto.
   Hoje a divisão é implícita e coincide com essa regra em 4 de 5 casos —
   falta só declará-la.
2. **Reviver a matriz como nota do vault**, gerada a partir do lock (não
   digitada), com data e SHA; `docs/historico/DEPENDENCY_COMPATIBILITY.md`
   ganha banner de congelado em 0.5.0 (ADR-0008). Matriz digitada à mão é o
   que apodreceu.
3. **Adicionar uma verificação de defasagem que não altera nada:**
   `flutter pub outdated` como passo informativo (ou consulta semanal), sem
   `upgrade` automático. Atualização continua entrando como PR do
   dependabot, com esteira verde, um lote por vez.
4. **Cadência explícita:** revisar dependências nativas a cada release
   (elas afetam APK e OCR), e as Dart pelo fluxo do dependabot. Sem
   `--major-versions` no pipeline, como já manda o documento histórico.

## Alternativas

- **A — Formalizar o estado atual (escolhida).** Regra de pin escrita, matriz
  gerada do lock, `pub outdated` informativo, dependabot como único
  atualizador. Prós: quase nenhum código novo; torna explícito o que já
  funciona; a matriz para de mentir. Contras: não reduz a defasagem, só a
  torna visível; exige disciplina para não aceitar PR de dependabot em lote.
- **B — Pins exatos em tudo + lock.** Todas as 15 com versão exata. Prós:
  reprodutibilidade máxima, nenhuma surpresa de transitiva. Contras:
  `pubspec.lock` já dá isso; vira ruído de diff e o dependabot passa a abrir
  PR para cada transitiva; caret em pacote Dart puro é seguro e barato.
- **C — Caret em tudo, confiar no lock.** Prós: menos pins para manter.
  Contras: `flutter pub get` sem `--enforce-lockfile` (uso local comum)
  passa a poder resolver versões diferentes; ML Kit e PaddleOCR mudam
  comportamento nativo sem aviso.
- **D — Atualização periódica em lote (trimestral).** Prós: menos
  interrupções, um teste grande por lote. Contras: lote grande = mais
  conflito e mais difícil de reverter; contradiz a prática atual de PR
  pequeno do dependabot e o princípio de strangler por fluxo.
- **E — Não fazer.** Prós: custo zero. Contras: a matriz continua dizendo
  0.5.0, ninguém sabe a defasagem, e a regra de pin continua tribal.

## Consequências e reversão

- **Positivas:** uma regra de pin consultável; matriz que reflete o lock;
  defasagem visível sem risco de upgrade automático; dependências nativas
  revisadas no momento em que seu custo aparece (release).
- **Negativas/custos:** gerar matriz do lock é um script a mais para manter;
  `pub outdated` informativo adiciona tempo de esteira; revisar nativas por
  release exige rebuild e medição de APK (ADR-0011).
- **Riscos:** aceitar PR de dependabot que mexe em ML Kit/PaddleOCR sem
  rebuild de APK pode mudar o OCR em produção sem teste de device.
  Mitigação: exigir teste de importação real e build Android para esse
  subset, não só `flutter test`.
- **Reversão:** política e matriz são texto — `git revert`. Pins são
  reversíveis editando `pubspec.yaml` e rodando `pub get`, mas a versão
  resolvida no lock precisa ser conferida depois; remover o
  `--enforce-lockfile` do CI seria afrouxar um gate existente e não é
  recomendado como efeito colateral.
- **Materialização em 2026-11-08 (alternativa A):** a regra está escrita em
  [[../../03 - Domínios/Dependências e pins]], a matriz viva é gerada do lock em
  [[../../05 - Qualidade/Matriz de dependências]] por
  `tool/generate_dependency_matrix.py` (stdlib, sem PyYAML e sem Flutter), e o
  `--check` mais o teste do gerador entraram no `qa/run_static.sh`. O CI ganhou
  o passo informativo `Defasagem de dependências (informativo, ADR-0009)` com
  `continue-on-error: true` (`.github/workflows/flutter-ci.yml:172-174`); nenhum
  upgrade foi executado. A data da matriz é preservada enquanto o SHA-256 do
  lock não muda — sem essa regra o `--check` falharia todo dia por motivo
  nenhum. `docs/historico/DEPENDENCY_COMPATIBILITY.md` ganhou no banner o link
  para os dois sucessores.
- **Defasagem medida em 2026-11-08:** `flutter pub outdated` exit 0 com o lock
  inalterado (SHA-256 conferido antes e depois). Cinco diretas atrás do
  publicado — `crypto` 3.0.7→3.0.8, `file_picker` 13.1.0→13.3.2,
  `google_mlkit_text_recognition` 0.17.1→**1.0.1** (major), `image`
  4.10.1→4.12.0, `pdfrx` 2.6.6→2.12.0 — e uma de dev, `pdfium_flutter`
  0.3.1→0.4.1; o rodapé conta 17 upgradable presas no lock e 9 constraints
  abaixo do resolvível. O major do ML Kit não foi aceito: cai no gate de
  benchmark em aparelho do ADR-0011, ainda pendente de dispositivo.
- **Divergência registrada, não resolvida por conta própria:** a regra diz
  "pino exato para o que toca nativo", mas a lista decidida acima não nomeia
  `pdfrx` nem `pdfium_flutter`, que carregam PDFium nativo e hoje são caret.
  Incluir os dois no conjunto exato ou registrar a exceção é decisão do
  responsável; o ponto está aberto na nota de política. Nenhum `pubspec.yaml`
  ou `pubspec.lock` foi editado nesta tarefa.

## Evidências e validação

- Área: [[../../09 - Auditoria/Áreas/17 - Dependências e manutenção|Área 17]].
- Arquivos: [pubspec.yaml](../../../pubspec.yaml),
  [pubspec.lock](../../../pubspec.lock),
  [.github/dependabot.yml](../../../.github/dependabot.yml),
  [flutter-ci.yml](../../../.github/workflows/flutter-ci.yml),
  [docs/historico/DEPENDENCY_COMPATIBILITY.md](../../../docs/historico/DEPENDENCY_COMPATIBILITY.md),
  [build.gradle do plugin](../../../packages/paddleocr_android/android/build.gradle),
  [generate_dependency_matrix.py](../../../tool/generate_dependency_matrix.py),
  [qa/run_static.sh](../../../qa/run_static.sh).
- Notas que materializam a decisão:
  [[../../03 - Domínios/Dependências e pins]] (regra, inventário, cadência,
  defasagem medida) e [[../../05 - Qualidade/Matriz de dependências]] (gerada).
- Testes que sustentam a esteira de dependências:
  [test_generate_dependency_matrix.py](../../../tool/test_generate_dependency_matrix.py)
  (15 testes, lock temporário mínimo),
  [supabase_config_test.dart](../../../test/supabase_config_test.dart),
  [github_release_service_test.dart](../../../test/github_release_service_test.dart),
  [local_corpus_benchmark_test.dart](../../../test/local_corpus_benchmark_test.dart)
  (sensível a mudança de parser/OCR).
- **Exigido antes de implementar:** ~~rodar `flutter pub outdated` e registrar
  a saída com data~~ — **feito em 2026-11-08**, saída resumida na nota de
  política e em `## Consequências e reversão`; ~~teste de que a matriz gerada
  bate com `pubspec.lock`~~ — **feito**, `--check` no `qa/run_static.sh`.
  Pendente: build Android limpo para conferir o lock do Gradle; para qualquer
  bump nativo, importação de prova real antes e depois (nenhum bump foi feito).
- Comandos de reprodução:
  `grep -n "enforce-lockfile" .github/workflows/flutter-ci.yml`;
  `git ls-files pubspec.lock`; `cat .github/dependabot.yml`;
  `grep -n "onnxruntime-android\|opencv\|coroutines" packages/paddleocr_android/android/build.gradle`;
  `git log --oneline -- pubspec.yaml pubspec.lock`;
  `python3 tool/test_generate_dependency_matrix.py`;
  `python3 tool/generate_dependency_matrix.py --check`;
  `flutter pub outdated`.
- Relacionados: [[ADR-0005 - Distribuição Android e seleção de ABI|ADR-0005]],
  [[ADR-0007 - Licença do app e fixtures de terceiros|ADR-0007]] (aviso de
  terceiros com versão errada), [[ADR-0011 - Tamanho de APK, modelos e componentes nativos|ADR-0011]],
  [[ADR-0008 - Hierarquia documental e versionamento do vault|ADR-0008]].