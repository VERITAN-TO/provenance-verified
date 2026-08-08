# Independent Provider Contracts

All provider calls are authenticated server-to-server, idempotent where consequential, return `cache-control: no-store`, and fail closed on missing or malformed receipts.

| Provider | Required result | Failure effect |
|---|---|---|
| Scanner | clean scan receipt bound to object hash | evidence denied |
| Evidence eligibility | signed eligible receipt | evidence denied |
| Claim validator | signed pass receipt and claim-set digest | issuance denied |
| Conflict engine | signed clear receipt per reviewer and review round | review denied |
| CUSTOS | signed pass verdict over current review/claim digest | consequential write denied |
| Signer | ES256 signature, KMS receipt, active non-exportable key | issuance denied |
| Registry | publication receipt and revocation capability confirmation | credential not issued |
| Mark authority | signed authorization against active registry state | seal suppressed |
| Secret vault | KMS envelope ciphertext/plaintext operation with context | webhook create/delivery denied |

Provider source lives in `services/provider-boundaries`; deployable AWS infrastructure lives in `infra/terraform/provider-boundaries`.
