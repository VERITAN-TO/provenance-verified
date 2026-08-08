#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; OUT="${1:-$ROOT/.r3-return-staging}"; rm -rf "$OUT"; mkdir -p "$OUT"/{SOURCE,BUILD,INFRASTRUCTURE,DATABASE,SERVICES,API,MCP,CUSTOS,REGISTRY,SIGNING,EVIDENCE_CUSTODY,MARK_AUTHORITY,TESTS,EVIDENCE,REVIEW,LEDGERS,MANIFESTS,DEPLOYMENT,ROLLBACK,LICENSES}
rsync -a --exclude='.git' --exclude='node_modules' --exclude='.next' --exclude='evidence' --exclude='review' --exclude='.r3-return-staging' "$ROOT/" "$OUT/SOURCE/"
cp -a "$ROOT/infra/." "$OUT/INFRASTRUCTURE/"; cp -a "$ROOT/database/." "$OUT/DATABASE/"; cp -a "$ROOT/supabase/migrations" "$OUT/DATABASE/"; cp -a "$ROOT/services/." "$OUT/SERVICES/"; cp -a "$ROOT/docs/." "$OUT/API/"; cp -a "$ROOT/sdk/." "$OUT/API/SDK/"; cp -a "$ROOT/services/provider-boundaries/custos/." "$OUT/CUSTOS/"; cp -a "$ROOT/services/provider-boundaries/registry/." "$OUT/REGISTRY/"; cp -a "$ROOT/services/provider-boundaries/signer/." "$OUT/SIGNING/"; cp -a "$ROOT/services/provider-boundaries/evidence-custody/." "$OUT/EVIDENCE_CUSTODY/"; cp -a "$ROOT/services/provider-boundaries/mark-authority/." "$OUT/MARK_AUTHORITY/"; cp -a "$ROOT/tests/." "$OUT/TESTS/"; cp -a "$ROOT/evidence/." "$OUT/EVIDENCE/"; cp -a "$ROOT/review/." "$OUT/REVIEW/"; cp -a "$ROOT/ledgers/." "$OUT/LEDGERS/"; cp -a "$ROOT/DEPLOYMENT/." "$OUT/DEPLOYMENT/"; cp -a "$ROOT/ROLLBACK/." "$OUT/ROLLBACK/"; cp -a "$ROOT/LICENSES/." "$OUT/LICENSES/"; git -C "$ROOT" bundle create "$OUT/MANIFESTS/R3_SOURCE_HISTORY.bundle" --all
if [ -d "$ROOT/.next" ]; then cp -a "$ROOT/.next" "$OUT/BUILD/.next"; fi
find "$OUT" -type f -print0 | sort -z | xargs -0 sha256sum > "$OUT/MANIFESTS/SHA256SUMS.txt"
find "$OUT" -type f | sed "s#^$OUT/##" | sort > "$OUT/MANIFESTS/FILE_MANIFEST.txt"
echo "$OUT"
