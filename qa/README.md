# Corpus incremental e pacotes de conteúdo

O corpus de QA fica em `build/qa/military-exams` e não é empacotado no
aplicativo. `qa/update_corpus.py` lê `qa/corpus_manifest.json`, baixa somente
arquivos ausentes e gera um manifesto local com SHA-256. Links sem download
direto ficam pendentes e não bloqueiam as outras fontes.

O projeto separado `/home/nikolas/Corpus/prova-social-corpus` é reutilizado
quando existe. Ele mantém o catálogo, arquivos por hash, normalização e
associação de gabaritos. O fluxo também valida que cada vínculo aponta para
uma chave com números de questões compatíveis.

```bash
qa/run_incremental_corpus.sh
```

Esse comando testa o corpus novo, depois o corpus externo, e por fim valida o
fluxo de publicação e conteúdo: JSON → gzip → download verificado →
descompactação → mídia local. A atualização de provas e pacotes de conteúdo
ocorre sem reinstalar o aplicativo; uma mudança no código do parser continua
sendo uma atualização do app.

## Baseline real da ESA

Com os PDFs oficiais ESA 2024, 2025 e 2026 disponíveis em
`build/qa/military-exams/exercito`, reproduza a verificação com:

```bash
flutter test test/local_corpus_benchmark_test.dart --reporter expanded
```

O benchmark grava `build/qa/esa-corpus-benchmark.json`, incluindo URL de origem,
SHA-256, resultados por documento e evidências dos metadados. Na execução de
2026-11-09:

- 3 documentos processados; 150/150 questões objetivas numeradas recuperadas
  na sequência esperada (1–50 por caderno).
- 109/150 (72,7%) tinham exatamente cinco alternativas detectadas. Isso é
  somente uma medida de estrutura/contagem: não comprova que o texto ou as
  alternativas estejam corretos.
- Título, instituição, ano, categoria e instância Tipo A coincidiram com a
  referência em 3/3 documentos. A banca ficou pendente nos 3/3; essa abstenção
  é intencional e não conta como identificação correta.
- OCR não foi avaliado. Fidelidade de imagens, fórmulas e diagramas requer
  comparação visual manual e não está incluída nessas métricas.

Essa amostra representa apenas a ESA; não deve ser apresentada como precisão
multibanca nem como aprovação integral do parser.
