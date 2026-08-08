import { useEffect, useState } from 'react';
import Link from 'next/link';
import { usePathname } from './next-navigation';
import { SiteHeader } from '@/ui/SiteHeader';
import { SiteFooter } from '@/ui/SiteFooter';
import { AccessibleStatus } from '@/ui/AccessibleStatus';
import { LivingInterface } from '@/ui/LivingInterface';
import { CaliberHomepage } from '@/ui/CaliberHomepage';
import { VerifyRoute } from '@/ui/VerifyRoute';
import { RegistryRoute } from '@/ui/RegistryRoute';
import { PublicRecord } from '@/ui/PublicRecord';
import { PolicyDocument, RouteShell } from '@/ui/RouteShell';
import { TierSeal } from '@/ui/TierSeal';
import { DeveloperWorkbench } from '@/ui/DeveloperWorkbench';
import { ContactForm } from '@/ui/ContactForm';
import { SignInAccess } from '@/ui/SignInAccess';
import { DocsIndex } from '@/ui/DocsIndex';
import { docsContent, legalContent } from '@/ui/content';
import { OperationsShell } from '@/ui/operations/OperationsShell';
import { OperationsDashboard } from '@/ui/operations/OperationsDashboard';
import { LotWorkspace } from '@/ui/operations/LotWorkspace';
import { BatchIntakeConsole } from '@/ui/operations/BatchIntakeConsole';
import { BatchList } from '@/ui/operations/BatchList';
import { BatchDetail } from '@/ui/operations/BatchDetail';
import { SearchWorkspace } from '@/ui/operations/SearchWorkspace';
import { ReviewWorkspace } from '@/ui/operations/ReviewWorkspace';
import { LabelWorkspace } from '@/ui/operations/LabelWorkspace';
import { ExceptionsQueue } from '@/ui/operations/ExceptionsQueue';
import { AuditLog } from '@/ui/operations/AuditLog';
import { resetOperationalRepositoryForTests } from './runtime';
import { useOperationsStore } from '@/operations/useOperationsStore';
import { safeStorageRemove } from '@/operations/browserStorage';

