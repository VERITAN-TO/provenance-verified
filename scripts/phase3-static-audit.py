#!/usr/bin/env python3
from __future__ import annotations
import hashlib, json, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
required = [
    'src/ui/phase3/TierEducationChamber.tsx',
    'src/ui/phase3/VerificationTransaction.tsx',
    'src/ui/phase3/EvidenceClaimsWorkbench.tsx',
    'src/ui/phase3/CredentialRegistryProjection.tsx',
    'src/ui/phase3/LifecycleContinuity.tsx',
    'src/ui/phase3/DeveloperContractChapter.tsx',
    'src/ui/phase3/AuthorityBoundary.tsx',
    'src/ui/phase3/Shared.tsx',
    'src/app/phase3.css',
    'docs/PHASE_3_PUBLIC_PROOF_SYSTEM_CONTRACT.md',
    'docs/PHASE_3_DONOR_AUTHORITY.json',
    'tests/unit/phase3-public-system.test.tsx',
]
missing = [p for p in required if not (ROOT / p).is_file()]
source_files = list((ROOT / 'src').rglob('*'))
text_files = [p for p in source_files if p.is_file() and p.suffix in {'.ts','.tsx','.css'}]
combined = '\n'.join(p.read_text(encoding='utf-8', errors='ignore') for p in text_files)
phase3_files = sorted((ROOT / 'src/ui/phase3').glob('*.tsx'))
checks = {
    'missing_required_files': missing,
    'phase3_component_count': len(phase3_files),
    'iframe_count': len(re.findall(r'<iframe\b', combined, flags=re.I)),
    'spatial_scene_instance_entrypoints': combined.count('new ProvenanceIdentityScene'),
    'spatial_renderer_implementation_count': len(re.findall(r'new\s+THREE\.WebGLRenderer', combined)),
    'zustand_store_definitions': combined.count('create<ProvenanceState>'),
    'mcp_not_deployed_language': 'RUNTIME NOT DEPLOYED' in combined,
    'educational_not_issuance_language': ('EDUCATION ONLY ' + chr(183) + ' NOT ISSUANCE') in combined,
    'outside_entity_term_count': len(re.findall(r'\b' + ''.join(['DIA','MODIA']) + r'\b', combined, flags=re.I)),
}
checks['pass'] = (
    not missing
    and checks['phase3_component_count'] >= 8
    and checks['iframe_count'] == 0
    and checks['spatial_renderer_implementation_count'] == 1
    and checks['spatial_scene_instance_entrypoints'] == 2
    and checks['zustand_store_definitions'] == 1
    and checks['mcp_not_deployed_language']
    and checks['educational_not_issuance_language']
    and checks['outside_entity_term_count'] == 0
)
checks['files'] = {rel: hashlib.sha256((ROOT / rel).read_bytes()).hexdigest() for rel in required if (ROOT / rel).is_file()}
out = ROOT / 'evidence/phase3/PHASE_3_STATIC_AUDIT.json'
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(checks, indent=2) + '\n', encoding='utf-8')
print(json.dumps(checks, indent=2))
sys.exit(0 if checks['pass'] else 1)
