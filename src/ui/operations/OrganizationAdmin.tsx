'use client';

import { useCallback, useEffect, useState, type FormEvent } from 'react';
import { getPublicEnvironment } from '@/authority/public-mode';
import { authorityFetch } from '@/operations/auth';

type Location = { id: string; code: string; name: string; timezone: string; address: string; active: boolean };
type Membership = { id: string; displayName: string; role: string; status: string; locationIds: string[]; conflictDomains: string[] };
type ApiClient = { id: string; name: string; keyPrefix: string; role: string; scopes: string[]; status: string; expiresAt?: string | null; lastUsedAt?: string | null };
type Webhook = { id: string; url: string; eventTypes: string[]; status: string; secretHint: string; createdAt: string };
type Snapshot = {
  organization: { id: string; legalName: string; displayName: string; status: string };
  locations: Location[];
  memberships: Membership[];
  apiClients: ApiClient[];
  webhooks: Webhook[];
};

type SecretReceipt = { label: string; secret: string } | null;

const roleOptions = ['owner','administrator','intake-operator','evidence-manager','inventory-manager','authorized-attestor','reviewer','compliance-officer','auditor'];
const apiScopes = ['operations:read','operations:write','evidence:write','labels:generate','mcp:execute'];

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await authorityFetch(path, { cache: 'no-store', ...init, headers: { 'content-type': 'application/json', ...(init?.headers ?? {}) } });
  const body = await response.json().catch(() => ({})) as { data?: T; error?: { message?: string; code?: string } };
  if (!response.ok) throw new Error(body.error?.message ?? body.error?.code ?? `REQUEST_FAILED_${response.status}`);
  return body.data as T;
}

