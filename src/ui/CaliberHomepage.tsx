'use client';

import Link from 'next/link';
import { useEffect, useMemo, useRef, useState } from 'react';
import { STAGES } from '@/domain/constants';
import { fixtureList } from '@/domain/fixtures';
import { operationalDataset } from '@/operations/fixtures';
import { SpatialEnvironment } from '@/spatial/SpatialEnvironment';
import { useProvenanceStore } from '@/store/useProvenanceStore';
import { TierSeal } from './TierSeal';
import { R5TierDeck } from '@/identity/R5TierDeck';
import { ScrollCodeBlock } from './ScrollCodeBlock';

type CodeLanguage = 'TypeScript' | 'cURL' | 'MCP';

type CredibilityControl = {
  title: string;
  summary: string;
  status: string;
  source: string;
  test: string;
  projection: string;
  glyph: string;
};

const credibilityControls: CredibilityControl[] = [
  { title: 'Canonical service contract', summary: 'Identity, evidence, policy, issuance, registry, lifecycle, API, and MCP operations share one contract.', status: 'enforced', source: 'src/services/contract.ts', test: 'service-contract.test.ts', projection: 'human + api + qr + events', glyph: '⌘' },
  { title: 'Fail-closed authority', summary: 'Eligibility, issuance, publication, revocation control, and mark authorization remain separate decisions.', status: 'enforced', source: 'src/domain/authority.ts', test: 'authority.test.ts', projection: 'credential + registry', glyph: '◇' },
  { title: 'Immutable audit continuity', summary: 'Material state transitions carry attributable receipts and event-chain integrity.', status: 'enforced', source: 'src/operations/audit.ts', test: 'operations-lifecycle-correction.test.ts', projection: 'audit + events', glyph: '≋' },
  { title: 'Tenant and role isolation', summary: 'Operational reads and writes are constrained by signed Test Mode session scope.', status: 'enforced', source: 'src/operations/auth.ts', test: 'operations-api.test.ts', projection: 'operations api', glyph: '⊞' },
  { title: 'Lifecycle governance', summary: 'Suspend, reactivate, revoke, supersede, and expire transitions remain resolvable.', status: 'enforced', source: 'src/operations/lifecycle.ts', test: 'operations-lifecycle-correction.test.ts', projection: 'registry + mark control', glyph: '↻' },
  { title: 'Separate mark control', summary: 'A credential can exist while certification-mark projection remains withheld or suppressed.', status: 'enforced', source: 'src/domain/projectors.ts', test: 'projections.test.ts', projection: 'seal + label + qr', glyph: '✦' },
  { title: 'Public and machine parity', summary: 'The human record and machine response resolve from the same canonical digest.', status: 'verified', source: 'src/adapters/projections.ts', test: 'caliber-public-system.test.tsx', projection: 'registry + api', glyph: '◎' },
  { title: 'Deterministic Test Mode', summary: 'Fixtures are explicit, repeatable, non-authoritative, and refused as production authority.', status: 'bounded', source: 'src/services/deterministic.ts', test: 'fixtures.test.ts', projection: 'all test surfaces', glyph: 'T' },
  { title: 'Live spatial runtime', summary: 'One Three.js authority object runs with reduced-motion and no-WebGL fallbacks.', status: 'verified', source: 'src/spatial/SpatialEnvironment.tsx', test: 'r5-webgl-audit.mjs', projection: 'webgl + static fallback', glyph: '◈' },
];


const authorityGates = [
  ['Evidence eligibility', 'Qualified evidence maps to scoped claims.'],
  ['Review determination', 'A reviewer decides what the evidence actually supports.'],
  ['Required approvals', 'Tier-specific independent approvals are recorded.'],
  ['Conflict clearance', 'Reviewer and organization conflicts must be clear.'],
  ['CUSTOS', 'Independent policy and integrity control must pass.'],
  ['Signing authorization', 'Issuer key and signing authority must be available.'],
  ['Registry publication', 'The canonical public record must be confirmed.'],
  ['Revocation control', 'Suspension, revocation, and supersession must remain possible.'],
  ['Credential issuance', 'Only PROVENANCE VERIFIED™ can issue Tier 1–4 credentials.'],
  ['Mark authorization', 'Certification-mark use is approved separately.'],
] as const;

