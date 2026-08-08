#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p evidence/corrective
rm -rf .local-build

tsc -p tsconfig.audit.json --pretty false > evidence/corrective/typecheck.txt 2>&1
tsc -p tsconfig.local.json --pretty false > evidence/corrective/local-emit.txt 2>&1
node scripts/local-acceptance.cjs > evidence/corrective/local-acceptance.log
python3 scripts/provider-contract-audit.py > evidence/corrective/provider-contract-audit.txt
node scripts/migration-contract-audit.mjs > evidence/corrective/migration-contract.log
node --no-warnings scripts/recovery-simulation.mjs > evidence/corrective/recovery-simulation.log
node scripts/source-quality-audit.mjs > evidence/corrective/source-quality.log
node scripts/verify-production-authority.mjs > evidence/corrective/verify-production-authority.txt
python3 scripts/phase3-static-audit.py > evidence/corrective/phase3-static-audit.txt
python3 scripts/phase4-static-audit.py > evidence/corrective/phase4-static-audit.txt
python3 scripts/caliber-static-audit.py > evidence/corrective/caliber-static-audit.txt
node scripts/link-audit.mjs > evidence/corrective/link-audit.txt
node scripts/continuity-lint.mjs > evidence/corrective/continuity-lint.txt
python3 -m py_compile services/provider-boundaries/*/handler.py
python3 scripts/standalone-flow-audit.py > evidence/corrective/standalone-flow-audit.txt
python3 scripts/capture-visual-baseline.py > evidence/corrective/visual-capture.txt
python3 scripts/visual-regression-audit.py > evidence/corrective/visual-regression.txt
scripts/run-cdp-browser-audit.sh > evidence/corrective/cdp-browser-audit.txt
node scripts/validate-json.mjs > evidence/corrective/validate-json.txt
node scripts/no-deployment-summary.mjs
