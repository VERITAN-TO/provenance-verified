import type { Metadata } from 'next'; import Link from 'next/link'; import { PolicyDocument } from '@/ui/RouteShell';
export const metadata: Metadata = { title: 'Security' };
export default function Page() { return <PolicyDocument title="Security architecture" summary="Controls demonstrated in this build, production boundaries, and claims that are intentionally not made." sections={[
  { heading: 'Application controls', body: 'The build sets CSP, X-Content-Type-Options, Referrer-Policy, Permissions-Policy, and X-Frame-Options headers. Input contracts are validated with schemas. Public IDs use a constrained format.' },
  { heading: 'Credential integrity', body: 'Deterministic credentials include an integrity hash, signature algorithm, key ID, signature value, version, issuer identity, lifecycle state, and signed event chain. Test signatures are explicitly non-authoritative.' },
  { heading: 'Secret boundary', body: 'No production secrets or live credentials are included. Test examples use masked keys. Production integrations require managed secret storage, key rotation, access logging, least privilege, and authorized issuer controls.' },
  { heading: 'Threat boundary', body: 'The client is not trusted to calculate certification truth. Tier and lifecycle results originate in the deterministic kernel and canonical state. Renderers are projections only.' },
  { heading: 'Compliance language', body: 'This build does not claim certification against an external compliance standard. Public statements describe implemented controls and explicit limitations only.' }
]} lead={<p><Link href="/security/report">Submit an encrypted vulnerability disclosure</Link></p>} />; }
