#!/usr/bin/env bash
set -euo pipefail

root="${PROVA_SOCIAL_CORPUS_ROOT:-build/qa/military-exams}"
python3 qa/update_corpus.py

PROVA_SOCIAL_CORPUS_ROOT="$root" \
  flutter test --reporter expanded --concurrency=1 --timeout 30m \
  test/local_corpus_benchmark_test.dart

# Reuse the separately maintained downloader/corpus when it is present.
external_root="${PROVA_SOCIAL_EXTERNAL_CORPUS_ROOT:-/home/nikolas/Corpus/prova-social-corpus}"
if [[ -f "$external_root/datasets/manifests/documents.jsonl" ]]; then
  external_pythonpath="$external_root/src"
  if PYTHONPATH="$external_pythonpath" python3 -c 'import pydantic' 2>/dev/null; then
    PYTHONPATH="$external_pythonpath" python3 -m prova_social_corpus.cli normalize
  else
    echo "Dependências Python do corpus não instaladas; usando normalizados existentes."
  fi
  python3 qa/validate_corpus_answer_links.py "$external_root"
  PROVA_SOCIAL_CORPUS_ROOT="$external_root" \
    flutter test --reporter expanded --concurrency=1 --timeout 60m \
    test/local_corpus_benchmark_test.dart
fi

flutter test --reporter expanded \
  test/content_package_test.dart \
  test/digital_exam_service_test.dart \
  test/publication_contract_test.dart