const lifecycleKeys = ['t4', 'suspended', 'revoked', 'superseded', 'expired'] as const;
const codeLanguageOrder: CodeLanguage[] = ['TypeScript', 'cURL', 'MCP'];
const CREDIBILITY_AUTO_MS = 5200;
const DEVELOPER_AUTO_MS = 5600;

const codeExamples: Record<CodeLanguage, string> = {
  TypeScript: `const result = await provenance.verify({\n  publicId: 'PV-TEST-T4D004',\n  mode: 'test'\n});\n\nif (result.credential.status !== 'issued') {\n  throw new Error(result.authorization.blockers.join(', '));\n}`,
  cURL: `curl https://provenanceverified.org/api/v1/verify \\\n  -H 'content-type: application/json' \\\n  -d '{"publicId":"PV-TEST-T4D004","mode":"test"}'`,
  MCP: `// Contract only. No production MCP runtime is claimed.\nprovenance_verify({\n  public_id: 'PV-TEST-T4D004',\n  mode: 'test'\n})`,
};

function GateState({ passed, label }: { passed: boolean; label: string }) {
  return <span className={passed ? 'pv2-gate-state is-pass' : 'pv2-gate-state is-open'}><i />{passed ? 'Verified' : label}</span>;
}

export function CaliberHomepage() {
  const fixture = useProvenanceStore((state) => state.fixture);
  const decision = useProvenanceStore((state) => state.decision);
  const credential = useProvenanceStore((state) => state.credential);
  const events = useProvenanceStore((state) => state.events);
  const stageIndex = useProvenanceStore((state) => state.stageIndex);
  const runState = useProvenanceStore((state) => state.runState);
  const noWebGL = useProvenanceStore((state) => state.noWebGL);
  const setNoWebGL = useProvenanceStore((state) => state.setNoWebGL);
  const selectFixture = useProvenanceStore((state) => state.selectFixture);
  const setStage = useProvenanceStore((state) => state.setStage);
  const runVerification = useProvenanceStore((state) => state.runVerification);
  const [paused, setPaused] = useState(false);
  const [selectedEvidence, setSelectedEvidence] = useState(0);
  const [language, setLanguage] = useState<CodeLanguage>('TypeScript');
  const [selectedCredibility, setSelectedCredibility] = useState(0);
  const [credibilityRun, setCredibilityRun] = useState(0);
  const [developerRun, setDeveloperRun] = useState(0);
  const [credibilityVisible, setCredibilityVisible] = useState(false);
  const [developerVisible, setDeveloperVisible] = useState(false);
  const [credibilityPaused, setCredibilityPaused] = useState(false);
  const [developerPaused, setDeveloperPaused] = useState(false);
  const credibilityRef = useRef<HTMLElement>(null);
  const developerRef = useRef<HTMLElement>(null);

  const issued = credential.status === 'issued';
  const markAuthorized = issued
    && credential.sealAuthorization.status === 'authorized'
    && !['suspended', 'revoked', 'superseded', 'expired'].includes(credential.lifecycle);
  const stage = STAGES[stageIndex];
  const activeEvidence = credential.evidence[selectedEvidence] ?? credential.evidence[0];
  const operationTenant = operationalDataset.tenants[0];
  const operationBatches = operationalDataset.batches.filter((item) => item.tenantId === operationTenant.id);
  const operationAssets = operationalDataset.assets.filter((item) => item.tenantId === operationTenant.id);
  const operationReviews = operationalDataset.reviewCases.filter((item) => item.tenantId === operationTenant.id);

  const projection = useMemo(() => ({
    public_id: credential.publicId,
    evidence_tier: decision.tier,
    credential: credential.status,
    lifecycle: credential.lifecycle,
    registry: issued ? 'published' : 'not_published',
    mark_authorization: markAuthorized ? 'authorized' : 'withheld',
    integrity: credential.integrityHash,
  }), [credential, decision.tier, issued, markAuthorized]);

  const credibilityReceipt = useMemo(() => {
    const control = credibilityControls[selectedCredibility];
    return JSON.stringify({
      control: control.title.toLowerCase().replace(/[^a-z0-9]+/g, '_'),
      status: control.status,
      source: control.source,
      verification: control.test,
      projection: control.projection,
      authority: 'PROVENANCE VERIFIED™ / VERITAN, INC.',
    }, null, 2);
  }, [selectedCredibility]);

  useEffect(() => {
    const targets = [
      [credibilityRef.current, setCredibilityVisible],
      [developerRef.current, setDeveloperVisible],
    ] as const;
    if (typeof IntersectionObserver === 'undefined') {
      const frame = requestAnimationFrame(() => {
        setCredibilityVisible(true);
        setDeveloperVisible(true);
      });
      return () => cancelAnimationFrame(frame);
    }
    const observers = targets.flatMap(([target, setter]) => {
      if (!target) return [];
      const observer = new IntersectionObserver(([entry]) => setter(entry.isIntersecting), {
        threshold: 0.34,
        rootMargin: '-10% 0px -12% 0px',
      });
      observer.observe(target);
      return [observer];
    });
    return () => observers.forEach((observer) => observer.disconnect());
  }, []);

  useEffect(() => {
    if (!credibilityVisible || credibilityPaused || window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
    const timer = window.setInterval(() => {
      setSelectedCredibility((current) => (current + 1) % credibilityControls.length);
      setCredibilityRun((current) => current + 1);
    }, CREDIBILITY_AUTO_MS);
    return () => window.clearInterval(timer);
  }, [credibilityPaused, credibilityVisible]);

  useEffect(() => {
    if (!developerVisible || developerPaused || window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
    const timer = window.setInterval(() => {
      setLanguage((current) => codeLanguageOrder[(codeLanguageOrder.indexOf(current) + 1) % codeLanguageOrder.length]);
      setDeveloperRun((current) => current + 1);
    }, DEVELOPER_AUTO_MS);
    return () => window.clearInterval(timer);
  }, [developerPaused, developerVisible]);

  function inspectCredibility(index: number) {
    setSelectedCredibility(index);
    setCredibilityRun((current) => current + 1);
  }

  function loadLanguage(nextLanguage: CodeLanguage) {
    setLanguage(nextLanguage);
    setDeveloperRun((current) => current + 1);
  }

  const gatePass = [
    decision.eligible,
    credential.claims.length > 0,
    credential.authorization.acceptedApprovalCount >= credential.authorization.requiredApprovalCount,
    !credential.authorization.blockers.some((item) => item.toLowerCase().includes('conflict')),
    !credential.authorization.blockers.some((item) => item.toLowerCase().includes('custos')),
    credential.signature.status === 'valid',
    issued,
    issued,
    issued,
    markAuthorized,
  ];

  async function chooseLifecycle(key: typeof lifecycleKeys[number]) {
    selectFixture(key);
    await runVerification();
  }

  return (
    <main id="main-content" className="pv2-main">
      <section className="pv2-hero" aria-labelledby="pv2-hero-title">
        <div className="pv2-hero-grid" aria-hidden="true" />
        <div className="pv2-hero-beam" aria-hidden="true" />
        <div className="pv2-hero-shell">
          <div className="pv2-hero-copy">
            <div className="pv2-kicker"><span>PROVENANCE VERIFIED™</span><i />AI-era trust infrastructure</div>
            <h1 id="pv2-hero-title"><span>Trust.</span><small>Made operational.</small></h1>
            <p>Turn physical evidence into scoped claims, signed credentials, public registry records, lifecycle control, and machine-readable verification—without collapsing evidence into authority.</p>
            <div className="pv2-hero-actions">
              <Link className="pv2-button pv2-button-primary" href="/verify">Verify a certification <span>↗</span></Link>
              <Link className="pv2-button pv2-button-ghost" href="/standard">Read the standard</Link>
              <Link className="pv2-button pv2-button-ghost" href="/developers">Build with the API</Link>
            </div>
            <div className="pv2-capability-line">
              <span>Evidence graph</span><span>Issuer authority</span><span>Public registry</span><span>API parity</span>
            </div>
          </div>

          <div className="pv2-proof-object" data-state={runState}>
            <div className="pv2-object-meta"><span>LIVE AUTHORITY OBJECT</span><strong>{fixture.publicId}</strong></div>
            <div className="pv2-object-stage">
              <SpatialEnvironment paused={paused} />
              <button className="pv2-pause" type="button" data-live-label="Toggle authority object motion" onClick={() => setPaused((value) => !value)} aria-label={paused ? 'Resume proof object motion' : 'Pause proof object motion'}>{paused ? '▶' : 'Ⅱ'}</button>
              <label className="pv2-webgl-toggle sr-only"><input type="checkbox" checked={noWebGL} onChange={(e) => setNoWebGL(e.target.checked)} />No WebGL</label>
              <div className="pv2-object-state">
                <span>{String(stageIndex + 1).padStart(2, '0')} / 07</span>
                <strong>{stage.label}</strong>
                <small>{stage.detail}</small>
              </div>
              <div className="pv2-object-response">
                <header><span>CANONICAL RESPONSE</span><b>{issued ? '200 ACTIVE' : runState === 'error' ? '409 BLOCKED' : 'READY'}</b></header>
                <pre tabIndex={0} aria-label="Canonical machine response">{JSON.stringify(projection, null, 2)}</pre>
              </div>
            </div>
          </div>
        </div>

        <div className="pv2-stage-rail" role="tablist" aria-label="Verification stages">
          {STAGES.map((item, index) => (
            <button key={item.id} type="button" role="tab" data-live-label={`Load ${item.label} proof stage`} aria-selected={stageIndex === index} className={stageIndex === index ? 'is-active' : index < stageIndex ? 'is-complete' : ''} onClick={() => setStage(index)}>
              <span>{String(index + 1).padStart(2, '0')}</span><strong>{item.label}</strong><small>{item.detail}</small>
            </button>
          ))}
        </div>
        <div className="pv2-mode-line"><span>TEST MODE</span><span>Deterministic authority fixtures</span><span>Production adapters not connected</span></div>
      </section>

      <section className="pv2-section pv2-parity" id="verification">
        <div className="pv2-section-head">
          <span className="pv2-chapter">01 / CANONICAL PARITY</span>
          <h2>One record.<br />Every consequence.</h2>
          <p>The human page, registry API, QR resolver, webhook state, and machine response derive from the same canonical record. No projection invents authority.</p>
        </div>
        <div className="pv2-parity-machine">
          <div className="pv2-parity-source">
            <span>PHYSICAL ASSET</span>
            <div className="pv2-asset-gem"><i /><i /><i /><i /><i /><i /></div>
            <strong>Natural sapphire</strong>
            <small>{fixture.publicId} · controlled test record</small>
          </div>
          <div className="pv2-parity-ledger">
            <header><span>CANONICAL AUTHORITY RECORD</span><b>{credential.integrityHash.slice(0, 18)}…</b></header>
            <dl>
              <div><dt>Evidence eligibility</dt><dd>Tier {decision.tier} · {decision.tierName}</dd></div>
              <div><dt>Issuer determination</dt><dd>{credential.authorization.status}</dd></div>
              <div><dt>Credential lifecycle</dt><dd>{credential.lifecycle}</dd></div>
              <div><dt>Mark control</dt><dd>{markAuthorized ? 'authorized' : 'withheld'}</dd></div>
            </dl>
          </div>
          <div className="pv2-parity-projections">
            {[
              ['Human record', issued ? `/registry/${credential.publicId}` : '/verify'],
              ['Registry API', `/api/v1/registry/${credential.publicId}`],
              ['QR resolver', `/registry/${credential.publicId}`],
              ['Webhook event', '/docs/webhooks'],
              ['MCP contract', '/docs/mcp'],
            ].map(([label, href], index) => <Link key={label} href={href}><span>{String(index + 1).padStart(2, '0')}</span><strong>{label}</strong><em>Same digest ↗</em></Link>)}
          </div>
        </div>
      </section>

      <section className="pv2-section pv2-evidence">
        <div className="pv2-section-head pv2-section-head-split">
          <div><span className="pv2-chapter">02 / EVIDENCE DEPTH</span><h2>Evidence stays inspectable.</h2></div>
          <p>Every claim preserves its source, qualification, independence, integrity digest, custody path, and disclosure boundary.</p>
        </div>
        <div className="pv2-evidence-workbench">
          <div className="pv2-evidence-list" role="listbox" aria-label="Evidence objects">
            <header><span>EVIDENCE OBJECTS</span><b>{credential.evidence.length}</b></header>
            {credential.evidence.slice(0, 6).map((item, index) => (
              <button key={item.id} type="button" role="option" aria-selected={selectedEvidence === index} className={selectedEvidence === index ? 'is-selected' : ''} onClick={() => setSelectedEvidence(index)}>
                <span>{String(index + 1).padStart(2, '0')}</span><div><strong>{item.type}</strong><small>{item.id}</small></div><em>{item.qualified ? 'qualified' : 'limited'}</em>
              </button>
            ))}
          </div>
          <article className="pv2-evidence-detail">
            <header><span>INSPECTED EVIDENCE</span><b>{activeEvidence?.hash.slice(0, 18)}…</b></header>
            <h3>{activeEvidence?.type ?? 'Evidence object'}</h3>
            <p>{activeEvidence?.label ?? 'No evidence is available for this deterministic record.'}</p>
            <dl>
              <div><dt>Source</dt><dd>{activeEvidence?.sourceId ?? 'Not available'}</dd></div>
              <div><dt>Independent</dt><dd>{activeEvidence?.independent ? 'Yes' : 'No'}</dd></div>
              <div><dt>Qualified</dt><dd>{activeEvidence?.qualified ? 'Yes' : 'No'}</dd></div>
              <div><dt>Captured</dt><dd>{activeEvidence?.capturedAt ?? 'Not available'}</dd></div>
            </dl>
            <div className="pv2-claim-scope"><span>CLAIM SCOPE</span>{credential.claims.slice(0, 4).map((claim) => <div key={claim.id}><strong>{claim.label}</strong><em data-state={claim.status}>{claim.status}</em></div>)}</div>
          </article>
          <div className="pv2-custody-line">
            <span>CONTINUITY</span>
            {credential.custody.slice(0, 5).map((event, index) => <div key={`${event.id}-${index}`}><i /><strong>{event.action}</strong><small>{event.actor}</small><time>{event.at.slice(0, 10)}</time></div>)}
          </div>
        </div>
      </section>

      <section className="pv2-section pv2-authority">
        <div className="pv2-authority-intro">
          <span className="pv2-chapter">03 / AUTHORITY LAW</span>
          <h2>Eligibility is not issuance.<br />Issuance is not mark authorization.</h2>
          <p>PROVENANCE VERIFIED™ alone issues Tier 1 through Tier 4. Partners, suppliers, miners, lapidaries, and customers may submit evidence; none can issue a PROVENANCE VERIFIED™ credential.</p>
          <Link href="/trust" className="pv2-text-link">Inspect the trust architecture <span>↗</span></Link>
        </div>
        <ol className="pv2-gate-sequence">
          {authorityGates.map(([title, description], index) => <li key={title} className={gatePass[index] ? 'is-pass' : ''}>
            <span>{String(index + 1).padStart(2, '0')}</span><div><strong>{title}</strong><p>{description}</p></div><GateState passed={gatePass[index]} label="Required" />
          </li>)}
        </ol>
      </section>

      <section className="pv2-section pv2-registry">
        <div className="pv2-section-head pv2-section-head-split">
          <div><span className="pv2-chapter">04 / PUBLIC REGISTRY</span><h2>Lifecycle never disappears.</h2></div>
          <p>Suspended, revoked, superseded, and expired records remain resolvable. Reliance changes; history remains inspectable.</p>
        </div>
        <div className="pv2-registry-stage">
          <div className="pv2-lifecycle-nav" role="tablist" aria-label="Lifecycle record examples">
            {lifecycleKeys.map((key) => {
              const item = fixtureList.find((candidate) => candidate.key === key)!;
              return <button key={key} role="tab" data-live-label={`Resolve ${item.lifecycle} credential`} aria-selected={fixture.key === key} className={fixture.key === key ? 'is-active' : ''} onClick={() => void chooseLifecycle(key)}><span>{item.lifecycle}</span><strong>{item.name}</strong><small>{item.publicId}</small></button>;
            })}
          </div>
          <article className="pv2-public-record">
            <header><div><span>PUBLIC CREDENTIAL RECORD</span><strong>{credential.publicId}</strong></div><em data-lifecycle={credential.lifecycle}>{credential.lifecycle}</em></header>
            <div className="pv2-public-record-main">
              <TierSeal tier={credential.tier ?? decision.tier} authorized={markAuthorized} />
              <div><span>{issued ? 'ISSUED CREDENTIAL' : 'EVIDENCE ELIGIBILITY'}</span><h3>Tier {credential.tier ?? decision.tier} · {credential.tierName ?? decision.tierName}</h3><p>{issued ? credential.disclosure : decision.disclosure}</p></div>
            </div>
            <div className="pv2-public-record-grid">
              <div><span>Issuer</span><strong>PROVENANCE VERIFIED™</strong></div><div><span>Registry</span><strong>{issued ? 'Published' : 'Withheld'}</strong></div><div><span>Signature</span><strong>{credential.signature.status}</strong></div><div><span>Mark</span><strong>{markAuthorized ? 'Authorized' : 'Suppressed'}</strong></div>
            </div>
            <footer><span>{events.length} event receipts</span><span>{credential.claims.length} claim determinations</span><Link href={issued ? `/registry/${credential.publicId}` : '/verify'}>Open full record ↗</Link></footer>
          </article>
        </div>
      </section>


      <section ref={credibilityRef} className={`pv2-section pv2-credibility ${credibilityPaused ? 'is-auto-paused' : ''}`} id="credibility" onPointerEnter={() => setCredibilityPaused(true)} onPointerLeave={() => setCredibilityPaused(false)} onFocusCapture={() => setCredibilityPaused(true)} onBlurCapture={() => setCredibilityPaused(false)}>
        <div className="pv2-section-head pv2-section-head-split">
          <div><span className="pv2-chapter">05 / INSTITUTIONAL CREDIBILITY</span><h2>Enterprise grade <span>by design.</span></h2></div>
          <p>Credibility is earned through inspectable controls, attributable authority, and repeatable proof—not borrowed logos, invented uptime, or unsupported compliance claims.</p>
        </div>
        <div className="pv2-credibility-stage">
          <div className="pv2-credibility-grid" role="group" aria-label="Implemented credibility controls">
            {credibilityControls.map((control, index) => (
              <button key={control.title} type="button" aria-pressed={selectedCredibility === index} className={selectedCredibility === index ? 'is-active' : ''} data-live-label={`Inspect ${control.title}`} onClick={() => inspectCredibility(index)}>
                <span aria-hidden="true">{control.glyph}</span><strong>{control.title}</strong><p>{control.summary}</p><em>{control.status}</em><i className="pv2-auto-progress" aria-hidden="true" />
              </button>
            ))}
          </div>
          <div className="pv2-control-receipt" aria-live="polite">
            <header><div><span>CONTROL RECEIPT</span><strong>{credibilityControls[selectedCredibility].title}</strong></div><b><i />AUTO {String(selectedCredibility + 1).padStart(2, '0')} / {String(credibilityControls.length).padStart(2, '0')}</b></header>
            <ScrollCodeBlock key={`credibility-${selectedCredibility}-${credibilityRun}`} code={credibilityReceipt} ariaLabel={`${credibilityControls[selectedCredibility].title} implementation receipt`} speed={7} />
            <footer><span>Source-linked · test-linked · projection-linked</span><Link href="/trust">Inspect authority ↗</Link></footer>
          </div>
        </div>
      </section>

      <section className="pv2-section pv2-operations">
        <div className="pv2-section-head pv2-section-head-split">
          <div><span className="pv2-chapter">06 / JEWELER OPERATIONS</span><h2>From parcel intake to controlled issuance.</h2></div>
          <p>Aggregate lots remain aggregate until a real unit identity exists. Every operational action preserves tenant, role, evidence, review, synchronization, and audit context.</p>
        </div>
        <div className="pv2-ops-window">
          <nav className="pv2-ops-sidebar" aria-label="Operations preview navigation">
            <div className="pv2-ops-brand">PV<span>OPERATIONS</span></div>
            {([['Command','/app'],['Lots','/app/lots'],['Intake','/app/intake'],['Batches','/app/batches'],['Review','/app/review'],['Labels','/app/labels'],['Exceptions','/app/exceptions'],['Audit','/app/audit']] as const).map(([item, href], index) => <Link key={item} href={href} className={index === 0 ? 'is-active' : ''} data-live-label={`Open operations ${item}`}>{item}<i /></Link>)}
          </nav>
          <div className="pv2-ops-main">
            <header><div><span>ACTIVE ORGANIZATION</span><strong>{operationTenant.displayName}</strong></div><em>Test Mode · Phoenix Intake Lab</em></header>
            <div className="pv2-ops-metrics">
              <article><span>Aggregate lots</span><strong>{operationalDataset.lots.filter((item) => item.tenantId === operationTenant.id).length}</strong><small>Quantity is never expanded into fake units</small></article>
              <article><span>Identified units</span><strong>{operationAssets.length}</strong><small>Each unit has a real explicit identity</small></article>
              <article><span>Review cases</span><strong>{operationReviews.length}</strong><small>{operationReviews.filter((item) => item.status === 'secondary-required').length} require dual review</small></article>
              <article><span>Synchronization</span><strong>1</strong><small>Queued work remains visibly unsubmitted</small></article>
            </div>
            <div className="pv2-ops-table">
              <div className="pv2-ops-table-head"><span>Batch</span><span>Status</span><span>Units</span><span>Authority state</span></div>
              {operationBatches.map((batch) => <div key={batch.id}><span><strong>{batch.reference}</strong><small>{batch.name}</small></span><em>{batch.status}</em><b>{batch.assetIds.length}</b><span>{operationReviews.some((review) => review.batchId === batch.id) ? 'Review open' : 'Intake only'}</span></div>)}
              <div><span><strong>LOT PHX-0719-A</strong><small>Mixed blue sapphire parcel</small></span><em>aggregate</em><b>120 qty / 24 IDs</b><span>Identity creation required</span></div>
            </div>
            <footer><Link href="/app" className="pv2-button pv2-button-primary">Open operations workspace <span>↗</span></Link><span>Role-aware · tenant-isolated · offline-aware</span></footer>
          </div>
        </div>
      </section>

      <section ref={developerRef} className={`pv2-section pv2-developer ${developerPaused ? 'is-auto-paused' : ''}`} onPointerEnter={() => setDeveloperPaused(true)} onPointerLeave={() => setDeveloperPaused(false)} onFocusCapture={() => setDeveloperPaused(true)} onBlurCapture={() => setDeveloperPaused(false)}>
        <div className="pv2-developer-copy">
          <span className="pv2-chapter">07 / DEVELOPER PLATFORM</span>
          <h2>One contract from evidence intake to public consequence.</h2>
          <p>Integrate verification, registry, lifecycle, events, webhooks, SDKs, and the MCP contract without recreating issuer authority in client code.</p>
          <div className="pv2-developer-links"><Link href="/docs/quickstart">Quickstart ↗</Link><Link href="/docs/api">API reference ↗</Link><Link href="/docs/webhooks">Webhooks ↗</Link><Link href="/docs/mcp">MCP contract ↗</Link></div>
        </div>
        <div className="pv2-code-window">
          <header><div role="tablist" aria-label="Code examples">{codeLanguageOrder.map((item) => <button key={item} type="button" role="tab" aria-selected={language === item} data-live-label={`Load ${item} integration example`} onClick={() => loadLanguage(item)}>{item}<i aria-hidden="true" /></button>)}</div><span className="pv2-code-auto"><i />AUTO · {language === 'MCP' ? 'CONTRACT ONLY' : 'TEST MODE'}</span></header>
          <ScrollCodeBlock key={`developer-${language}-${developerRun}`} code={codeExamples[language]} ariaLabel={`${language} canonical integration example`} speed={6} />
          <footer><span>POST /api/v1/verify</span><b>canonical response</b></footer>
        </div>
      </section>

      <section className="pv2-section pv2-tiers">
        <div className="pv2-section-head"><span className="pv2-chapter">08 / PROVENANCE VERIFIED™</span><h2>Four tiers. No implied evidence.</h2><p>Each tier communicates only what the evidence and authority record support. The corporate master mark and certification seals remain separate systems.</p></div>
<R5TierDeck />
      </section>

      <section className="pv2-final">
        <div><span>PROVENANCE VERIFIED™</span><h2>Trust must survive inspection.</h2><p>Evidence. Authority. Registry. Lifecycle. Machine-readable consequence.</p></div>
        <div><Link href="/access" className="pv2-button pv2-button-primary">Request access <span>↗</span></Link><Link href="/verify" className="pv2-button pv2-button-ghost">Verify a record</Link></div>
      </section>
    </main>
  );
}
