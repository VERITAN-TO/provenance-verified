'use client';

import { useCallback, useEffect, useMemo, useState, type FormEvent } from 'react';
import { authorityFetch } from '@/operations/auth';

type CategoryEvidence = { evidenceId: string; evidenceDigest: string; evidenceUrl: string; verified: boolean; createdAt: string; expiresAt: string | null };
type CategoryControl = { id: string; name: string; ownerIdentity: string; dependencies: string[]; state: string; evidence: CategoryEvidence[] };
type MediaRecord = { id: string; mediaType?: string; credentialId?: string | null; state?: string; useCount?: number; events?: Array<Record<string, unknown>> };
type PartyRecord = { id: string; name?: string; partyType?: string; status?: string; contractStatus?: string; accreditationStatus?: string; updatedAt?: string };
type CustomerAcceptance = { id: string; customerType?: string; tenantName?: string; result?: string; acceptedAt?: string; authoritative?: boolean };
type LaunchGate = { id: string; state: string; evidenceFresh: boolean; killSwitchReady: boolean; approverIdentity?: string; updatedAt?: string };
type StabilizationRecord = { day: number; controlType?: string; result?: string; riskLevel?: string; recordedAt?: string };
type MarkLicense = { id: string; licenseNumber?: string; status?: string; renewalState?: string; expiresAt?: string; permittedMedia?: string[]; permittedGeography?: string[] };
type LocationAuthorization = { id: string; locationId?: string; status?: string; expiresAt?: string; permittedMedia?: string[]; permittedGeography?: string[] };
type ArtworkVersion = { id: string; version?: string; artworkDigest?: string; status?: string; effectiveAt?: string };
type Snapshot = {
  categoryL: CategoryControl[];
  media: MediaRecord[];
  parties: PartyRecord[];
  customers: CustomerAcceptance[];
  launchGates: LaunchGate[];
  stabilization: StabilizationRecord[];
  markLicenses: MarkLicense[];
  locationAuthorizations: LocationAuthorization[];
  artwork: ArtworkVersion[];
  summary: {
    categoryReady: number;
    categoryTotal: number;
    launchReady: number;
    launchTotal: number;
    activeMedia: number;
    governedPartiesCurrent: number;
    stabilizationDaysRecorded: number;
    productionLaunchAuthorized: boolean;
    deterministic?: boolean;
    authoritative?: boolean;
  };
};

type ApiEnvelope<T> = { data?: T; error?: { code?: string; message?: string } };

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await authorityFetch(path, {
    cache: 'no-store',
    ...init,
    headers: { 'content-type': 'application/json', ...(init?.headers ?? {}) },
  });
  const body = await response.json().catch(() => ({})) as ApiEnvelope<T>;
  if (!response.ok || !body.data) throw new Error(body.error?.message ?? body.error?.code ?? `AUTHORITY_REQUEST_FAILED_${response.status}`);
  return body.data;
}

function sha256Placeholder(id: string) {
  return `sha256:${id.toLowerCase().replace(/[^a-f0-9]/g, 'a').padEnd(64, '0').slice(0, 64)}`;
}