export function OrganizationAdmin() {
  const environment = getPublicEnvironment();
  const [snapshot, setSnapshot] = useState<Snapshot | null>(null);
  const [message, setMessage] = useState('Loading organization authority…');
  const [secretReceipt, setSecretReceipt] = useState<SecretReceipt>(null);

  const load = useCallback(async () => {
    if (environment === 'sandbox') {
      setMessage('Organization administration is intentionally disabled in deterministic Test Mode. Use Pilot or Production with authenticated AAL2 identity.');
      return;
    }
    try {
      setMessage('Loading canonical organization state…');
      setSnapshot(await request<Snapshot>('/api/v1/organization'));
      setMessage('Canonical organization state loaded.');
    } catch (error) {
      setMessage(error instanceof Error ? error.message : 'Organization state unavailable.');
    }
  }, [environment]);

  useEffect(() => { void load(); }, [load]);

  async function submit(path: string, payload: Record<string, unknown>, secretLabel?: string) {
    try {
      setMessage('Applying server-authoritative change…');
      const data = await request<Record<string, unknown>>(path, { method: 'POST', body: JSON.stringify(payload) });
      const secret = typeof data.secret === 'string' ? data.secret : null;
      if (secret && secretLabel) setSecretReceipt({ label: secretLabel, secret });
      setMessage('Change committed and attributed in the audit ledger.');
      await load();
    } catch (error) {
      setMessage(error instanceof Error ? error.message : 'Authority change failed closed.');
    }
  }

  async function createLocation(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formElement = event.currentTarget;
    const form = new FormData(formElement);
    await submit('/api/v1/organization/locations', Object.fromEntries(form.entries()));
    formElement.reset();
  }

  async function inviteMember(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formElement = event.currentTarget;
    const form = new FormData(formElement);
    await submit('/api/v1/organization/members/invite', {
      email: form.get('email'), displayName: form.get('displayName'), role: form.get('role'),
      locationIds: form.getAll('locationIds'), conflictDomains: String(form.get('conflictDomains') ?? '').split(',').map((item) => item.trim()).filter(Boolean),
    });
    formElement.reset();
  }

  async function createApiClient(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formElement = event.currentTarget;
    const form = new FormData(formElement);
    await submit('/api/v1/organization/api-clients', {
      name: form.get('name'), role: form.get('role'), scopes: form.getAll('scopes'), expiresAt: form.get('expiresAt') || null,
    }, 'API client secret');
    formElement.reset();
  }

  async function createWebhook(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formElement = event.currentTarget;
    const form = new FormData(formElement);
    await submit('/api/v1/organization/webhooks', { url: form.get('url'), eventTypes: String(form.get('eventTypes') ?? '').split(',').map((item) => item.trim()).filter(Boolean) }, 'Webhook signing secret');
    formElement.reset();
  }

  async function mutate(path: string) {
    try {
      setMessage('Applying revocation…');
      await request(path, { method: 'POST', body: '{}' });
      setMessage('Revocation committed.');
      await load();
    } catch (error) {
      setMessage(error instanceof Error ? error.message : 'Revocation failed closed.');
    }
  }

  async function updateMember(memberId: string, patch: { role?: string; status?: string }) {
    try {
      setMessage('Updating server-authoritative membership…');
      await request(`/api/v1/organization/members/${memberId}`, { method: 'PATCH', body: JSON.stringify(patch) });
      setMessage('Membership authority updated and attributed.');
      await load();
    } catch (error) {
      setMessage(error instanceof Error ? error.message : 'Membership update failed closed.');
    }
  }

  if (environment === 'sandbox') return <section className="ops-panel ops-wide"><span className="ops-kicker">ISOLATED TEST MODE</span><h2>Organization authority is not simulated</h2><p>{message}</p></section>;

  return <div className="ops-dashboard-grid ops-admin-grid">
    <section className="ops-panel ops-wide">
      <header><div><span>Canonical tenant authority</span><h2>{snapshot?.organization.displayName ?? 'Organization'}</h2></div><em data-state={snapshot?.organization.status ?? 'loading'}>{snapshot?.organization.status ?? 'loading'}</em></header>
      <p role="status">{message}</p>
      {secretReceipt && <div className="ops-secret-receipt" role="alert"><strong>{secretReceipt.label} — shown once</strong><code>{secretReceipt.secret}</code><button type="button" onClick={() => void navigator.clipboard.writeText(secretReceipt.secret)}>Copy secret</button><button type="button" onClick={() => setSecretReceipt(null)}>Dismiss</button></div>}
    </section>

    <section className="ops-panel">
      <header><div><span>Physical operating boundary</span><h2>Add location</h2></div></header>
      <form className="ops-admin-form" onSubmit={createLocation}>
        <label>Code<input required name="code" maxLength={16} /></label>
        <label>Name<input required name="name" /></label>
        <label>Timezone<input required name="timezone" placeholder="America/Phoenix" /></label>
        <label>Address<input required name="address" /></label>
        <button type="submit">Create location</button>
      </form>
      <ul className="ops-authority-list">{snapshot?.locations.map((location) => <li key={location.id}><strong>{location.code} · {location.name}</strong><small>{location.timezone} · {location.address}</small></li>)}</ul>
    </section>

    <section className="ops-panel">
      <header><div><span>Human identity and role</span><h2>Invite member</h2></div></header>
      <form className="ops-admin-form" onSubmit={inviteMember}>
        <label>Email<input required name="email" type="email" /></label>
        <label>Display name<input required name="displayName" /></label>
        <label>Role<select name="role" defaultValue="auditor">{roleOptions.map((role) => <option key={role}>{role}</option>)}</select></label>
        <label>Conflict domains<input name="conflictDomains" placeholder="supplier-a, laboratory-b" /></label>
        <fieldset><legend>Location scope</legend>{snapshot?.locations.map((location) => <label key={location.id}><input type="checkbox" name="locationIds" value={location.id} />{location.code}</label>)}</fieldset>
        <button type="submit">Send controlled invitation</button>
      </form>
      <ul className="ops-authority-list">{snapshot?.memberships.map((member) => <li key={member.id}><span><strong>{member.displayName}</strong><small>{member.status} · {member.locationIds.length ? `${member.locationIds.length} location scope(s)` : 'all authorized locations'}</small></span><div className="ops-member-controls"><select aria-label={`Role for ${member.displayName}`} value={member.role} onChange={(event) => void updateMember(member.id, { role: event.target.value })}>{roleOptions.map((role) => <option key={role}>{role}</option>)}</select><button type="button" onClick={() => void updateMember(member.id, { status: member.status === 'active' ? 'suspended' : 'active' })}>{member.status === 'active' ? 'Suspend' : 'Reactivate'}</button></div></li>)}</ul>
    </section>

    <section className="ops-panel">
      <header><div><span>Machine authentication</span><h2>Scoped API clients</h2></div></header>
      <form className="ops-admin-form" onSubmit={createApiClient}>
        <label>Name<input required name="name" /></label>
        <label>Role<select name="role" defaultValue="auditor">{['auditor','intake-operator','evidence-manager','inventory-manager'].map((role) => <option key={role}>{role}</option>)}</select></label>
        <label>Expires<input name="expiresAt" type="datetime-local" /></label>
        <fieldset><legend>Explicit scopes</legend>{apiScopes.map((scope) => <label key={scope}><input type="checkbox" name="scopes" value={scope} />{scope}</label>)}</fieldset>
        <button type="submit">Issue one-time secret</button>
      </form>
      <ul className="ops-authority-list">{snapshot?.apiClients.map((client) => <li key={client.id}><span><strong>{client.name}</strong><small>{client.keyPrefix}… · {client.role} · {client.scopes.join(', ')}</small></span><button disabled={client.status !== 'active'} type="button" onClick={() => void mutate(`/api/v1/organization/api-clients/${client.id}/revoke`)}>{client.status === 'active' ? 'Revoke' : client.status}</button></li>)}</ul>
    </section>

    <section className="ops-panel">
      <header><div><span>Signed delivery boundary</span><h2>Webhooks</h2></div></header>
      <form className="ops-admin-form" onSubmit={createWebhook}>
        <label>HTTPS endpoint<input required name="url" type="url" placeholder="https://example.com/provenance-events" /></label>
        <label>Event types<input required name="eventTypes" defaultValue="credential.authority-complete" /></label>
        <button type="submit">Create encrypted webhook</button>
      </form>
      <ul className="ops-authority-list">{snapshot?.webhooks.map((webhook) => <li key={webhook.id}><span><strong>{webhook.url}</strong><small>{webhook.eventTypes.join(', ')} · {webhook.secretHint}…</small></span><button disabled={webhook.status !== 'active'} type="button" onClick={() => void mutate(`/api/v1/organization/webhooks/${webhook.id}/disable`)}>{webhook.status === 'active' ? 'Disable' : webhook.status}</button></li>)}</ul>
    </section>
  </div>;
}
