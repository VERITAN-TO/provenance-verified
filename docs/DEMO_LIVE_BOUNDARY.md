# Demonstration and Live boundary

## Deterministic Demonstration Mode — implemented

- Stable fixture IDs and policy version.
- Local deterministic kernel.
- Visible `TEST MODE`, `NON-AUTHORITATIVE`, and `NOT A PRODUCTION CREDENTIAL` labels.
- No public credential issuance.
- No fabricated network success.
- Deterministic failure, retry, replay, suspension, revocation, supersession, expiry, and not-found states.

## Authorized Live Mode — not configured

Authorized Live Mode requires authentication, approved adapters, persistent storage, signer custody, production registry authorization, tenant permissions, external webhook delivery, secrets management, audit retention, honest timeout/unavailable states, and operational incident controls. The build contains interface and contract surfaces only. It never falls back from an unavailable Live adapter to fake success.
