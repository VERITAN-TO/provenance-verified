#!/usr/bin/env python3
from pathlib import Path
import json, re, sys
root = Path(__file__).resolve().parents[1]
required = [
  'src/app/app/page.tsx','src/app/app/lots/page.tsx','src/app/app/intake/page.tsx','src/app/app/batches/page.tsx',
  'src/app/app/batches/[batchId]/page.tsx','src/app/app/review/page.tsx',
  'src/app/app/search/page.tsx','src/app/app/labels/page.tsx','src/app/app/exceptions/page.tsx','src/app/app/audit/page.tsx',
  'src/operations/types.ts','src/operations/kernel.ts','src/operations/permissions.ts',
  'src/operations/repository.ts','src/operations/offline/indexedDb.ts',
  'public/manifest.webmanifest','public/sw.js','database/001_phase4_operations.sql',
  'docs/PHASE_4_OPERATIONAL_SYSTEM_CONTRACT.md','docs/PHASE_4_PRODUCTION_BOUNDARY.md'
]
missing = [p for p in required if not (root/p).exists()]
scan_roots = [root/'src', root/'docs', root/'database', root/'public', root/'tests']
files = [p for base in scan_roots for p in base.rglob('*') if p.is_file() and p.suffix.lower() in {'.ts','.tsx','.md','.css','.json','.sql','.js'}]
all_text = '\n'.join(p.read_text(errors='ignore') for p in files)
outside_entity = ''.join(['DIA','MODIA'])
prohibited = re.findall(r'(?i)' + outside_entity, all_text)
checks = {
  'missing_required_files': missing,
  'prohibited_external_entity_occurrences': len(prohibited),
  'operations_store_count': len(list(root.glob('src/operations/useOperationsStore.ts'))),
  'spatial_environment_count': len(list((root/'src').rglob('SpatialEnvironment.tsx'))),
  'iframe_occurrences': len(re.findall(r'<iframe', all_text, flags=re.I)),
  'tenant_scope_sql_policies': len(re.findall(r'create policy tenant_scope_', (root/'database/001_phase4_operations.sql').read_text())),
  'operational_api_route_count': len(list((root/'src/app/api/v1/operations').rglob('route.ts'))),
  'operational_page_count': len(list((root/'src/app/app').rglob('page.tsx'))),
  'pwa_manifest_valid': bool(json.loads((root/'public/manifest.webmanifest').read_text()).get('start_url') == '/app'),
}
passed = not missing and not prohibited and checks['operations_store_count'] == 1 and checks['spatial_environment_count'] == 1 and checks['iframe_occurrences'] == 0 and checks['tenant_scope_sql_policies'] >= 8 and checks['operational_api_route_count'] >= 14 and checks['operational_page_count'] >= 10 and checks['pwa_manifest_valid']
checks['status'] = 'PASS' if passed else 'FAIL'
out = root/'evidence/phase4/PHASE_4_STATIC_CONTRACT.json'
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(checks, indent=2) + '\n')
print(json.dumps(checks, indent=2))
sys.exit(0 if passed else 1)
