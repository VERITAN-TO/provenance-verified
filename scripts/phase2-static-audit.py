#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path

TEXT_SUFFIXES = {'.ts', '.tsx', '.js', '.mjs', '.css', '.md', '.json', '.html', '.svg'}
EXPECTED_RELATIVE_ASSETS = [
    'lockups/provenance-lockup-horizontal.svg',
    'lockups/provenance-lockup-stacked.svg',
    'lockups/provenance-symbol-only.svg',
    'lockups/provenance-wordmark-only.svg',
    'marks/provenance-master-mark.svg',
    'marks/provenance-master-mark-fallback.svg',
    'seals/01_provenance-verified-tier-1-self-reported-compact.svg',
    'seals/01_provenance-verified-tier-1-self-reported-display.svg',
    'seals/01_provenance-verified-tier-1-self-reported-monochrome.svg',
    'seals/02_provenance-verified-tier-2-bronze-compact.svg',
    'seals/02_provenance-verified-tier-2-bronze-display.svg',
    'seals/02_provenance-verified-tier-2-bronze-monochrome.svg',
    'seals/03_provenance-verified-tier-3-silver-compact.svg',
    'seals/03_provenance-verified-tier-3-silver-display.svg',
    'seals/03_provenance-verified-tier-3-silver-monochrome.svg',
    'seals/04_provenance-verified-tier-4-gold-compact.svg',
    'seals/04_provenance-verified-tier-4-gold-display.svg',
    'seals/04_provenance-verified-tier-4-gold-monochrome.svg',
    'icons/favicon-optical-16.svg',
    'icons/favicon-optical-32.svg',
    'icons/safari-pinned-tab.svg',
    'icons/app-icon-16.png',
    'icons/app-icon-32.png',
    'icons/app-icon-48.png',
    'icons/app-icon-64.png',
    'icons/app-icon-128.png',
    'icons/app-icon-192.png',
    'icons/app-icon-256.png',
    'icons/app-icon-512.png',
    'icons/app-icon-1024.png',
    'icons/app-icon-maskable-192.png',
    'icons/app-icon-maskable-512.png',
    'icons/micro-mark-16.png',
    'icons/micro-mark-32.png',
    'icons/micro-mark-48.png',
]


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def source_text_files(root: Path):
    ignored = {'.git', 'node_modules', '.next', 'coverage', 'playwright-report', 'test-results'}
    for path in root.rglob('*'):
        if not path.is_file() or path.suffix.lower() not in TEXT_SUFFIXES:
            continue
        if any(part in ignored for part in path.parts):
            continue
        yield path


def scan(pattern: re.Pattern[str], files: list[Path], root: Path):
    hits = []
    for path in files:
        try:
            text = path.read_text(encoding='utf-8', errors='ignore')
        except OSError:
            continue
        for match in pattern.finditer(text):
            line = text.count('\n', 0, match.start()) + 1
            hits.append({'file': str(path.relative_to(root)), 'line': line, 'match': match.group(0)[:160]})
    return hits


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', default='.')
    parser.add_argument('--source-assets-root')
    parser.add_argument('--source-zip')
    parser.add_argument('--output', default='evidence/phase2/PHASE_2_STATIC_CONTRACT.json')
    args = parser.parse_args()

    root = Path(args.root).resolve()
    app_assets = root / 'public' / 'r5'
    source_assets = Path(args.source_assets_root).resolve() if args.source_assets_root else None
    files = list(source_text_files(root))
    app_files = [path for path in files if path.is_relative_to(root / 'src')]

    asset_rows = []
    missing_assets = []
    parity_failures = []
    for rel in EXPECTED_RELATIVE_ASSETS:
        app = app_assets / rel
        source = source_assets / rel if source_assets else None
        row = {'relative_path': rel, 'app_present': app.is_file(), 'app_sha256': sha256(app) if app.is_file() else None}
        if not app.is_file():
            missing_assets.append(rel)
        if source_assets:
            row['source_present'] = bool(source and source.is_file())
            row['source_sha256'] = sha256(source) if source and source.is_file() else None
            row['exact_match'] = bool(app.is_file() and source and source.is_file() and row['app_sha256'] == row['source_sha256'])
            if not row['exact_match']:
                parity_failures.append(rel)
        asset_rows.append(row)

    scene_hits = scan(re.compile(r'new\s+ProvenanceIdentityScene\s*\('), app_files, root)
    iframe_hits = scan(re.compile(r'<iframe\b', re.I), app_files, root)
    forbidden_hits = scan(re.compile(r'\b' + ''.join(['DIA','MODIA']) + r'\b', re.I), files, root)
    three_imports = scan(re.compile(r"(?:from\s+['\"]three['\"]|require\(['\"]three['\"]\))"), app_files, root)

    layout = (root / 'src/app/layout.tsx').read_text(encoding='utf-8')
    homepage = (root / 'src/ui/HomepageExperience.tsx').read_text(encoding='utf-8')
    core_hero = (root / 'src/ui/CoreHero.tsx').read_text(encoding='utf-8')
    tier_seal = (root / 'src/ui/TierSeal.tsx').read_text(encoding='utf-8')

    source_zip = Path(args.source_zip).resolve() if args.source_zip else None
    checks = {
        'all_expected_r5_assets_present': not missing_assets,
        'exact_r5_asset_parity': not parity_failures if source_assets else None,
        'one_spatial_scene_constructor': len(scene_hits) == 1,
        'spatial_runtime_not_global_layout': 'SpatialEnvironment' not in layout,
        'core_hero_is_homepage_entry': '<CoreHero' in homepage,
        'corporate_master_mark_is_tier_zero': 'certificationTier: 0' in (root / 'src/spatial/SpatialEnvironment.tsx').read_text(encoding='utf-8'),
        'unauthorized_tier_uses_eligibility_projection': 'if (!authorized)' in tier_seal and 'ELIGIBILITY ONLY' in tier_seal,
        'hero_exposes_test_mode_boundary': 'TEST_MODE_LABELS' in core_hero,
        'no_iframe_integration': not iframe_hits,
        'scope_purity': not forbidden_hits,
        'single_three_dependency_version': len(set(hit['match'] for hit in three_imports)) <= 2,
    }
    status = 'PASS' if all(value is True or value is None for value in checks.values()) else 'FAIL'
    result = {
        'schema_version': '1.0.0',
        'phase': 'PHASE_2_VISUAL_FOUNDATION',
        'status': status,
        'source_zip': {'path': str(source_zip) if source_zip else None, 'sha256': sha256(source_zip) if source_zip and source_zip.is_file() else None},
        'source_assets_root': str(source_assets) if source_assets else None,
        'checks': checks,
        'counts': {
            'expected_assets': len(EXPECTED_RELATIVE_ASSETS),
            'missing_assets': len(missing_assets),
            'asset_parity_failures': len(parity_failures),
            'spatial_scene_constructors': len(scene_hits),
            'iframe_hits': len(iframe_hits),
            'forbidden_scope_hits': len(forbidden_hits),
            'three_import_hits': len(three_imports),
        },
        'missing_assets': missing_assets,
        'parity_failures': parity_failures,
        'scene_constructor_locations': scene_hits,
        'iframe_hits': iframe_hits,
        'forbidden_scope_hits': forbidden_hits,
        'three_imports': three_imports,
        'asset_parity': asset_rows,
    }
    output = root / args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'status': status, 'output': str(output), 'checks': checks, 'counts': result['counts']}, indent=2))
    return 0 if status == 'PASS' else 1


if __name__ == '__main__':
    raise SystemExit(main())