export function AuthorityControlCenter() {
  const [snapshot, setSnapshot] = useState<Snapshot | null>(null);
  const [message, setMessage] = useState('Loading launch-to-operate authority…');
  const [busy, setBusy] = useState(false);
  const [mediaSecret, setMediaSecret] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      setMessage('Loading server-authoritative campaign state…');
      setSnapshot(await request<Snapshot>('/api/v1/authority/control-center'));
      setMessage('Launch-to-operate authority state loaded.');
    } catch (error) {
      setMessage(error instanceof Error ? error.message : 'Authority control state unavailable.');
    }
  }, []);

  useEffect(() => { void load(); }, [load]);

  async function submit<T>(path: string, payload: Record<string, unknown>, method: 'POST' | 'PATCH' = 'POST'): Promise<T | null> {
    try {
      setBusy(true);
      setMessage('Committing attributed authority operation…');
      const result = await request<T>(path, { method, body: JSON.stringify(payload) });
      setMessage('Authority operation committed and audit-bound.');
      await load();
      return result;
    } catch (error) {
      setMessage(error instanceof Error ? error.message : 'Authority operation failed closed.');
      return null;
    } finally {
      setBusy(false);
    }
  }

  async function attachCategoryEvidence(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    const evidenceId = String(form.get('evidenceId') ?? '');
    await submit('/api/v1/authority/category-l/evidence', {
      controlId: form.get('controlId'),
      evidenceId,
      evidenceDigest: form.get('evidenceDigest') || sha256Placeholder(evidenceId),
      evidenceUrl: form.get('evidenceUrl') || `sandbox://evidence/${encodeURIComponent(evidenceId)}`,
      verified: form.get('verified') === 'on',
      expiresAt: form.get('expiresAt') || null,
    });
  }

  async function createMedia(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formElement = event.currentTarget;
    const form = new FormData(formElement);
    const result = await submit<MediaRecord & { activationCode?: string }>('/api/v1/authority/media', {
      mediaType: form.get('mediaType'),
      credentialId: form.get('credentialId') || null,
    });
    if (result?.activationCode) setMediaSecret(result.activationCode);
    formElement.reset();
  }

  async function transitionMedia(mediaId: string, action: string) {
    await submit(`/api/v1/authority/media/${encodeURIComponent(mediaId)}/transition`, { action });
  }

  async function upsertParty(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formElement = event.currentTarget;
    const form = new FormData(formElement);
    await submit('/api/v1/authority/governance', {
      name: form.get('name'), partyType: form.get('partyType'), status: form.get('status'),
      contractStatus: form.get('contractStatus'), accreditationStatus: form.get('accreditationStatus'),
      accessScopes: String(form.get('accessScopes') ?? '').split(',').map((item) => item.trim()).filter(Boolean),
      conflictDomains: String(form.get('conflictDomains') ?? '').split(',').map((item) => item.trim()).filter(Boolean),
      expiresAt: form.get('expiresAt') || null,
    });
    formElement.reset();
  }

  async function recordCustomer(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formElement = event.currentTarget;
    const form = new FormData(formElement);
    const tenantId = String(form.get('tenantId') ?? '').trim();
    await submit('/api/v1/authority/customer-acceptance', {
      customerType: form.get('customerType'), ...(tenantId ? { tenantId } : {}),
      unrelatedToOtherTenant: form.get('unrelatedToOtherTenant') === 'on',
      isolationProof: form.get('isolationProof') === 'on', aggregateLotProof: form.get('aggregateLotProof') === 'on',
      evidenceIngestionProof: form.get('evidenceIngestionProof') === 'on', lifecycleProof: form.get('lifecycleProof') === 'on',
      operationalAcceptance: form.get('operationalAcceptance') === 'on', rollbackTested: form.get('rollbackTested') === 'on',
      evidence: { tenantName: form.get('tenantName'), acceptanceReference: form.get('acceptanceReference') },
    });
    formElement.reset();
  }

  async function recordLaunchGate(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    const gateId = String(form.get('gateId') ?? '');
    await submit(`/api/v1/authority/launch-gates/${gateId}`, {
      state: form.get('state'), evidenceFresh: form.get('evidenceFresh') === 'on', killSwitchReady: form.get('killSwitchReady') === 'on',
      approverIdentities: String(form.get('approverIdentities') ?? '').split(',').map((item) => item.trim()).filter(Boolean),
      approvalSignatures: String(form.get('approvalSignatures') ?? '').split(',').map((item) => item.trim()).filter(Boolean),
      activationRecordId: form.get('activationRecordId') || null, keyCeremonyReference: form.get('keyCeremonyReference') || null,
      releaseHashes: String(form.get('releaseHashes') ?? '').split(',').map((item) => item.trim()).filter(Boolean),
      rollbackAuthority: form.get('rollbackAuthority'), activationTimestamp: form.get('activationTimestamp') || null,
      postActivationChecks: String(form.get('postActivationChecks') ?? '').split(',').map((item) => item.trim()).filter(Boolean),
    });
  }

  async function upsertMarkLicense(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formElement = event.currentTarget;
    const form = new FormData(formElement);
    await submit('/api/v1/authority/marks/licenses', {
      licenseNumber: form.get('licenseNumber'), status: form.get('status'),
      credentialTypes: String(form.get('credentialTypes') ?? '').split(',').map((item) => item.trim()).filter(Boolean),
      permittedMedia: String(form.get('permittedMedia') ?? '').split(',').map((item) => item.trim()).filter(Boolean),
      permittedGeography: String(form.get('permittedGeography') ?? '').split(',').map((item) => item.trim()).filter(Boolean),
      effectiveAt: form.get('effectiveAt'), expiresAt: form.get('expiresAt'), renewalState: form.get('renewalState'),
      evidence: { reference: form.get('evidenceReference') },
    });
    formElement.reset();
  }

  async function upsertMarkLocation(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formElement = event.currentTarget;
    const form = new FormData(formElement);
    await submit('/api/v1/authority/marks/locations', {
      locationId: form.get('locationId'), status: form.get('status'),
      permittedMedia: String(form.get('permittedMedia') ?? '').split(',').map((item) => item.trim()).filter(Boolean),
      permittedGeography: String(form.get('permittedGeography') ?? '').split(',').map((item) => item.trim()).filter(Boolean),
      effectiveAt: form.get('effectiveAt'), expiresAt: form.get('expiresAt'), evidence: { reference: form.get('evidenceReference') },
    });
    formElement.reset();
  }

  async function registerArtwork(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formElement = event.currentTarget;
    const form = new FormData(formElement);
    await submit('/api/v1/authority/marks/artwork', {
      id: form.get('id'), version: form.get('version'), artworkDigest: form.get('artworkDigest'), status: form.get('status'),
      permittedMedia: String(form.get('permittedMedia') ?? '').split(',').map((item) => item.trim()).filter(Boolean),
      permittedGeographies: String(form.get('permittedGeographies') ?? '').split(',').map((item) => item.trim()).filter(Boolean),
      effectiveAt: form.get('effectiveAt'),
    });
    formElement.reset();
  }

  async function transitionMark(resourceType: 'license' | 'location' | 'artwork', resourceId: string, action: string) {
    const reason = window.prompt(`Reason for ${action}`)?.trim();
    if (!reason) return;
    await submit(`/api/v1/authority/marks/governance/${resourceType}/${encodeURIComponent(resourceId)}/transition`, { action, reason });
  }

  async function recordStabilization(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formElement = event.currentTarget;
    const form = new FormData(formElement);
    const day = Number(form.get('day'));
    await submit(`/api/v1/authority/stabilization/${day}`, {
      controlDate: form.get('controlDate') || new Date().toISOString().slice(0,10),
      dailyControlsPass: form.get('dailyControlsPass') === 'on', weeklyRiskReview: form.get('weeklyRiskReview') === 'on',
      defectTrend: Number(form.get('defectTrend') ?? 0), incidentsReviewed: form.get('incidentsReviewed') === 'on',
      issuanceHealthy: form.get('issuanceHealthy') === 'on', revocationHealthy: form.get('revocationHealthy') === 'on',
      registryConsistent: form.get('registryConsistent') === 'on', keyHealthy: form.get('keyHealthy') === 'on',
      custosHealthy: form.get('custosHealthy') === 'on', evidenceCustodyHealthy: form.get('evidenceCustodyHealthy') === 'on',
      customerSupportHealthy: form.get('customerSupportHealthy') === 'on', authorityReview: form.get('authorityReview') || null,
      evidence: { reference: form.get('evidenceReference') },
    });
    formElement.reset();
  }

  const mediaActions = useMemo<Record<string, string[]>>(() => ({
    created: ['bind'], bound: ['encode'], encoded: ['inventory'], inventory: ['ship', 'recall'],
    shipped: ['receive', 'recall'], received: ['activate'], active: ['lost', 'recall', 'suppress'],
    lost: ['replace'], recalled: ['destroy'], suppressed: ['destroy'],
  }), []);

  const summary = snapshot?.summary;

  return <div className="ops-dashboard-grid ops-authority-control-grid">
    <section className="ops-panel ops-wide">
      <header><div><span>Original campaign command</span><h2>Launch-to-operate authority</h2></div><em data-state={summary?.productionLaunchAuthorized ? 'completed' : 'blocked'}>{summary?.productionLaunchAuthorized ? 'authorized' : 'fail closed'}</em></header>
      <p role="status">{message}</p>
      <div className="ops-metric-grid ops-authority-metrics">
        <article><span>Category L ready</span><strong>{summary?.categoryReady ?? 0}/{summary?.categoryTotal ?? 24}</strong></article>
        <article><span>G1–G5 approved</span><strong>{summary?.launchReady ?? 0}/{summary?.launchTotal ?? 5}</strong></article>
        <article><span>Active credential media</span><strong>{summary?.activeMedia ?? 0}</strong></article>
        <article><span>Stabilization days</span><strong>{summary?.stabilizationDaysRecorded ?? 0}/90</strong></article>
      </div>
      <p><strong>Mode:</strong> {summary?.authoritative ? 'authoritative control plane' : 'non-authoritative deterministic control plane'} · No silent promotion between Sandbox, Pilot, and Production.</p>
    </section>

    <section className="ops-panel ops-wide">
      <header><div><span>WO-020 · Category L</span><h2>L-001 through L-024 readiness graph</h2></div><em data-state={(summary?.categoryReady ?? 0) === 24 ? 'completed' : 'blocked'}>{summary?.categoryReady ?? 0}/24 ready</em></header>
      <form className="ops-admin-form ops-authority-evidence-form" onSubmit={attachCategoryEvidence}>
        <label>Control<select name="controlId" required>{snapshot?.categoryL.map((item) => <option key={item.id} value={item.id}>{item.id} · {item.name}</option>)}</select></label>
        <label>Evidence ID<input name="evidenceId" required placeholder="EV-L001-001" /></label>
        <label>SHA-256<input name="evidenceDigest" pattern="sha256:[0-9a-f]{64}" placeholder="Auto-generated in Sandbox when blank" /></label>
        <label>Evidence URL<input name="evidenceUrl" type="url" placeholder="https://…" /></label>
        <label>Expiry<input name="expiresAt" type="datetime-local" /></label>
        <label className="ops-inline-check"><input name="verified" type="checkbox" />Cryptographically verified</label>
        <button disabled={busy} type="submit">Attach governed evidence</button>
      </form>
      <ul className="ops-authority-list ops-category-list">{snapshot?.categoryL.map((control) => <li key={control.id}><span><strong>{control.id} · {control.name}</strong><small>Owner: {control.ownerIdentity} · Dependencies: {control.dependencies.join(', ') || 'none'} · Evidence: {control.evidence.length}</small></span><em data-state={control.state === 'READY' ? 'completed' : 'blocked'}>{control.state}</em></li>)}</ul>
    </section>

    <section className="ops-panel">
      <header><div><span>WO-350 · QR/NFC custody</span><h2>Credential media</h2></div></header>
      <form className="ops-admin-form" onSubmit={createMedia}>
        <label>Media type<select name="mediaType" defaultValue="QR"><option>QR</option><option>NFC</option></select></label>
        <label>Credential ID<input name="credentialId" placeholder="Optional until binding" /></label>
        <button disabled={busy} type="submit">Create controlled media</button>
      </form>
      {mediaSecret ? <div className="ops-secret-receipt" role="alert"><strong>Activation code — shown once</strong><code>{mediaSecret}</code><button type="button" onClick={() => void navigator.clipboard.writeText(mediaSecret)}>Copy</button><button type="button" onClick={() => setMediaSecret(null)}>Dismiss</button></div> : null}
      <ul className="ops-authority-list">{snapshot?.media.map((media) => <li key={media.id}><span><strong>{media.mediaType} · {media.id}</strong><small>{media.state} · credential {media.credentialId ?? 'unbound'} · use count {media.useCount ?? 0}</small></span><div className="ops-authority-actions">{(mediaActions[String(media.state)] ?? []).map((action) => <button disabled={busy} key={action} type="button" onClick={() => void transitionMedia(media.id, action)}>{action}</button>)}</div></li>)}</ul>
    </section>

    <section className="ops-panel">
      <header><div><span>WO-430 · External governance</span><h2>Reviewers, partners and vendors</h2></div></header>
      <form className="ops-admin-form" onSubmit={upsertParty}>
        <label>Name<input required name="name" /></label>
        <label>Party type<select name="partyType"><option value="reviewer">Reviewer</option><option value="reviewer-organization">Reviewer organization</option><option value="partner">Partner</option><option value="vendor">Vendor</option></select></label>
        <label>Status<select name="status"><option value="active">Active</option><option value="suspended">Suspended</option><option value="terminated">Terminated</option></select></label>
        <label>Contract<select name="contractStatus"><option value="current">Current</option><option value="pending">Pending</option><option value="expired">Expired</option><option value="terminated">Terminated</option></select></label>
        <label>Accreditation<select name="accreditationStatus"><option value="current">Current</option><option value="pending">Pending</option><option value="restricted">Restricted</option><option value="expired">Expired</option></select></label>
        <label>Expiry<input name="expiresAt" type="date" /></label>
        <label>Access scopes<input name="accessScopes" placeholder="review:read, review:decide" /></label>
        <label>Conflict domains<input name="conflictDomains" placeholder="supplier-a, organization-b" /></label>
        <button disabled={busy} type="submit">Commit governed party</button>
      </form>
      <ul className="ops-authority-list">{snapshot?.parties.map((party) => <li key={party.id}><span><strong>{party.name ?? party.id}</strong><small>{party.partyType} · {party.contractStatus} contract · {party.accreditationStatus} accreditation</small></span><em data-state={party.status === 'active' ? 'completed' : 'blocked'}>{party.status}</em></li>)}</ul>
    </section>

    <section className="ops-panel">
      <header><div><span>WO-600 · Customer acceptance</span><h2>Customer Zero and Customer One</h2></div></header>
      <form className="ops-admin-form" onSubmit={recordCustomer}>
        <label>Customer type<select name="customerType"><option value="customer-zero">Customer Zero</option><option value="customer-one">Unrelated Customer One</option></select></label>
        <label>Tenant ID<input name="tenantId" placeholder="Blank uses active tenant for Customer Zero" /></label>
        <label>Tenant name<input required name="tenantName" /></label>
        <label>Acceptance evidence<input required name="acceptanceReference" /></label>
        <fieldset><legend>Required operational proofs</legend>
          <label><input type="checkbox" name="unrelatedToOtherTenant" />Unrelated tenant</label>
          <label><input type="checkbox" name="isolationProof" />Isolation proof</label>
          <label><input type="checkbox" name="aggregateLotProof" />Aggregate-lot proof</label>
          <label><input type="checkbox" name="evidenceIngestionProof" />Evidence ingestion</label>
          <label><input type="checkbox" name="lifecycleProof" />Lifecycle proof</label>
          <label><input type="checkbox" name="operationalAcceptance" />Operational acceptance</label>
          <label><input type="checkbox" name="rollbackTested" />Rollback tested</label>
        </fieldset>
        <button disabled={busy} type="submit">Record operational acceptance</button>
      </form>
      <ul className="ops-authority-list">{snapshot?.customers.map((customer) => <li key={customer.id}><span><strong>{customer.customerType} · {customer.tenantName}</strong><small>{customer.acceptedAt ?? 'not accepted'} · {customer.authoritative ? 'authoritative' : 'non-authoritative'}</small></span><em data-state={customer.result === 'PASS' ? 'completed' : 'blocked'}>{customer.result}</em></li>)}</ul>
    </section>

    <section className="ops-panel">
      <header><div><span>WO-610 · G1–G5 launch command</span><h2>Activation gates</h2></div></header>
      <form className="ops-admin-form" onSubmit={recordLaunchGate}>
        <label>Gate<select name="gateId">{['G1','G2','G3','G4','G5'].map((gate) => <option key={gate}>{gate}</option>)}</select></label>
        <label>State<select name="state"><option value="pending">Pending</option><option value="approved">Approved</option><option value="denied">Denied</option></select></label>
        <label>Approver identities<input required name="approverIdentities" placeholder="approver-1, approver-2" /></label>
        <label>Approval signatures<input required name="approvalSignatures" placeholder="sig-1, sig-2" /></label>
        <label>Activation record ID<input name="activationRecordId" /></label>
        <label>Key ceremony reference<input name="keyCeremonyReference" /></label>
        <label>Release hashes<input required name="releaseHashes" placeholder="sha256:…, sha256:…" /></label>
        <label>Rollback authority<input required name="rollbackAuthority" /></label>
        <label>Activation time<input name="activationTimestamp" type="datetime-local" /></label>
        <label>Post-activation checks<input name="postActivationChecks" placeholder="status, registry, revocation" /></label>
        <label className="ops-inline-check"><input name="evidenceFresh" type="checkbox" />Evidence fresh</label>
        <label className="ops-inline-check"><input name="killSwitchReady" type="checkbox" />Kill switch verified</label>
        <button disabled={busy} type="submit">Record signed gate decision</button>
      </form>
      <ul className="ops-authority-list">{snapshot?.launchGates.map((gate) => <li key={gate.id}><span><strong>{gate.id}</strong><small>Evidence {gate.evidenceFresh ? 'fresh' : 'stale/missing'} · kill switch {gate.killSwitchReady ? 'ready' : 'not ready'} · approver {gate.approverIdentity ?? 'unassigned'}</small></span><em data-state={gate.state === 'approved' && gate.evidenceFresh && gate.killSwitchReady ? 'completed' : 'blocked'}>{gate.state}</em></li>)}</ul>
    </section>

    <section className="ops-panel ops-wide">
      <header><div><span>H-012 · Certification-mark authority</span><h2>License, location and artwork governance</h2></div><em data-state="blocked">separate authority</em></header>
      <div className="ops-mark-governance-grid">
        <div>
          <form className="ops-admin-form" onSubmit={upsertMarkLicense}>
            <label>License number<input required name="licenseNumber" /></label>
            <label>Status<select name="status"><option value="active">Active</option><option value="suspended">Suspended</option><option value="expired">Expired</option><option value="terminated">Terminated</option></select></label>
            <label>Credential types<input required name="credentialTypes" placeholder="origin, custody" /></label>
            <label>Permitted media<input required name="permittedMedia" placeholder="digital, print, qr, nfc" /></label>
            <label>Geography<input required name="permittedGeography" placeholder="US, EU" /></label>
            <label>Renewal state<select name="renewalState"><option value="current">Current</option><option value="pending">Pending</option><option value="renewed">Renewed</option></select></label>
            <label>Effective<input required name="effectiveAt" type="datetime-local" /></label>
            <label>Expires<input required name="expiresAt" type="datetime-local" /></label>
            <label>Evidence reference<input required name="evidenceReference" /></label>
            <button disabled={busy} type="submit">Commit mark license</button>
          </form>
          <ul className="ops-authority-list">{snapshot?.markLicenses.map((license) => <li key={license.id}><span><strong>{license.licenseNumber ?? license.id}</strong><small>{license.renewalState} · expires {license.expiresAt}</small></span><div className="ops-authority-actions"><em data-state={license.status === 'active' ? 'completed' : 'blocked'}>{license.status}</em>{license.status === 'active' ? <button type="button" onClick={() => void transitionMark('license', license.id, 'suspend')}>Suspend</button> : <button type="button" onClick={() => void transitionMark('license', license.id, 'activate')}>Activate</button>}<button type="button" onClick={() => void transitionMark('license', license.id, 'terminate')}>Terminate</button></div></li>)}</ul>
        </div>
        <div>
          <form className="ops-admin-form" onSubmit={upsertMarkLocation}>
            <label>Location UUID<input required name="locationId" /></label>
            <label>Status<select name="status"><option value="active">Active</option><option value="suspended">Suspended</option><option value="expired">Expired</option><option value="terminated">Terminated</option></select></label>
            <label>Permitted media<input required name="permittedMedia" placeholder="digital, print, qr, nfc" /></label>
            <label>Geography<input required name="permittedGeography" placeholder="US, EU" /></label>
            <label>Effective<input required name="effectiveAt" type="datetime-local" /></label>
            <label>Expires<input required name="expiresAt" type="datetime-local" /></label>
            <label>Evidence reference<input required name="evidenceReference" /></label>
            <button disabled={busy} type="submit">Commit location authority</button>
          </form>
          <ul className="ops-authority-list">{snapshot?.locationAuthorizations.map((location) => <li key={location.id}><span><strong>{location.locationId ?? location.id}</strong><small>expires {location.expiresAt}</small></span><div className="ops-authority-actions"><em data-state={location.status === 'active' ? 'completed' : 'blocked'}>{location.status}</em>{location.status === 'active' ? <button type="button" onClick={() => void transitionMark('location', location.id, 'suspend')}>Suspend</button> : <button type="button" onClick={() => void transitionMark('location', location.id, 'activate')}>Activate</button>}</div></li>)}</ul>
        </div>
        <div>
          <form className="ops-admin-form" onSubmit={registerArtwork}>
            <label>Artwork ID<input required name="id" /></label>
            <label>Version<input required name="version" /></label>
            <label>SHA-256<input required name="artworkDigest" pattern="sha256:[0-9a-f]{64}" /></label>
            <label>Status<select name="status"><option value="active">Active</option><option value="recalled">Recalled</option><option value="retired">Retired</option></select></label>
            <label>Permitted media<input required name="permittedMedia" /></label>
            <label>Geographies<input required name="permittedGeographies" /></label>
            <label>Effective<input required name="effectiveAt" type="datetime-local" /></label>
            <button disabled={busy} type="submit">Register immutable artwork</button>
          </form>
          <ul className="ops-authority-list">{snapshot?.artwork.map((artwork) => <li key={artwork.id}><span><strong>{artwork.version ?? artwork.id}</strong><small>{artwork.artworkDigest}</small></span><div className="ops-authority-actions"><em data-state={artwork.status === 'active' ? 'completed' : 'blocked'}>{artwork.status}</em>{artwork.status === 'active' ? <button type="button" onClick={() => void transitionMark('artwork', artwork.id, 'recall')}>Recall</button> : null}</div></li>)}</ul>
        </div>
      </div>
    </section>

    <section className="ops-panel">
      <header><div><span>WO-620 · Days 1–90</span><h2>Stabilization controls</h2></div></header>
      <form className="ops-admin-form" onSubmit={recordStabilization}>
        <label>Day<input required name="day" type="number" min="1" max="90" /></label>
        <label>Control date<input required name="controlDate" type="date" /></label>
        <label>Defect trend<input required name="defectTrend" type="number" min="0" /></label>
        <label>Authority review<select name="authorityReview"><option value="">Not scheduled</option><option value="pass">Pass</option><option value="fail">Fail</option></select></label>
        <label>Evidence reference<input required name="evidenceReference" /></label>
        <fieldset><legend>Daily control health</legend>
          <label><input type="checkbox" name="dailyControlsPass" />Daily controls pass</label>
          <label><input type="checkbox" name="weeklyRiskReview" />Weekly risk review</label>
          <label><input type="checkbox" name="incidentsReviewed" />Incidents reviewed</label>
          <label><input type="checkbox" name="issuanceHealthy" />Issuance healthy</label>
          <label><input type="checkbox" name="revocationHealthy" />Revocation healthy</label>
          <label><input type="checkbox" name="registryConsistent" />Registry consistent</label>
          <label><input type="checkbox" name="keyHealthy" />Key healthy</label>
          <label><input type="checkbox" name="custosHealthy" />CUSTOS healthy</label>
          <label><input type="checkbox" name="evidenceCustodyHealthy" />Evidence custody healthy</label>
          <label><input type="checkbox" name="customerSupportHealthy" />Support healthy</label>
        </fieldset>
        <button disabled={busy} type="submit">Commit stabilization record</button>
      </form>
      <ul className="ops-authority-list">{snapshot?.stabilization.map((row) => <li key={row.day}><span><strong>Day {row.day} · {row.controlType}</strong><small>{row.riskLevel} risk · {row.recordedAt}</small></span><em data-state={row.result === 'PASS' ? 'completed' : 'blocked'}>{row.result}</em></li>)}</ul>
    </section>
  </div>;
}
