# Source fingerprint protocol

The source fingerprint is the SHA-256 of a stable, sorted stream of per-file SHA-256 records for the editable implementation surface:

- `src/`
- `public/`
- `fixtures/`
- `schemas/`
- `scripts/`
- `tests/`
- `package.json`
- `package-lock.json`
- `next.config.ts`
- `tsconfig.json`
- `eslint.config.mjs`
- `vitest.config.ts`
- `playwright.config.ts`
- `playwright.system.config.ts`
- `next-env.d.ts`

Generated build output, evidence, documentation, coverage, dependencies, and checksum manifests are excluded to avoid circularity.
