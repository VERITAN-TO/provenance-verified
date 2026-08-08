# Browser Command Security Policy

Cookie-authenticated mutations are accepted only when Fetch Metadata does not
identify a cross-site request and the `Origin` equals the application origin.
Requests with an authority access or refresh cookie but no Origin are denied.
Machine clients authenticate with scoped bearer credentials and do not depend on
browser cookies. `SameSite=Lax`, `HttpOnly`, and Secure cookies in Pilot and
Production provide defense in depth; authorization remains server-side.
