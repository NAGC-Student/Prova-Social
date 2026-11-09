#!/usr/bin/env bash
set -uo pipefail

mkdir -p build/qa
failed=0

run() {
  echo
  echo "===== $1 ====="
  shift
  "$@" || failed=1
}

run "Flutter version" flutter --version
run "Dart version" dart --version
run "Dart format" dart format --output=none --set-exit-if-changed lib test tool packages integration_test
run "Flutter analyze" flutter analyze
run "Supabase build configuration" python3 tool/test_supabase_build_config.py
run "APK size report" python3 tool/test_apk_size_report.py
run "Public SEO pages" python3 tool/test_generate_seo_pages.py
run "Documentation hierarchy and links" python3 tool/test_docs_links.py
run "Dependency matrix generator" python3 tool/test_generate_dependency_matrix.py
run "Dependency matrix freshness" python3 tool/generate_dependency_matrix.py --check
run "Design token discipline" python3 tool/test_design_tokens.py
run "Site tests" node --test site/tests/site.test.cjs

exit "$failed"
