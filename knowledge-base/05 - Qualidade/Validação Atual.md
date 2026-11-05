---
tipo: area
area: qualidade e validação
status: PARCIAL
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [test/, qa/, .github/workflows/flutter-ci.yml]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: alta
atualizado: 2026-11-05
---

# Qualidade e Validação Atual

## Gate local

Medido em 2026-11-03 e **revido em 2026-11-05** depois do Lote 0:

- `flutter analyze`: limpo em `05a8fc1`; **quebrou com o próprio Lote 0**
  (`unused_local_variable` em `test/manual/corpus_probe.dart:182`, criado ao mover
  a saída do probe para buffer) e voltou a limpo em `46eb9a0`.
- `dart format --output=none --set-exit-if-changed lib test tool packages`:
  **exit 0** em 2026-11-05 (115 arquivos). Antes falhava nos três probes
  `test/_corpus_*_test.dart`, agora movidos para `test/manual/corpus_*.dart`
  (sem sufixo `_test`), com corpus por variável de ambiente e saída em
  `build/qa/probes/`.
- `flutter test`: **313 aprovados + 1 ignorado** em 46 arquivos `*_test.dart`
  (era 296 no SHA publicado; 290 depois de tirar os probes da suíte e 313 com as
  23 expectativas de caracterização de `ff3be0c`).
- `bash qa/run_static.sh`: **exit 0 medido no próprio script**, incluindo agora
  `node --test site/tests/site.test.cjs` (4 testes) ao lado das 7 verificações
  Supabase e 11 SEO. A medição anterior usou `| tail` e leu o `$?` do `tail`, o
  que mascarou o issue do analyzer.
- Nenhum caminho `/home/nikolas` permanece em `test/`, `tool/`, `qa/`,
  `scripts/`, `site/`, `web/` ou `.github/`.

## CI

Diagnóstico lido nos logs do Actions em `NAGCODE-Dev/Prova-Social`, não deduzido:

- push do PR #18 (`05a8fc1`, run 41760190392): **QA Completo** falhou em "QA
  estático" por `dart format` nos três probes (`Changed test/_corpus_*_probe_test.dart`).
- schedule de 2026-11-05 (run 42047549926): falhou antes, em "Resolver dependências
  Android" — `Could not download kotlin-compiler-embeddable-2.2.21.jar`, **504 do
  JetBrains Releases**. Transitório, sem relação com o Lote 0; o QA Completo nem
  executou.
- schedule de 2026-11-04 (run 41849374037): verde — a janela entre os dois runs é o
  que separa o transitório do real.

**Estado de 2026-11-05:** a correção está commitada e empurrada para
`NAGC-Student/main` (`27403be`, `eebb2b0`, `46eb9a0`, `ff3be0c`). `git push
upstream main` retorna 403 (sem escrita em `NAGCODE-Dev`) e o fork não registra
nenhum run de Actions, então **só um PR** produz evidência de CI. `qa-full` voltou a
rodar em `schedule` (`flutter-ci.yml:134`) e os testes do site entraram no gate
estático (`qa/run_static.sh`). Evitar imprimir conteúdo extraído de prova nos logs:
os probes agora gravam relatórios em arquivo.

## Auditoria das 18 áreas

- **18 de 18** áreas auditadas no SHA `05a8fc1`, com notas em
  [[../09 - Auditoria/Áreas/Mapa das Áreas|Mapa das Áreas]].
- **Placar:** 16 **EVOLUIR**, 2 **REFATORAR** (Domínio e Supabase), nenhuma
  **MANTER** ou **REESCREVER**.
- **Média geral:** 2,92/5. Mais fortes: clareza (3,44), segurança (3,39) e
  portabilidade (3,33). Mais fracos: aderência (2,17), robustez (2,39) e testes
  (2,56).
- **Achados de validação mais relevantes:** CI vermelho por formatação; probes
  não portáveis; ausência de `integration_test/`, cobertura, goldens e teste
  nativo do Paddle; RLS social e Storage sem cobertura; site com 4 testes fora
  do CI; release sem APK universal e sem checksums; APK arm64 de 82 MB.
- **Síntese e ordem dos lotes:**
  [[../09 - Auditoria/Síntese da Refatoração|Síntese da Refatoração]].
- **Detalhes:** [[../09 - Auditoria/Áreas/14 - Testes, QA e benchmark|área 14]]
  e [[../09 - Auditoria/Áreas/15 - CI-CD, releases, site, Web e PWA|área 15]].

## Benchmark do parser

O script `qa/run_corpus_benchmark.sh` aplica `PdfTextExtractor`,
`QuestionParser` e `ImportQualityGate` aos 46 PDFs únicos disponíveis; sem
ground truth, 2.419 detectadas é uma contagem candidata, não uma métrica de
precisão. O runner Linux não verifica OCR nativo nem preservação visual.

## Scanner (área 9)

- 11 arquivos de teste do scanner: **105 aprovados, 1 ignorado** em 2026-11-04.
  O ignorado é o caderno ENEM 2025, cujo PDF não está versionado; o teste de
  gabarito do ENEM executou.
- VUNESP 2024: 32 páginas, 80 questões, ordem 1–80, quatro questões visuais com
  alternativas vazias, previews e quality gate `review`.
- Sintético: 8 páginas, 80 questões em duas colunas, sem revisão pendente.
- ENEM 2025 (quando o PDF existe): 90 questões em 32 páginas, ≥85 com cinco
  alternativas e ≤12 para revisão.
- O fixture VUNESP está versionado com licença não verificada; é QA local, não
  conteúdo de produto.
- Não coberto: OCR nativo em aparelho, câmera/galeria, fidelidade visual,
  fórmulas, feedback remoto e precisão/recall contra ground truth.
- Detalhes e critérios de aceite em
  [[../09 - Auditoria/Áreas/09 - Importação, OCR, parser e quality gate|Auditoria da área 9]].

## Não verificado

Mobile/desktop real, navegador real, leitores de tela, execução offline após
crash, fluxo completo de publicação autenticada, migrações no backend ativo e
direitos de redistribuição.
