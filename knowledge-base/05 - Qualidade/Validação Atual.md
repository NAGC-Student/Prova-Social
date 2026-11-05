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

- `flutter analyze`: limpo.
- `dart format --output=none --set-exit-if-changed lib test tool packages`:
  **exit 0** em 2026-11-05. Antes falhava nos três probes
  `test/_corpus_*_test.dart`, agora movidos para `test/manual/corpus_*.dart`
  (sem sufixo `_test`), com corpus por variável de ambiente e saída em
  `build/qa/probes/`.
- `flutter test`: **290 aprovados + 1 ignorado** em 43 arquivos `*_test.dart`
  (era 296; a diferença são os probes fora da suíte automatizada).
- `bash qa/run_static.sh`: **exit 0**, incluindo agora
  `node --test site/tests/site.test.cjs` (4 testes) ao lado das 7 verificações
  Supabase e 11 SEO.
- Nenhum caminho `/home/nikolas` permanece em `test/`, `tool/`, `qa/`,
  `scripts/`, `site/`, `web/` ou `.github/`.

## CI

Runs #100 e #104 interrompem no format gate; o analyzer passou. Run #98 é
agendado e seu job QA completo foi ignorado. **Estado de 2026-11-05:** a
correção existe apenas no worktree — `qa-full` voltou a rodar em `schedule`
(`flutter-ci.yml:134`) e os testes do site entraram no gate estático
(`qa/run_static.sh`), mas nada foi commitado nem empurrado, então `main` no
GitHub segue vermelha no SHA publicado. Evitar imprimir conteúdo extraído de
prova nos logs: os probes agora gravam relatórios em arquivo.

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
