#!/usr/bin/env bash
# Executa o benchmark estrutural dos dois motores de OCR em um Android real.
#
# Uso:
#   qa/run_ocr_benchmark.sh
#   PROVA_SOCIAL_OCR_BENCHMARK_PDF=outra_prova.pdf \
#     PROVA_SOCIAL_OCR_EXPECTED_QUESTIONS=80 \
#     PROVA_SOCIAL_OCR_EXPECTED_OPTIONS=400 \
#     qa/run_ocr_benchmark.sh
#
# O PDF é embutido nos defines do teste (limite de 512 KiB). O fixture padrão
# tem 13.602 B. Saídas: build/qa/ocr-benchmark.log e build/qa/ocr-benchmark.json.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() {
  echo "ERRO: $*" >&2
  exit 1
}

command -v adb >/dev/null 2>&1 || fail "adb não encontrado no PATH."
command -v flutter >/dev/null 2>&1 || fail "flutter não encontrado no PATH."
command -v python3 >/dev/null 2>&1 || fail "python3 não encontrado no PATH."

PDF="${PROVA_SOCIAL_OCR_BENCHMARK_PDF:-test/fixtures/synthetic_two_column_80_questions.pdf}"
[[ -f "$PDF" ]] || fail "PDF do benchmark não encontrado: $PDF"

size="$(wc -c < "$PDF")"
max_size=$((512 * 1024))
if (( size > max_size )); then
  fail "PDF do benchmark tem $size B; o limite para embutir no teste é $max_size B. Divida o arquivo ou use um fixture menor."
fi

if [[ -n "${ANDROID_DEVICE:-}" ]]; then
  device="$ANDROID_DEVICE"
else
  mapfile -t devices < <(adb devices | awk 'NR > 1 && $2 == "device" { print $1 }')
  if (( ${#devices[@]} == 0 )); then
    adb devices >&2 || true
    fail "Nenhum dispositivo Android autorizado. Conecte um aparelho, aceite a depuração USB ou inicie um emulador."
  fi
  if (( ${#devices[@]} > 1 )); then
    printf 'Dispositivos: %s\n' "${devices[*]}" >&2
    fail "Mais de um dispositivo conectado. Defina ANDROID_DEVICE com o id desejado."
  fi
  device="${devices[0]}"
fi

expected_questions="${PROVA_SOCIAL_OCR_EXPECTED_QUESTIONS:-80}"
expected_options="${PROVA_SOCIAL_OCR_EXPECTED_OPTIONS:-400}"
[[ "$expected_questions" =~ ^[0-9]+$ ]] || fail "PROVA_SOCIAL_OCR_EXPECTED_QUESTIONS deve ser inteiro."
[[ "$expected_options" =~ ^[0-9]+$ ]] || fail "PROVA_SOCIAL_OCR_EXPECTED_OPTIONS deve ser inteiro."

pdf_base64="$(python3 - "$PDF" <<'PY'
import base64
import sys

print(base64.b64encode(open(sys.argv[1], "rb").read()).decode("ascii"))
PY
)"

mkdir -p build/qa
log="build/qa/ocr-benchmark.log"
report="build/qa/ocr-benchmark.json"

echo "Benchmark de OCR: $PDF ($size B) em $device"
echo "Esperado: $expected_questions questões, $expected_options alternativas"
echo "Log: $log"

set +e
flutter test integration_test/ocr_engine_benchmark_test.dart \
  -d "$device" \
  --dart-define=OCR_BENCHMARK_PDF_BASE64="$pdf_base64" \
  --dart-define=OCR_BENCHMARK_EXPECTED_QUESTIONS="$expected_questions" \
  --dart-define=OCR_BENCHMARK_EXPECTED_OPTIONS="$expected_options" \
  2>&1 | tee "$log"
test_status="${PIPESTATUS[0]}"
set -e

python3 - "$log" "$report" "$device" "$PDF" <<'PY'
import json
import sys
from pathlib import Path

log_path, report_path, device, source = sys.argv[1:]
marker = "OCR_BENCHMARK_REPORT:"
runs = []
for raw in Path(log_path).read_text(encoding="utf-8", errors="replace").splitlines():
    index = raw.find(marker)
    if index < 0:
        continue
    try:
        runs.append(json.loads(raw[index + len(marker):].strip()))
    except json.JSONDecodeError:
        continue

if not runs:
    print(
        "ERRO: nenhum relatório OCR_BENCHMARK_REPORT encontrado no log. "
        "O build ou a instalação falhou antes do teste.",
        file=sys.stderr,
    )
    raise SystemExit(1)

report = {
    "schemaVersion": 1,
    "device": device,
    "source": Path(source).name,
    "runs": runs,
}
Path(report_path).write_text(
    json.dumps(report, indent=2, ensure_ascii=False) + "\n",
    encoding="utf-8",
)
print(f"Relatório: {report_path} ({len(runs)} motor(es))")
for run in runs:
    if "error" in run:
        print(f"- {run.get('engine')}: ERRO: {run['error']}")
    else:
        print(
            f"- {run.get('engine')}: {run.get('questionsDetected')} questões, "
            f"{run.get('optionsDetected')} alternativas, "
            f"ordem={run.get('orderCorrect')}, "
            f"{run.get('averageMillisecondsPerPage')} ms/página, "
            f"falhas={len(run.get('structuralFailures', []))}"
        )
PY

if (( test_status != 0 )); then
  echo "O benchmark terminou com falha de execução (código $test_status)." >&2
  exit "$test_status"
fi

echo "Benchmark executado. Registre os números em 'knowledge-base/05 - Qualidade/Benchmark de OCR.md'."
