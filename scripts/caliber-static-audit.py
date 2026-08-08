#!/usr/bin/env python3
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
layout = (root / 'src/app/layout.tsx').read_text()
kernel = (root / 'src/operations/kernel.ts').read_text()
source = '\n'.join(p.read_text(errors='ignore') for p in (root / 'src').rglob('*') if p.is_file() and p.suffix in {'.ts', '.tsx', '.css', '.md'})
required = [
  'src/app/site.css',
  'src/app/loading.tsx',
  'src/app/error.tsx',
  'src/app/not-found.tsx',
  'src/app/sitemap.ts',
  'src/app/robots.ts',
  'src/ui/DocsIndex.tsx',
  'src/ui/SignInAccess.tsx',
  'src/ui/DeveloperWorkbench.tsx',
  'src/ui/SiteFooter.tsx',
  'src/app/api/v1/inquiries/route.ts',
]
report = {
  'missing_required_files': [p for p in required if not (root / p).exists()],
  'single_authoritative_css_import': "import './site.css'" in layout and 'phase2.css' not in layout and 'phase3.css' not in layout and 'phase4.css' not in layout,
  'global_footer_integrated': '<SiteFooter />' in layout,
  'manufactured_transfer_history_removed': 'completeTransferHistory: true' not in kernel,
  'manufactured_custody_history_removed': 'completeCustodyTransfers: true' not in kernel,
  'status_based_signature_removed': "signedAttestation: asset.status !== 'draft'" not in kernel,
  'outside_entity_term_count': source.lower().count('diamodia'),
  'test_mode_boundary_present': 'runtime not deployed' in source.lower() and 'does not create an account' in source.lower(),
}
report['pass'] = not report['missing_required_files'] and all(report[k] for k in ['single_authoritative_css_import','global_footer_integrated','manufactured_transfer_history_removed','manufactured_custody_history_removed','status_based_signature_removed','test_mode_boundary_present']) and report['outside_entity_term_count'] == 0
print(json.dumps(report, indent=2))
raise SystemExit(0 if report['pass'] else 1)
