---
tipo: area
area: ocr e qualidade de importação
status: PENDENTE
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [integration_test/ocr_engine_benchmark_test.dart, qa/run_ocr_benchmark.sh, test/fixtures/synthetic_two_column_80_questions.pdf, lib/core/import/ocr_service_native.dart]
sha: 516a52aef8716991f0004767a13aef7faf655fb5
confianca: alta
atualizado: 2026-11-08
---

# Benchmark de OCR

> **Estado: pendente de execução em Android.** O harness existe e está
> versionado; nenhum número desta nota foi medido ainda. Não remover uma pilha
> de OCR antes de preencher a tabela e registrar o aparelho usado.
> Decisão: [[../06 - Decisões/ADR/ADR-0011 - Tamanho de APK, modelos e componentes nativos|ADR-0011]].
> Licença do fixture: [[../06 - Decisões/ADR/ADR-0007 - Licença do app e fixtures de terceiros|ADR-0007]].

## Por que medir antes de cortar

O APK Android carrega PaddleOCR **e** ML Kit. Remover uma pilha reduz o
download, mas pode regredir a importação, que é o fluxo central do produto.
O ADR-0011 condiciona a decisão a um benchmark no mesmo corpus. Esta rodada
mede **estrutura**, não acurácia de caractere: se o OCR não recupera a
numeração e as alternativas, o parser não tem como montar a prova mesmo que
cada palavra esteja correta.

## O que o harness mede

Para cada motor, em um Android real:

- tempo por página, incluindo renderização, JPEG e chamada nativa;
- questões detectadas pelo parser após ordenação, limpeza de mobília e
  normalização — o mesmo caminho da importação;
- total de alternativas detectadas;
- ordem correta: numeração presente e sequencial de 1 até N;
- falhas estruturais: contagem divergente, numeração duplicada ou fora de
  ordem, questão com menos de 2 alternativas, enunciado vazio e página sem
  texto.

**Não mede:** acurácia de caractere (CER/WER), confiança calibrada, RAM, tempo
de primeiro uso, consumo de bateria ou tamanho instalado. Uma execução é uma
amostra; não há repetição estatística nesta rodada.

## Fixture padrão

`test/fixtures/synthetic_two_column_80_questions.pdf` — 8 páginas, duas
colunas, 80 questões objetivas com 5 alternativas cada (400 no total).
Gerado pelo projeto, permitido para teste e **proibido como conteúdo de
produto** (`test/fixtures/import_corpus.json`). O SHA-256 do PDF está no
manifesto e é conferido pelo teste de importação sintética.

O teste não lê o arquivo do repositório no aparelho: o script converte o PDF
em base64 e o entrega por `--dart-define`, com limite de 512 KiB. Isso evita
declarar o fixture como asset do app e não aumenta o APK de produção.

## Como executar

Pré-requisitos: Flutter, `adb` e **um** dispositivo Android autorizado
(aparelho físico ou emulador). Com mais de um dispositivo, defina
`ANDROID_DEVICE`.

```bash
qa/run_ocr_benchmark.sh
```

O script falha com mensagem clara quando não há dispositivo, quando o PDF não
existe ou quando ele passa do limite. Saídas:

- `build/qa/ocr-benchmark.log` — saída completa do `flutter test`;
- `build/qa/ocr-benchmark.json` — `schemaVersion`, dispositivo, arquivo de
  origem e um relatório por motor.

Para outro corpus local:

```bash
PROVA_SOCIAL_OCR_BENCHMARK_PDF=prova.pdf \
PROVA_SOCIAL_OCR_EXPECTED_QUESTIONS=80 \
PROVA_SOCIAL_OCR_EXPECTED_OPTIONS=400 \
qa/run_ocr_benchmark.sh
```

O comando direto equivalente, sem o script, é:

```bash
flutter test integration_test/ocr_engine_benchmark_test.dart -d <device> \
  --dart-define=OCR_BENCHMARK_PDF_BASE64="$(base64 -w0 test/fixtures/synthetic_two_column_80_questions.pdf)" \
  --dart-define=OCR_BENCHMARK_EXPECTED_QUESTIONS=80 \
  --dart-define=OCR_BENCHMARK_EXPECTED_OPTIONS=400
```

## Resultados

**Pendente de execução em Android.** Preencher uma linha por motor com data,
aparelho, versão do app e os valores do JSON. Não copiar números de outra
máquina nem estimar.

| Motor | Data | Aparelho | Páginas | Questões | Alternativas | Ordem | ms/página | Falhas estruturais |
| --- | --- | --- | ---: | ---: | ---: | --- | ---: | --- |
| PaddleOCR | pendente | — | — | — | — | — | — | — |
| ML Kit | pendente | — | — | — | — | — | — | — |

## Gate

1. Executar o benchmark em Android e preencher a tabela.
2. Comparar os dois motores no mesmo aparelho e no mesmo PDF.
3. Só então decidir se uma pilha sai do APK; a decisão e a evidência devem ser
   registradas no ADR-0011 antes de qualquer remoção.
4. Repetir o benchmark no corpus real disponível quando ele existir; o fixture
   sintético não substitui uma prova de banca.

Relacionado: [[Tamanho do APK]].
