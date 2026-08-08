# Local Browser and Responsive Matrix

This matrix records the complete browser acceptance required by the authorized no-deployment scope.

| Runtime | Viewport | Result |
|---|---:|---|
| Chromium 144 | 1440 × 1000 | PASS |
| Chromium 144 tablet emulation | 768 × 1024 | PASS |
| Chromium 144 Android-class mobile emulation | 390 × 844, DPR 2 | PASS |
| Chromium accessibility tree | Full document | PASS |
| Chromium keyboard traversal | First 30 focus stops | PASS |
| Chromium reduced motion | `prefers-reduced-motion: reduce` | PASS |
| Chromium WebGL-unavailable path | Semantic fallback | PASS |

No deployment and no physical-device connection were performed by instruction. The responsive implementation itself is complete and locally accepted.