function Developers() {
  return <RouteShell eyebrow="DEVELOPER INTEGRATION" title="One contract from evidence intake to public consequence." lede="Consume verification, registry, lifecycle, event, webhook, SDK, and MCP contracts without recreating issuer authority in client code."><DeveloperWorkbench /></RouteShell>;
}
function Docs() {
  return <RouteShell eyebrow="DEVELOPER DOCUMENTATION" title="Build against the same canonical proof transaction." lede="Documentation for deterministic verification, registry resolution, signed events, webhooks, SDKs, MCP contracts, lifecycle control, and Test Mode boundaries."><DocsIndex /></RouteShell>;
}
function Trust() {
  return <RouteShell eyebrow="TRUST CENTER" title="Issuer, policy, keys, status, and lifecycle boundaries." lede="Trust is not a decorative badge. It is a public set of authority, evidence, state, and recovery controls."><div className="trust-route-grid"><article><small>ISSUER</small><h2>VERITAN, INC.</h2><p>Issuer identity is present in every credential and public registry projection.</p></article><article><small>PLATFORM</small><h2>PROVENANCE VERIFIED™</h2><p>Records are issued, resolved, and managed through one canonical registry.</p></article><article><small>KEY POLICY</small><h2>Versioned signatures</h2><p>Credentials and events expose algorithm, key ID, signature value, and integrity hash.</p></article><article><small>LIFECYCLE</small><h2>Resolvable history</h2><p>Suspended, superseded, revoked, and expired records remain explicitly resolvable.</p></article></div><div className="trust-route-links"><Link href="/security">Security architecture</Link><Link href="/legal/certification-policy">Certification policy</Link><Link href="/legal/evidence-policy">Evidence policy</Link><Link href="/legal/revocation-policy">Lifecycle policy</Link><Link href="/status">Service status</Link><Link href="/brand/trademark">Trademark and identity</Link></div></RouteShell>;
}
function Company() {
  const items = [['01','Evidence before assertion','No interface, model, or operator can create source independence or turn unknown evidence into certainty.'],['02','Scope before badge','Every public result preserves claim-level status instead of hiding uncertainty behind one checkmark.'],['03','Authority before issuance','Credentials identify issuer, policy version, signature key, lifecycle, and registry record.'],['04','Control after issuance','Suspension, supersession, revocation, expiration, and replay remain observable.']];
  return <RouteShell eyebrow="COMPANY" title="PROVENANCE VERIFIED™ is operated by VERITAN, INC." lede="The platform converts evidence into scoped, signed, lifecycle-aware credentials that can be resolved by people and machines."><div className="company-grid">{items.map(([index,title,body]) => <article key={index}><span>{index}</span><h2>{title}</h2><p>{body}</p></article>)}</div></RouteShell>;
}
function Contact() {
  return <RouteShell eyebrow="CONTACT" title="Discuss evidence, registry, and integration requirements." lede="Use this surface for product, pilot, security, documentation, or issuer-policy inquiries. The packaged form operates in Test Mode."><div className="contact-route-layout"><div><h2>Route your inquiry</h2><p>Include the asset class, evidence sources, required public claims, registry consumers, and lifecycle obligations.</p><dl><div><dt>Product</dt><dd>Verification, registry, credentials, lifecycle</dd></div><div><dt>Developers</dt><dd>API, SDK, MCP, events, webhooks</dd></div><div><dt>Authority</dt><dd>Issuer, evidence, certification, revocation</dd></div><div><dt>Security</dt><dd>Keys, access, headers, boundaries</dd></div></dl></div><ContactForm /></div></RouteShell>;
}
function Access() {
  return <RouteShell eyebrow="AUTHORIZED ACCESS" title="Move from deterministic Test Mode to an authorized pilot." lede="Pilot scope is defined by evidence source, asset class, issuer authority, registry requirements, lifecycle controls, and security boundaries."><div className="access-route-layout"><div><h2>Pilot boundary</h2><ul className="feature-list"><li>Authorized organization and operator identities</li><li>Approved evidence and source qualification rules</li><li>Versioned certification policy and issuer authority</li><li>Managed keys and production credential signing</li><li>Registry publication and lifecycle responsibilities</li><li>Event, webhook, retention, and incident requirements</li></ul><p>No pricing or availability claim is made in this build.</p></div><ContactForm mode="access" /></div></RouteShell>;
}
function SignIn() {
  return <RouteShell eyebrow="OPERATOR ACCESS / TEST MODE" title="Enter the authenticated website through an explicit authority context." lede="Select a deterministic organization role to inspect permissions, intake, evidence, review, issuance, registry publication, labels, exceptions, and audit behavior."><SignInAccess /></RouteShell>;
}
function Status() {
  const services = ['Certification kernel','Canonical state projections','Public registry fixtures','Signed event fixtures','Webhook retry/replay fixture','WebGL fallback','Documentation routes'];
  return <RouteShell eyebrow="SERVICE STATUS / TEST MODE" title="Deterministic demonstration services are available." lede="This surface reports packaged demonstration components and makes no live production uptime claim."><div className="status-panel"><div className="status-summary"><span className="status-dot complete" /><div><strong>All packaged test components available</strong><p>Canonical Test Mode runtime</p></div></div>{services.map((item) => <div className="status-row" key={item}><span>{item}</span><strong>Available</strong></div>)}</div></RouteShell>;
}
function Changelog() {
  const entries = [['2026-07-21','Living interface R7','Tighter editorial rhythm, auto-sequenced control receipts, auto-cycling developer code, and real R5 master-mark and seal projections.'],['2026-07-21','Living interface R6','Credibility controls, scroll-executed code, soft light section transitions, complete standalone route coverage, and universal interaction telemetry.'],['2026-07-20','Unified four-layer R5','One canonical frontend, signed Test Mode sessions, lifecycle and correction workflows, WebGL and static fallback.']];
  return <RouteShell eyebrow="CHANGELOG" title="Versioned product and authority changes." lede="Every entry describes the public contract that changed."><div className="changelog-list">{entries.map(([date,title,body]) => <article key={date+title}><time>{date}</time><div><h2>{title}</h2><p>{body}</p></div></article>)}</div></RouteShell>;
}
function Trademark() {
  return <PolicyDocument title="Trademark and identity" summary="Role separation, approved material language, and prohibited uses for the PROVENANCE VERIFIED™ corporate identity and Provenance Verified™ certification seals." sections={[{heading:'Corporate master mark',body:'The corporate mark identifies the platform and never changes into a certification-tier metal.'},{heading:'Certification-tier seals',body:'Tier material and ring count are driven only by the certification result and separate mark authorization.'},{heading:'Prohibited use',body:'Do not present fixture seals as production credentials, recolor the corporate mark by tier, or imply unsupported authority.'}]} />;
}
function NotFound({ path }: { path: string }) {
  return <RouteShell eyebrow="ROUTE CONTROL" title="Review route not found." lede={`The standalone review runtime has no maintained projection for ${path}.`}><div className="empty-state"><p>Use the platform navigation to return to a maintained route.</p><Link href="/" className="pv2-button pv2-button-primary">Return home</Link></div></RouteShell>;
}
function OperationsRoute({ path }: { path: string }) {
  if (path === '/app') return <OperationsShell eyebrow="PROVENANCE OPERATIONS" title="Jeweler command center"><OperationsDashboard /></OperationsShell>;
  if (path === '/app/lots') return <OperationsShell eyebrow="INVENTORY RECEIVING" title="Lots and parcels"><LotWorkspace /></OperationsShell>;
  if (path === '/app/intake') return <OperationsShell eyebrow="FIELD PWA" title="Gemstone intake"><BatchIntakeConsole /></OperationsShell>;
  if (path === '/app/batches') return <OperationsShell eyebrow="INVENTORY OPERATIONS" title="Batches"><BatchList /></OperationsShell>;
  const batch = path.match(/^\/app\/batches\/([^/]+)$/);
  if (batch) return <OperationsShell eyebrow="BATCH CONTROL" title="Batch record"><BatchDetail batchId={decodeURIComponent(batch[1])} /></OperationsShell>;
  if (path === '/app/search') return <OperationsShell eyebrow="OPERATIONS INDEX" title="Search records"><SearchWorkspace /></OperationsShell>;
  if (path === '/app/review') return <OperationsShell eyebrow="AUTHORITY OPERATIONS" title="Evidence review"><ReviewWorkspace /></OperationsShell>;
  if (path === '/app/labels') return <OperationsShell eyebrow="CONTROLLED PROJECTION" title="Labels and QR"><LabelWorkspace /></OperationsShell>;
  if (path === '/app/exceptions') return <OperationsShell eyebrow="FAIL-CLOSED OPERATIONS" title="Exceptions"><ExceptionsQueue /></OperationsShell>;
  if (path === '/app/audit') return <OperationsShell eyebrow="IMMUTABLE ACTIVITY" title="Operational audit"><AuditLog /></OperationsShell>;
  return <NotFound path={path} />;
}
function ApiInspector() {
  const [open, setOpen] = useState(false);
  const [endpoint, setEndpoint] = useState('');
  const [body, setBody] = useState('');
  useEffect(() => {
    const inspect = async (event: Event) => {
      const href = (event as CustomEvent<string>).detail;
      setEndpoint(href); setOpen(true); setBody('Resolving canonical response…');
      try { const response = await fetch(href); setBody(JSON.stringify(await response.json(), null, 2)); }
      catch (error) { setBody(JSON.stringify({ error: error instanceof Error ? error.message : 'UNKNOWN_ERROR' }, null, 2)); }
    };
    window.addEventListener('pv:api-inspect', inspect);
    return () => window.removeEventListener('pv:api-inspect', inspect);
  }, []);
  if (!open) return null;
  return <div className="standalone-api-scrim" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) setOpen(false); }}><section className="standalone-api-modal" role="dialog" aria-modal="true" aria-labelledby="api-inspector-title"><header><div><span>CANONICAL API RESPONSE</span><strong id="api-inspector-title">{endpoint}</strong></div><button type="button" onClick={() => setOpen(false)}>Close</button></header><pre tabIndex={0}>{body}</pre></section></div>;
}
function StandaloneControl() {
  const hydrate = useOperationsStore((state) => state.hydrateSession);
  const reset = () => { resetOperationalRepositoryForTests(); safeStorageRemove('pv-test-session-id'); void hydrate(); };
  return <div className="standalone-control" role="status"><span><i />UNIFIED R8.1 REVIEW RUNTIME</span><b>Same React components · route handlers · authority kernel</b><button type="button" onClick={reset}>Reset deterministic data</button></div>;
}
function PublicRoute({ path }: { path: string }) {
  if (path === '/') return <CaliberHomepage />;
  if (path === '/verify') return <VerifyRoute />;
  if (path === '/registry') return <RegistryRoute />;
  if (path.startsWith('/registry/')) return <PublicRecord publicId={decodeURIComponent(path.slice('/registry/'.length))} />;
  if (path === '/developers') return <Developers />;
  if (path === '/docs') return <Docs />;
  if (path.startsWith('/docs/')) {
    const slug = path.slice('/docs/'.length); const doc = docsContent[slug];
    return doc ? <PolicyDocument title={doc.title} summary={doc.lede} sections={doc.sections} /> : <NotFound path={path} />;
  }
  if (path.startsWith('/legal/')) {
    const slug = path.slice('/legal/'.length); const doc = legalContent[slug];
    return doc ? <PolicyDocument title={doc.title} summary={doc.lede} sections={doc.sections} /> : <NotFound path={path} />;
  }
  if (path === '/trust') return <Trust />;
  if (path === '/security') return <PolicyDocument title="Security architecture" summary="Implemented controls, production boundaries, and claims intentionally not made." sections={[{heading:'Application controls',body:'Schema validation, constrained public IDs, fail-closed authority, and explicit lifecycle state.'},{heading:'Credential integrity',body:'Integrity hashes, signature metadata, event continuity, and public registry parity remain inspectable.'},{heading:'Production boundary',body:'No live production secrets, HSM authority, or external compliance certification is claimed.'}]} />;
  if (path === '/company') return <Company />;
  if (path === '/contact') return <Contact />;
  if (path === '/access') return <Access />;
  if (path === '/sign-in') return <SignIn />;
  if (path === '/status') return <Status />;
  if (path === '/changelog') return <Changelog />;
  if (path === '/brand/trademark') return <Trademark />;
  if (path === '/provenance-verified') { const doc = legalContent['certification-policy']; return <PolicyDocument title="Provenance Verified™" summary="Four-tier gemstone provenance certification issued by VERITAN, INC. and operated through provenanceverified.org." sections={doc.sections} aside={<div className="pv2-route-seal-cluster" aria-label="Provenance Verified certification seal system"><TierSeal tier={4} authorized /><span>R5 certification seal system</span></div>} />; }
  return <NotFound path={path} />;
}
export function StandaloneApplication() {
  const path = usePathname();
  const content = path.startsWith('/app') ? <OperationsRoute path={path} /> : <PublicRoute path={path} />;
  useEffect(() => { document.title = `${path.startsWith('/app') ? 'Operations' : 'PROVENANCE VERIFIED™'} — Unified R8.1 Review`; }, [path]);
  return <><a className="skip-link" href="#main-content">Skip to content</a><StandaloneControl /><div className="site-chrome"><SiteHeader />{content}<SiteFooter /></div><AccessibleStatus /><LivingInterface /><ApiInspector /></>;
}
