#!/usr/bin/env bash
# Roda os probes manuais de corpus. Eles ficam fora da suíte automatizada:
# cada probe só executa quando a pasta do corpus é informada pelo ambiente.
set -euo pipefail

provas_dir="${PROVA_SOCIAL_PROVAS_DIR:-}"
corpus_root="${PROVA_SOCIAL_CORPUS_ROOT:-}"

if [[ -z "$provas_dir" && -z "$corpus_root" ]]; then
  echo "Defina PROVA_SOCIAL_PROVAS_DIR (pasta de PDFs de prova) e/ou" >&2
  echo "PROVA_SOCIAL_CORPUS_ROOT (repositório do corpus)." >&2
  echo "Uso: PROVA_SOCIAL_CORPUS_ROOT=/caminho/do/corpus $0" >&2
  exit 64
fi

for root in "$provas_dir" "$corpus_root"; do
  if [[ -n "$root" && ! -d "$root" ]]; then
    echo "Pasta inexistente: $root" >&2
    exit 66
  fi
done

output_dir="${PROVA_SOCIAL_PROBE_OUTPUT_DIR:-build/qa/probes}"
mkdir -p "$output_dir"
export PROVA_SOCIAL_PROBE_OUTPUT_DIR="$output_dir"

run_probe() {
  local target="$1"
  echo
  echo "===== probe $target ====="
  flutter test --reporter expanded --concurrency=1 --timeout=60m "$target"
}

if [[ -n "$provas_dir" ]]; then
  run_probe test/manual/corpus_probe.dart
fi

if [[ -n "$corpus_root" ]]; then
  run_probe test/manual/corpus_bench_probe.dart
  run_probe test/manual/corpus_detail_probe.dart
  run_probe test/manual/corpus_page_probe.dart
fi

echo
echo "Relatórios em $output_dir (fora do Git)."
