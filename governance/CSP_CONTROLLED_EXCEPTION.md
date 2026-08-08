# CSP Controlled Exception — R8.1 Render-Protected Style Attributes

Production script execution is nonce-bound and does not permit `unsafe-eval` or
`unsafe-inline`. The application retains `style-src 'unsafe-inline'` only for the
three render-protected dynamic geometry attributes used by the tier ring,
interaction pulse, and live code progress components. The exception carries no
script execution authority, is covered by visual regression, and must be removed
if those geometry values are migrated to predeclared CSS classes or a CSP Level 3
hash-compatible attribute strategy.

Sandbox alone permits `unsafe-eval` because the local Three.js/Turbopack reference
runtime requires it. Pilot and production do not.
