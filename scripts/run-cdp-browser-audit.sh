#!/usr/bin/env bash
set -euo pipefail
PORT="${CDP_PORT:-9222}"
LOG="${TMPDIR:-/tmp}/pv-cdp-browser.log"
chromium --headless=new --no-sandbox --disable-gpu --disable-software-rasterizer --disable-background-networking --disable-component-update --disable-default-apps --disable-sync --metrics-recording-only --no-first-run --remote-debugging-port="$PORT" about:blank >"$LOG" 2>&1 &
pid=$!
trap 'kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true' EXIT
for _ in $(seq 1 80); do
  if curl -sf "http://127.0.0.1:${PORT}/json/version" >/dev/null; then break; fi
  sleep 0.1
done
FORCE_NO_WEBGL=true CDP_PORT="$PORT" node scripts/cdp-local-browser-audit.mjs review/PROVENANCE_CX_R8_PRODUCTION_CAMPAIGN_REVIEW_STANDALONE.html
