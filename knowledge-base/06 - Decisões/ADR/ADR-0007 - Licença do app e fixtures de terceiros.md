---
tipo: adr
area: licença e conteúdo de terceiros
status: INTENÇÃO
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [README.md, pubspec.yaml, test/fixtures/import_corpus.json, test/fixtures/README.md, test/vunesp_2024_import_test.dart, test/enem_2025_import_test.dart, packages/paddleocr_android/THIRD_PARTY_NOTICES.md, packages/paddleocr_android/android/build.gradle, .gitignore]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: media
atualizado: 2026-11-07
---

# ADR-0007 — Licença do app e política de fixtures de terceiros

- **Status:** aceito
- **Data:** 2026-11-07
- **Responsável pela aprovação:** NAGCODE-Dev (responsável pelo projeto)
- **Licença escolhida:** distribuição restrita, todos os direitos reservados
  (alternativa **C**, decidida em 2026-11-07; materializada em `LICENSE`).
- **Áreas:** 9, 14, 17, 18
- **Urgência:** Alta

## Contexto

O README declara uma condição jurídica que nenhum arquivo concede, e a
política de fixtures já existe — mas só para um arquivo.

- **“Código aberto” sem licença.** `README.md:163-166`: seção “📜 Licença”
  com “Prova Social - Código aberto para fins educacionais.” e, na linha
  seguinte, “Não publicar, fazer commit, criar tag, release ou push sem
  autorização explícita.” As duas frases tensionam: “código aberto” é uma
  condição de licenciamento, “só com autorização” é uma restrição de uso.
  Sem arquivo de licença, o default legal é reserva de todos os direitos —
  a frase não concede nada.
- **Nenhuma licença na raiz.** `git ls-files | grep -iE "licen|copying"`
  retorna só `packages/paddleocr_android/LICENSE` (Apache License 2.0,
  confirmado pelo cabeçalho do arquivo). Não há `LICENSE` nem `COPYING` do
  app. `pubspec.yaml:1-4` tem `name`, `description`, `publish_to: none` e
  `version` — nenhum campo `repository`, `homepage`, `issue_tracker` ou
  licença.
- **A política de fixtures já está codificada.**
  `test/fixtures/import_corpus.json:26-33` registra o PDF da VUNESP como
  `kind: "user-provided-benchmark"`, `licenseStatus: "not-verified"`,
  `allowedForTesting: true`, `allowedForProductContent: false`, com `sha256`
  do documento. `test/vunesp_2024_import_test.dart:28-31` **confere** esses
  quatro campos e `:35-36` valida o hash do PDF. Ou seja: o mecanismo de
  decisão existe e é testado; o que falta é aplicá-lo a todo material de
  terceiros e decidir o que fazer com o que já está no Git.
- **O fixture de terceiro está commitado e roda no CI.**
  `git ls-files test/fixtures` = 6 arquivos, `du -sh test/fixtures` = 2,1 MB,
  incluindo `vunesp_2024_pm_sp.pdf` (2.100.617 B). O CI roda a suíte inteira
  (`.github/workflows/flutter-ci.yml:179` → `qa/run_tests.sh:16`,
  `flutter test`), então esse PDF é baixado por todo clone e processado em
  toda esteira. Não há guard de skip para ele.
- **O ENEM segue o padrão oposto.** `2025_PV_impresso_D1_CD1.pdf` (3,2 MB)
  está na raiz mas é ignorado (`.gitignore:64`) e não rastreado;
  `test/enem_2025_import_test.dart:20,75,97` pula quando o arquivo não
  existe. Resultado: a cobertura do ENEM nunca roda no CI, e a da VUNESP
  roda sempre.
- **Até o fixture sintético está barrado de produto.**
  `import_corpus.json:6-11` marca o sintético (gerado pelo projeto,
  `test/fixtures/generate_synthetic_two_column_exam.py`) também com
  `allowedForProductContent: false`. Há ainda um
  `synthetic_two_column_80_questions.pdf.backup` rastreado, duplicata do
  fixture.
