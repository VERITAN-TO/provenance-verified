#!/usr/bin/env python3
import json
from pathlib import Path
from jsonschema import Draft202012Validator, RefResolver

root = Path(__file__).resolve().parents[1]
schema_dir = root / 'schemas'
fixture_dir = root / 'fixtures' / 'authority'

schemas = {}
for path in schema_dir.glob('*.json'):
    data = json.loads(path.read_text())
    schemas[path.name] = data
    if '$id' in data:
        schemas[data['$id']] = data

canonical = schemas['canonical-state.schema.json']
resolver = RefResolver.from_schema(canonical, store=schemas)
validator = Draft202012Validator(canonical, resolver=resolver)

failures = []
for path in sorted(fixture_dir.glob('*.json')):
    instance = json.loads(path.read_text())
    errors = sorted(validator.iter_errors(instance), key=lambda error: list(error.absolute_path))
    if errors:
        failures.append((path, errors))

if failures:
    for path, errors in failures:
        print(f'FAIL {path.relative_to(root)}')
        for error in errors:
            location = '/'.join(str(part) for part in error.absolute_path) or '<root>'
            print(f'  {location}: {error.message}')
    raise SystemExit(1)

print(f'PASS: {len(list(fixture_dir.glob("*.json")))} authority fixtures validate against canonical-state.schema.json')
