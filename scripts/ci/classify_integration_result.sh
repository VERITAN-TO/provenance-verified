#!/usr/bin/env bash
# Classifies a real-backend-integration test outcome as EXECUTED_PASS,
# EXECUTED_FAIL_EXTERNAL_BACKEND, or EXECUTED_FAIL_NATIVE_OR_UNCLASSIFIED.
#
# Attribution, not suppression: this never turns a real failure green. It only
# decides whether Native is faithfully reporting a server-side failure (external
# backend) or hit a genuine Native exception/assertion failure (native/unclassified).
#
# Inputs (env):
#   INT_TEST_OUTCOME - "success" | "failure" | anything else
#   BOOTSTRAP_CLASS  - diagnostic probe classification (HTML_RESPONSE, CONNECTION_FAILED,
#                      JSON_RESPONSE, UNKNOWN, CREDENTIAL_OR_CONFIG_MISSING, ...)
#   TEST_OUTPUT_FILE - path to the flutter test integration output (may not exist)
#
# Prints the resulting integration_state to stdout.
set -euo pipefail

INT_TEST_OUTCOME="${INT_TEST_OUTCOME:-}"
BOOTSTRAP_CLASS="${BOOTSTRAP_CLASS:-}"
TEST_OUTPUT_FILE="${TEST_OUTPUT_FILE:-/dev/null}"

if [ "$INT_TEST_OUTCOME" = "success" ]; then
  echo "EXECUTED_PASS"
  exit 0
fi

if [ "$INT_TEST_OUTCOME" = "failure" ]; then
  if [ "$BOOTSTRAP_CLASS" = "HTML_RESPONSE" ] || [ "$BOOTSTRAP_CLASS" = "CONNECTION_FAILED" ]; then
    echo "EXECUTED_FAIL_EXTERNAL_BACKEND"
    exit 0
  fi
  # A structured ApiException(5xx/...) thrown from MobileTokenService._bootstrap in the
  # actual test run means Native correctly reached the server and is faithfully
  # surfacing a server-side error — external backend, even when the separate
  # diagnostic probe (which uses a placeholder tenant/device) got a well-formed
  # JSON_RESPONSE; a 5xx during the real authenticated bootstrap call is a distinct,
  # later-stage server-side failure the probe cannot see.
  BACKEND_5XX_COUNT=$(grep -cE 'ApiException\(5[0-9]{2}/' "$TEST_OUTPUT_FILE" 2>/dev/null || true)
  BACKEND_5XX_COUNT="${BACKEND_5XX_COUNT:-0}"
  if [ "$BACKEND_5XX_COUNT" -gt 0 ]; then
    echo "EXECUTED_FAIL_EXTERNAL_BACKEND"
    exit 0
  fi
  echo "EXECUTED_FAIL_NATIVE_OR_UNCLASSIFIED"
  exit 0
fi

echo "EXECUTED_FAIL_NATIVE_OR_UNCLASSIFIED"