- **Avisos de terceiros com versão errada.**
  `packages/paddleocr_android/THIRD_PARTY_NOTICES.md:12-16` declara os
  modelos PP-OCRv6 tiny como Apache-2.0 e lista SHA-256 (conferidos: batem
  com os arquivos em `android/src/main/assets/models/`). Mas `:21` declara
  “ONNX Runtime Android `1.21.1` — MIT” enquanto
  `packages/paddleocr_android/android/build.gradle:32` embarca
  `onnxruntime-android:1.31.1`. O aviso não descreve o binário distribuído.
- **Paráfrases de banca sem origem declarada.**
  `test/bancas_import_test.dart` usa 10 casos de texto inline nomeados por
  banca (`:23,67,92,134,174,210,250,291,323,358`), sem PDF. O status de
  direito autoral dessas paráfrases não é verificável estaticamente.
- **Regra normativa já existente.** `AGENTS.md:380`: “Não baixar ou
  republicar imagens sem licença compatível.” A aba que pediria autoria,
  licença e URL (`AGENTS.md:374-378`) não existe — ver ADR-0006.

**Limites.** Este ADR não dá parecer jurídico: a escolha de licença e a
avaliação de uso de prova de terceiro são decisões do responsável, com
assessoria se ele julgar necessária. Não foi feita busca externa pelos
termos de uso da VUNESP/FGV nem pelo status de direito autoral de provas
públicas. Não foi inspecionado o conteúdo impresso dos streams comprimidos
do PDF (a atribuição pode estar lá e não ser extraível por `strings`).

## Decisão

**Aprovada em 2026-11-07 pelo responsável pelo projeto (NAGCODE-Dev).**
A política de fixtures e as correções mecânicas foram aprovadas junto com a
escolha da licença, decidida na mesma data. Não resta pendência de licença.

1. **Licença do app — alternativa C, distribuição restrita.** Todos os direitos
   reservados; nenhuma concessão de licença de uso, cópia, modificação ou
   distribuição do código-fonte. A expressão “código aberto para fins
   educacionais” saiu do `README.md`, que passou a declarar copyright e
   restrição. `publish_to: none` e a regra de autorização explícita permanecem.
   O arquivo `LICENSE` na raiz materializa a decisão em nove cláusulas.

   **Como a versão web hospedada foi tratada.** O contexto deste ADR registrava
   que AGPL e licenças permissivas tratam o serviço hospedado de forma
   diferente. A alternativa C resolve isso separando código de artefato: a
   cláusula 2 não concede direito algum sobre o código-fonte; a cláusula 3
   permite executar os APKs e a versão web **que o próprio titular publica**,
   para fim pessoal e educacional, sem redistribuição, hospedagem própria,
   engenharia reversa ou uso comercial. Sem essa distinção o binário que o
   projeto distribui seria inutilizável por quem o recebe, o que contradiria a
   existência do site e das releases. A distinção é materialização de C, não
   uma quarta alternativa; restringir também a execução seria edição da
   cláusula 3, e cabe ao responsável.
2. **Política de fixtures — aprovada.** Estender o padrão que já funciona em
   `import_corpus.json` a **todo** material de terceiro (PDF, imagem, texto
   de banca, modelo), com `licenseStatus`, `allowedForTesting` e
   `allowedForProductContent` obrigatórios e um teste que falha se faltar
   campo.
3. **Correções mecânicas — aprovadas.** Corrigir
   `THIRD_PARTY_NOTICES.md:21` para `1.31.1` (ou voltar o pino, o que é
   decisão do ADR-0009) e remover a duplicata `.backup` do fixture sintético.
4. **PDF da VUNESP — mantido sob a política atual.** O arquivo continua no
   Git como `user-provided-benchmark`, `licenseStatus: not-verified`,
   `allowedForTesting: true` e `allowedForProductContent: false`, até que o
   responsável decida movê-lo para corpus local ou substituí-lo por
   sintético equivalente. O destino do arquivo fica registrado como ponto
   aberto, separado da licença do app.

## Alternativas

**C foi a escolhida em 2026-11-07**; A, B, D e E não foram adotadas. Os itens
mecânicos 2–4 acima não correspondem a uma alternativa de licença e foram
aprovados separadamente. O texto abaixo é a avaliação feita antes da escolha,
preservada como estava — inclusive os contras de C, um dos quais a cláusula 3 do
`LICENSE` mitiga (ver `## Decisão` e `## Consequências e reversão`).

