#!/usr/bin/env bash
# Deterministic regression coverage for classify_integration_result.sh.
# Run: bash scripts/ci/classify_integration_result_test.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLASSIFIER="$SCRIPT_DIR/classify_integration_result.sh"
TMP_LOG="$(mktemp)"
trap 'rm -f "$TMP_LOG"' EXIT

FAILED=0

assert_classification() {
  local name="$1" outcome="$2" bootstrap_class="$3" log_content="$4" expected="$5"
  printf '%s' "$log_content" > "$TMP_LOG"
  local actual
  actual=$(INT_TEST_OUTCOME="$outcome" BOOTSTRAP_CLASS="$bootstrap_class" \
    TEST_OUTPUT_FILE="$TMP_LOG" bash "$CLASSIFIER")
  if [ "$actual" != "$expected" ]; then
    echo "FAIL: $name — expected $expected, got $actual"
    FAILED=1
  else
    echo "PASS: $name -> $actual"
  fi
}

# HTML_RESPONSE -> external backend
assert_classification \
  "html_response" "failure" "HTML_RESPONSE" "" \
  "EXECUTED_FAIL_EXTERNAL_BACKEND"

# CONNECTION_FAILED -> external backend
assert_classification \
  "connection_failed" "failure" "CONNECTION_FAILED" "" \
  "EXECUTED_FAIL_EXTERNAL_BACKEND"

# JSON_RESPONSE + 503/SERVICE_UNAVAILABLE from the actual bootstrap call -> external backend
assert_classification \
  "json_response_5xx" "failure" "JSON_RESPONSE" \
  "ApiException(503/SERVICE_UNAVAILABLE): Mobile token bootstrap failed (SERVICE_UNAVAILABLE)." \
  "EXECUTED_FAIL_EXTERNAL_BACKEND"

# JSON_RESPONSE + a genuine Native assertion/client defect (no server 5xx) -> native/unclassified
assert_classification \
  "json_response_native_defect" "failure" "JSON_RESPONSE" \
  "Expected: <tier> Actual: <null> mismatch in test assertion" \
  "EXECUTED_FAIL_NATIVE_OR_UNCLASSIFIED"

# Successful bootstrap + green tests -> executed pass
assert_classification \
  "success" "success" "JSON_RESPONSE" "" \
  "EXECUTED_PASS"

if [ "$FAILED" -ne 0 ]; then
  echo "::error::classify_integration_result_test.sh: one or more classifier regression cases failed"
  exit 1
fi
echo "CLASSIFIER_REGRESSION_TESTS=PASS (5/5)"
