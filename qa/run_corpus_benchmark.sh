#!/usr/bin/env bash
set -euo pipefail

corpus_root="${1:-${PROVA_SOCIAL_CORPUS_ROOT:-}}"
if [[ -z "$corpus_root" ]]; then
  echo "Usage: $0 /path/to/prova-social-corpus" >&2
  exit 64
fi

manifest="$corpus_root/datasets/manifests/documents.jsonl"
if [[ ! -f "$manifest" ]]; then
  echo "Corpus manifest not found: $manifest" >&2
  exit 66
fi

PROVA_SOCIAL_CORPUS_ROOT="$corpus_root" \
  flutter test --reporter expanded --concurrency=1 --timeout 10m \
    test/local_corpus_benchmark_test.dart