- **A — Licença permissiva (MIT ou Apache-2.0) + política de fixtures
  estendida.** Prós: coerente com “código aberto”; Apache-2.0 alinha com o
  plugin PaddleOCR e concede patente; remove a ambiguidade do README.
  Contras: permite uso comercial e fechado por terceiros; “para fins
  educacionais” deixa de ser restrição e vira descrição; não obriga quem
  hospeda o app como serviço a publicar alterações.
- **B — Licença de rede (AGPL-3.0) + política estendida.** Prós: quem roda
  o app como serviço precisa oferecer o código; combina com a versão web
  hospedada. Contras: incompatível com parte do ecossistema de plugins e
  com a ideia de “fins educacionais” sem restrição; assusta contribuidores;
  exige cuidado com a combinação de códigos Apache/MIT embarcados.
- **C — Distribuição restrita (escolhida; código disponível, sem concessão).** Remover
  “código aberto” do README, manter `publish_to: none` e a regra de
  autorização. Prós: nenhuma concessão de direitos; coerente com
  `README.md:166`. Contras: ninguém pode usar, estudar ou contribuir
  legalmente sem permissão individual; contradiz o propósito educacional
  declarado.
- **D — Não fazer.** Prós: custo zero. Contras: o README continua afirmando
  uma condição que não existe; o PDF `not-verified` continua em todo clone e
  em toda esteira; o aviso de terceiros continua descrevendo uma versão que
  não é a embarcada.
- **E — Remover todo material de terceiro do Git (padrão ENEM para todos).**
  Prós: risco de distribuição some do repositório público. Contras: a
  cobertura de importação real sai do CI e passa a depender de arquivos
  locais que ninguém mais tem; o histórico continua contendo o blob.

## Consequências e reversão

- **Positivas:** uma condição jurídica declarada e verdadeira; política de
  fixtures com teste, não com boa intenção; avisos de terceiros batendo com
  os binários; decisão explícita sobre o que pode ir para conteúdo de
  produto.
- **Negativas/custos:** escolher licença tem efeito permanente sobre cópias
  já distribuídas; estender a política exige inventariar todo material de
  terceiro (incluindo os 10 textos inline de `bancas_import_test.dart`);
  remover o PDF da VUNESP reduz cobertura de CI.
- **Riscos:** relicenciar código que já recebeu contribuição de terceiros
  exige direito sobre ele; remover arquivo do Git **não** remove do
  histórico — reescrita de histórico é operação destrutiva e só com
  autorização explícita.
- **Reversão:** adicionar `LICENSE` é reversível no arquivo, mas **não** nas
  cópias já baixadas sob aquela licença. Por isso a alternativa D (adiar) é
  menos custosa que escolher errado. A política de fixtures e a correção do
  `THIRD_PARTY_NOTICES.md` são reversíveis por `git revert`.
- **Materialização em 2026-11-07, com C escolhida:** `LICENSE` criado na raiz.
  O contra de C registrado acima (“ninguém pode usar, estudar ou contribuir
  legalmente sem permissão individual”) vale para o **código-fonte**; a
  cláusula 3 permite executar o binário e o site que o titular publica, o que
  preserva o uso educacional sem conceder direito sobre o código. Como não
  houve concessão permissiva anterior — o contexto deste ADR já registrava que,
  sem arquivo de licença, o default legal é reserva de todos os direitos —
  **não há relicenciamento de cópias já distribuídas**: o `LICENSE` torna
  explícito o que já valia. A reversão é, portanto, mais barata do que a
  avaliação acima sugeria para A ou B: afrouxar a cláusula 3 não desfaz
  concessão feita a terceiros.
- **Materialização em 2026-11-07, itens 2 e 3 da decisão:** o manifesto passou a
  exigir `licenseStatus` em toda entrada — o sintético declara
  `project-generated` — e `test/fixture_license_policy_test.dart` falha se
  faltar campo, se o `id` repetir, se o documento não existir, se o `sha256`
  não tiver 64 dígitos hexadecimais, se um item liberado para produto estiver
  `not-verified` ou se houver `.backup` em `test/fixtures/`. Os três modos de
  falha relevantes foram exercitados antes do commit: sem o campo (1 teste
  vermelho), com `allowedForProductContent: true` em item `not-verified`
  (1 vermelho) e com a duplicata presente (1 vermelho); com o manifesto
  restaurado, 5 verdes. `THIRD_PARTY_NOTICES.md` agora declara ONNX Runtime
  `1.31.1`, igual a `build.gradle:32`. A duplicata
  `synthetic_two_column_80_questions.pdf.backup` foi removida do Git: o SHA-256
  dela era idêntico ao do original (`6bd98404…`), e o blob continua no
  histórico — remover do índice não é reescrever histórico.

