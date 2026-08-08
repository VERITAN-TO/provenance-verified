# Phase 2 visual foundation contract

## Authority

- Application spine: Phase 1 Victory R1 authority slice.
- Corporate identity authority: `PROVENANCE VERIFIED™_REAL_LOGO_R5(7).zip`.
- Corporate identity source SHA-256: `8b469e20316306028378f4db140755fcf7b1487f3133b60758941a909b2cdee0`.
- Hero composition authority: Exact CORE010 candidate.
- Exact CORE010 source SHA-256: `e11358cfa189a428f97b7903bb29937709d5d8d3eecd81d4b98ea18f1679a83e`.
- Exact CORE010 source location in the Phase 0 estate: `P-WEBSITE-002/PROVENANCE VERIFIED™_CURRENT_BASE_EXACT_CORE010_HERO_PACKAGE/PROVENANCE VERIFIED™_CURRENT_BASE_EXACT_CORE010_HERO_FINAL.html`.

## Authorized Phase 2 boundary

Phase 2 establishes the visual identity and first-viewport runtime only:

1. exact R5 corporate lockup and corporate master mark;
2. exact controlled Tier 1 through Tier 4 certification-seal assets;
3. strict separation between the corporate master mark and PV certification seals;
4. one shared Three.js dependency and one hero renderer lifecycle;
5. canonical Phase 1 authority and lifecycle state mapped into the R5 spatial object;
6. CORE010 first-viewport hierarchy rebuilt as maintained React components;
7. responsive desktop, tablet, and mobile composition rules;
8. reduced-motion and no-WebGL fallback behavior;
9. visible Test Mode and non-authoritative boundaries.

Phase 2 does not authorize replacement of later homepage chapters, field PWA implementation, production persistence, production signing, OAuth, live MCP, or production credential issuance.

## Corporate identity law

- The corporate master mark always represents PROVENANCE VERIFIED™.
- The corporate master mark is rendered with `certificationTier: 0`.
- The corporate master mark must not change into Bronze, Silver, Gold, or any other certification tier.
- Tier-specific seal assets may appear only when the canonical credential is issued and its mark authorization is `authorized`.
- An evidence-eligible but unissued case displays a neutral eligibility projection, never a certification seal.
- An issued case with pending or denied mark authorization displays a neutral eligibility projection, never a certification seal.

## Shared spatial runtime law

- `SpatialEnvironment` is mounted only inside the first viewport.
- The root layout does not mount a second global renderer.
- Exactly one `ProvenanceIdentityScene` constructor exists in application source.
- The runtime consumes the existing Phase 1 Zustand store; no competing visual-state store is permitted.
- Renderer state is derived from canonical stage, run, lifecycle, authorization, and blocker state.
- Renderer cleanup must dispose of listeners, scene resources, and the canvas lifecycle.
- WebGL loss, no-WebGL mode, and initialization failure must resolve to the static R5 corporate mark.
- Reduced motion must be propagated to the scene and CSS motion system.

## Canonical state mapping

| Canonical condition | R5 visual state |
|---|---|
| lifecycle revoked | `revoked` |
| verification runtime error | `failed` |
| reviewer conflict or CUSTOS blocker | `exception` |
| approval stage reached without issuer authorization | `pending` |
| stage 1 | `observe` |
| stage 2 | `attest` |
| stage 3 | `prove` |
| stage 4 | `policy` |
| stage 5 | `approve` |
| stage 6 | `verify` |
| stage 7 | `secure` |

## First-viewport composition

The desktop first viewport uses three distinct responsibilities:

1. **Authority statement** — category-defining headline, direct product description, primary action, verification action, documentation action, and concise capability line.
2. **Live proof object** — R5 corporate master mark, state label, seven-stage rail, pause control, and physical-asset-to-machine-response sequence.
3. **Operational proof** — deterministic fixture, eligible versus issued distinction, controlled mark projection, credential or blocker status, and machine JSON.

At narrower desktop widths, the operational proof column is removed before the product statement or proof object is compromised. On mobile, the authority statement remains first, actions become full-width, the object remains legible, and the dense stage rail is removed.

## Truth and claim controls

- The first viewport must visibly identify Test Mode.
- Fixture signatures, credentials, registry records, and state transitions must not be described as production authority.
- `API + MCP contract` describes the contract surface; it does not claim a deployed production MCP runtime.
- The hero may present the deterministic verification flow but may not imply that a phone camera performs laboratory authentication.

## Asset contract

The application carries exact copied R5 bytes under `public/r5/`. Asset parity is recorded in `evidence/phase2/PHASE_2_STATIC_CONTRACT.json`.

The copied set contains:

- four corporate lockup/wordmark/symbol variants;
- corporate master mark and fallback;
- compact, display, and monochrome certification seals for all four tiers;
- favicon, application-icon, maskable-icon, and micro-mark assets.

## Acceptance gates

Phase 2 code acceptance requires:

- exact R5 asset hash parity;
- one spatial scene constructor;
- no global spatial mount;
- no iframe donor integration;
- no outside-entity references;
- corporate mark and certification-seal separation tests;
- authorized/unauthorized seal projection tests;
- authority, integration, security, typecheck, lint, route, continuity, and production-build passes;
- browser rendering, responsive, accessibility, reduced-motion, no-WebGL, WebGL recovery, and interaction acceptance in an unblocked browser environment.

The final browser gate remains separate from code acceptance. A browser-policy failure must be reported as blocked, not converted into a visual pass.
