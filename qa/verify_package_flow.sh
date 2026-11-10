#!/usr/bin/env bash
set -euo pipefail

# JSON payload -> gzip package -> verified download -> local media.
flutter test --reporter expanded \
  test/content_package_test.dart \
  test/digital_exam_service_test.dart \
  test/publication_contract_test.dart
