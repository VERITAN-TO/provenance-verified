'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';
import { CorporateLockup, CorporateMark3D } from '@/identity/CorporateIdentity';
import { TEST_MODE_LABELS } from '@/domain/constants';
import { projectionParity } from '@/adapters/projections';
import { useProvenanceStore } from '@/store/useProvenanceStore';
import { selectWebhookSummary } from '@/store/selectors';
import { ProofChapterHeader, StatePill } from './Shared';
import { R5IdentityObject } from '@/identity/R5IdentityObject';
import type { CertificationTier } from '@/domain/types';


function FooterTierRuntime() {
  const [tier, setTier] = useState<CertificationTier>(4);
  const [paused, setPaused] = useState(false);
  useEffect(() => {
    if (paused) return;
    const timer = window.setInterval(() => setTier((current) => (current === 4 ? 1 : current + 1) as CertificationTier), 5200);
    return () => window.clearInterval(timer);
  }, [paused]);
  return <div className="p3-footer-tier-runtime" onPointerEnter={() => setPaused(true)} onPointerLeave={() => setPaused(false)} onFocusCapture={() => setPaused(true)} onBlurCapture={(event) => { if (!event.currentTarget.contains(event.relatedTarget as Node | null)) setPaused(false); }}>
    <div className="p3-footer-tier-object"><R5IdentityObject key={`footer-tier-${tier}`} variant="certification" tier={tier} compact priority label={`Live R5 Three.js Provenance Verified Tier ${tier} certification seal`} /></div>
    <div className="p3-footer-tier-selector" role="tablist" aria-label="Footer certification tier selector">
      {([1, 2, 3, 4] as const).map((item) => <button key={item} type="button" role="tab" aria-selected={tier === item} onClick={() => setTier(item)}><span>0{item}</span><strong>Tier {item}</strong><i /></button>)}
    </div>
  </div>;
}

export function AuthorityBoundary() {
  const credential = useProvenanceStore((state) => state.credential);
  const apiLog = useProvenanceStore((state) => state.apiLog);
  const webhooks = useProvenanceStore((state) => state.webhooks);
  const replayVerification = useProvenanceStore((state) => state.replayVerification);
  const parity = projectionParity(credential);
  const webhookSummary = selectWebhookSummary(webhooks);
  const aligned = Object.values(parity).every(Boolean);

  return (
    <>
      <section className="p3-chapter p3-operations" aria-labelledby="p3-operations-title">
        <ProofChapterHeader
          index="07"
          eyebrow="OPERABILITY + AUTHORITY"
          title="Operators can trace, recover, and explain every deterministic result."
          description="Health, requests, blockers, event delivery, decision traces, and human gates remain visible. The interface does not invent uptime, customers, production signing, or deployed services."
          aside={<StatePill tone={aligned ? 'good' : 'danger'}>{aligned ? 'CANONICAL PARITY' : 'INVESTIGATE'}</StatePill>}
        />
        <div className="p3-ops-grid">
          <article className="p3-ops-health">
            <div className="p3-panel-head"><span>DETERMINISTIC SERVICE STATE</span><strong>TEST MODE</strong></div>
            <dl>
              <div><dt>Certification kernel</dt><dd>Ready</dd></div>
              <div><dt>Authority gates</dt><dd>{credential.authorization.status}</dd></div>
              <div><dt>Registry projection</dt><dd>{credential.status === 'issued' ? 'Resolvable' : 'Withheld'}</dd></div>
              <div><dt>Webhook fixture</dt><dd>{webhookSummary.failed ? 'Failure scenario active' : 'Ready'}</dd></div>
              <div><dt>Canonical parity</dt><dd>{aligned ? 'Aligned' : 'Mismatch'}</dd></div>
            </dl>
            <Link href="/status">Open status surface →</Link>
          </article>

          <article className="p3-ops-log">
            <div className="p3-panel-head"><span>REQUEST HISTORY</span><strong>{apiLog.length || 1} RECORD</strong></div>
            {(apiLog.length ? apiLog : [{ id: `req_${credential.publicId}`, method: 'POST', path: '/api/v1/verify', status: credential.status === 'issued' ? 200 : 409, at: '2026-07-16T10:07:00Z' }]).map((log) => (
              <div key={log.id} className="p3-request-row">
                <span className={log.status >= 400 ? 'error' : 'ok'}>{log.status}</span>
                <div><strong>{log.method} {log.path}</strong><small>{log.id} · {log.at}</small></div>
                <button type="button" onClick={() => void replayVerification()}>Replay</button>
              </div>
            ))}
          </article>

          <aside className="p3-human-gate">
            <div className="eyebrow"><span />HUMAN AUTHORITY GATE</div>
            <h3>{credential.status === 'issued' ? `Credential authorized with ${credential.authorization.acceptedApprovalCount} accepted approvals.` : `Issuance blocked: ${credential.authorization.status}.`}</h3>
            <p>AI may classify, summarize, compare, and flag. It cannot approve its own record, clear reviewer conflicts, satisfy CUSTOS, sign a credential, publish the registry, or authorize a certification mark.</p>
            {credential.authorization.blockers.map((blocker) => <small key={blocker}>{blocker}</small>)}
          </aside>
        </div>
      </section>

      <section className="p3-chapter p3-trust" aria-labelledby="p3-trust-title">
        <ProofChapterHeader
          index="08"
          eyebrow="PUBLIC AUTHORITY"
          title="The issuer, evidence rules, lifecycle controls, and test boundary are public."
          description="Trust does not come from a decorative mark. It comes from attributable authority, inspectable policy, controlled keys, resolvable lifecycle, and visible limitations."
        />
        <div className="p3-trust-grid">
          <article className="p3-issuer-card">
            <CorporateMark3D className="p3-issuer-mark" compact interactive />
            <div><small>PLATFORM</small><h3>PROVENANCE VERIFIED™</h3><p>Evidence, verification, registry, lifecycle, API, and machine-readable infrastructure.</p><small>ISSUER</small><h3>VERITAN, INC.</h3><p>Provenance Verified™ certifications are issued and lifecycle-controlled by VERITAN, INC.</p></div>
          </article>
          <nav className="p3-policy-links" aria-label="Public authority policies">
            <Link href="/security"><strong>Security architecture</strong><span>Boundary controls, dependencies, signing assumptions, and threat surfaces.</span></Link>
            <Link href="/legal/evidence-policy"><strong>Evidence policy</strong><span>Qualification, independence, correspondence, custody, and integrity.</span></Link>
            <Link href="/legal/certification-policy"><strong>Certification policy</strong><span>Four evidence tiers and separate issuer controls.</span></Link>
            <Link href="/legal/revocation-policy"><strong>Lifecycle policy</strong><span>Suspension, supersession, revocation, expiration, and resolvability.</span></Link>
            <Link href="/trust"><strong>Trust center</strong><span>Issuer, keys, mode boundaries, status, and public controls.</span></Link>
            <Link href="/brand/trademark"><strong>Identity control</strong><span>Corporate mark and certification-seal separation.</span></Link>
          </nav>
        </div>
      </section>

      <section className="p3-access" aria-labelledby="p3-access-title">
        <div><div className="eyebrow"><span />BUILD THE EVIDENCE LAYER</div><h2 id="p3-access-title">Make proof resolvable by people, registries, and machines.</h2><p>Start in deterministic Test Mode, inspect the complete transaction, then request an authorized pilot or production integration.</p><div className="p3-access-actions"><Link href="/access" className="button button-primary">Request pilot access</Link><Link href="/docs/quickstart" className="button button-secondary">Read the quickstart</Link><Link href="/contact" className="inline-action">Contact us →</Link></div></div>
      </section>
    </>
  );
}

