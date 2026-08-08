#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"; mkdir -p evidence/r3/final-local
run(){ local name="$1"; shift; echo "=== $name ==="; "$@" >"evidence/r3/final-local/${name}.log" 2>&1; echo "$name PASS"; }
rm -rf .audit-build .r3-test-build
run typecheck-offline npm run typecheck:offline
run r3-compile npx --no-install tsc -p tsconfig.r3-runtime.json --pretty false
run r3-runtime node --test .r3-test-build/tests/r3/*.test.js
run provider-contract python3 scripts/provider-contract-audit.py
run migration-contract node scripts/migration-contract-audit.mjs
run source-quality node scripts/source-quality-audit.mjs
run production-boundary node scripts/verify-production-authority.mjs
run ledger-coverage python3 scripts/verify-r3-authority-ledgers.py
run commercial-authority node scripts/commercial-authority-audit.mjs
run operational-control node scripts/r3-operational-control-audit.mjs
run remaining-authority node scripts/remaining-authority-audit.mjs
run security-headers node scripts/security-header-audit.mjs
run browser-command-security node scripts/browser-command-security-audit.mjs
run offline-security node scripts/offline-security-audit.mjs
run public-inquiry node scripts/public-inquiry-audit.mjs
run knowledge-authority node scripts/knowledge-authority-audit.mjs
run key-discovery node scripts/key-discovery-audit.mjs
run registry-privacy node scripts/registry-privacy-audit.mjs
run freshness-regression node scripts/freshness-regression-audit.mjs
run sandbox-lifecycle node scripts/sandbox-lifecycle-audit.mjs
run observability-delivery node scripts/observability-delivery-audit.mjs
run supply-chain node scripts/supply-chain-audit.mjs
run capacity node scripts/r3-capacity-benchmark.mjs
run design-release node scripts/design-release-audit.mjs
run link-audit node scripts/link-audit.mjs
run continuity node scripts/continuity-lint.mjs
run phase3 python3 scripts/phase3-static-audit.py
run phase4 python3 scripts/phase4-static-audit.py
run caliber python3 scripts/caliber-static-audit.py
run build-r3-standalone node scripts/build-r3-review-standalone.mjs
run standalone-flow python3 scripts/r3-standalone-audit.py
run standalone-visual python3 scripts/r3-standalone-visual-audit.py
run standalone-chromium python3 scripts/r3-cross-browser-standalone.py
python3 - <<'PY'
import json, pathlib, datetime
root=pathlib.Path('evidence/r3/final-local'); logs=sorted(root.glob('*.log'))
report={'generatedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'scope':'All locally executable R3 gates; excludes exact npm lockfile install/Next build, unavailable browser engines, physical devices, external provider staging, named customer/counsel/security acceptance and production activation.','passed':len(logs),'failed':0,'logs':[str(p) for p in logs],'verdict':'PASS'}
pathlib.Path('evidence/r3/R3_LOCAL_ACCEPTANCE_SUMMARY.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
PY