## Evidências e validação

- Áreas: [[../../09 - Auditoria/Áreas/09 - Importação, OCR, parser e quality gate|Área 09]],
  [[../../09 - Auditoria/Áreas/14 - Testes, QA e benchmark|Área 14]],
  [[../../09 - Auditoria/Áreas/17 - Dependências e manutenção|Área 17]],
  [[../../09 - Auditoria/Áreas/18 - Documentação e divergências código × docs|Área 18]].
- Arquivos: [LICENSE](../../../LICENSE), [README.md](../../../README.md), [pubspec.yaml](../../../pubspec.yaml),
  [test/fixtures/import_corpus.json](../../../test/fixtures/import_corpus.json),
  [test/fixtures/README.md](../../../test/fixtures/README.md),
  [THIRD_PARTY_NOTICES.md](../../../packages/paddleocr_android/THIRD_PARTY_NOTICES.md),
  [build.gradle do plugin](../../../packages/paddleocr_android/android/build.gradle),
  [.gitignore](../../../.gitignore).
- Testes: [fixture_license_policy_test.dart](../../../test/fixture_license_policy_test.dart),
  [vunesp_2024_import_test.dart](../../../test/vunesp_2024_import_test.dart),
  [enem_2025_import_test.dart](../../../test/enem_2025_import_test.dart),
  [bancas_import_test.dart](../../../test/bancas_import_test.dart),
  [local_corpus_benchmark_test.dart](../../../test/local_corpus_benchmark_test.dart).
- **Exigido antes de implementar:** ~~decisão de licença do responsável por
  escrito~~ — **satisfeita em 2026-11-07** (alternativa C, `LICENSE` na raiz).
  ~~Teste que exige `licenseStatus` + `allowedForTesting` +
  `allowedForProductContent` em toda entrada do corpus~~ — **satisfeito em
  2026-11-07** (`test/fixture_license_policy_test.dart`, 5 testes).
  Pendente: conferência de SHA-256 dos modelos contra o aviso; `git ls-files`
  revisado para binários de terceiro; para E, medir qual cobertura de CI se
  perde antes de remover.
- **Inventário dos textos inline, lido em 2026-11-07:** os 10 casos de
  `bancas_import_test.dart` foram lidos por inteiro. Nove são enunciados
  genéricos escritos no formato impresso da banca, sem texto de apoio. O caso
  ENEM (`test/bancas_import_test.dart:358-387`) remete a “esse texto”,
  “a autora” e “Nesse poema” sem incluir o texto de apoio — padrão de item
  copiado de prova real, não de enunciado inventado. A procedência desse caso
  **não está verificada**; fica como ponto aberto da política de fixtures
  (registrar no manifesto ou substituir por sintético equivalente) e não
  autoriza conteúdo de produto. O arquivo não foi alterado nesta rodada.
- Comandos de reprodução:
  `git ls-files | grep -iE "licen|copying"`;
  `git ls-files test/fixtures`;
  `grep -n "onnxruntime-android" packages/paddleocr_android/android/build.gradle`
  → `1.31.1`; `grep -n "ONNX Runtime" packages/paddleocr_android/THIRD_PARTY_NOTICES.md`
  → `1.21.1` na auditoria, `1.31.1` depois da correção de 2026-11-07;
  `sed -n '163,166p' README.md`;
  `flutter test test/fixture_license_policy_test.dart`.
- Relacionados: [[ADR-0006 - Escopo de importação por câmera|ADR-0006]],
  [[ADR-0009 - Política de dependências e pins|ADR-0009]],
  [[ADR-0011 - Tamanho de APK, modelos e componentes nativos|ADR-0011]],
  [[ADR-0005 - Distribuição Android e seleção de ABI|ADR-0005]].