export function InstitutionalFooter() {
  return (
    <footer className="p3-footer p3-footer-r8">
      <div className="p3-footer-atmosphere" aria-hidden="true" />
      <section className="p3-footer-cta" aria-labelledby="p3-footer-cta-title">
        <div>
          <span>CANONICAL TRUST INFRASTRUCTURE</span>
          <h2 id="p3-footer-cta-title">Make evidence resolvable.</h2>
          <p>Begin in deterministic Test Mode. Inspect the full transaction. Move to an authorized integration only when identity, signing, registry, and operational boundaries are connected.</p>
        </div>
        <div className="p3-footer-cta-actions">
          <Link href="/access" className="pv2-button pv2-button-primary">Request access <span>↗</span></Link>
          <Link href="/docs/quickstart" className="pv2-button pv2-button-ghost">Read quickstart</Link>
        </div>
      </section>

      <div className="p3-footer-core">
        <div className="p3-footer-brand">
          <div className="p3-footer-brand-lockup"><CorporateLockup priority /><span>ISSUED BY VERITAN, INC.</span></div>
          <div className="p3-footer-brand-object"><CorporateMark3D interactive priority /></div>
          <p>Physical evidence, scoped claims, governed credentials, public registry records, lifecycle control, and machine-readable verification through one canonical authority system.</p>
          <div className="p3-mode-pills">{TEST_MODE_LABELS.map((label) => <span key={label}>{label}</span>)}</div>
        </div>

        <nav className="p3-footer-navigation" aria-label="Footer navigation">
          <div><h3>Platform</h3><Link href="/">Public authority</Link><Link href="/verify">Verify</Link><Link href="/registry">Registry</Link><Link href="/provenance-verified">Provenance Verified™</Link><Link href="/app">Operations</Link></div>
          <div><h3>Developers</h3><Link href="/developers">Overview</Link><Link href="/docs/quickstart">Quickstart</Link><Link href="/docs/api">API reference</Link><Link href="/docs/sdk">SDK</Link><Link href="/docs/webhooks">Webhooks</Link><Link href="/docs/mcp">MCP contract</Link></div>
          <div><h3>Authority</h3><Link href="/trust">Trust center</Link><Link href="/security">Security</Link><Link href="/legal/evidence-policy">Evidence policy</Link><Link href="/legal/certification-policy">Certification policy</Link><Link href="/legal/revocation-policy">Lifecycle policy</Link></div>
          <div><h3>Company</h3><Link href="/company">VERITAN, INC.</Link><Link href="/contact">Contact</Link><Link href="/status">Status</Link><Link href="/changelog">Changelog</Link><Link href="/brand/trademark">Identity control</Link></div>
        </nav>
      </div>

      <div className="p3-footer-r6-wordmark" aria-hidden="true">
        <span>PROVENANCE</span>
        <i />
      </div>

      <section className="p3-footer-tier-band" aria-label="R5 live certification seal system">
        <div><span>R5 CERTIFICATION SYSTEM</span><strong>Four controlled projections. One issuer authority.</strong></div>
        <FooterTierRuntime />
      </section>

      <div className="p3-footer-bottom">
        <div className="p3-footer-runtime"><i /><span>Deterministic Test Mode</span><em>Production authority adapters remain unconnected.</em></div>
        <div className="p3-footer-legal"><Link href="/legal/privacy">Privacy</Link><Link href="/legal/terms">Terms</Link><span>© 2026 VERITAN, INC.</span></div>
      </div>
      <div className="p3-footer-supergraphic" aria-hidden="true">PROVENANCE VERIFIED</div>
    </footer>
  );
}
