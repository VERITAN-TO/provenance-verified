import { describe, expect, it } from 'vitest';
import { POST } from '@/app/api/v1/inquiries/route';

describe('inquiry contract', () => {
  it('records a deterministic Test Mode receipt without claiming delivery', async () => {
    const response = await POST(new Request('http://test/api/v1/inquiries', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ mode: 'access', name: 'Avery Stone', organization: 'Northstar Jewelry Group', email: 'avery@example.com', message: 'Evaluate the verification and registry workflow for a controlled jeweler pilot.', workflow: 'Verification API', consent: true, consentPolicyVersion: 'privacy-r3.1' }) }));
    const body = await response.json();
    expect(response.status).toBe(202);
    expect(body.data.status).toBe('recorded-sandbox');
    expect(body.meta.delivered).toBe(false);
    expect(body.meta.productionMessageCreated).toBe(false);
  });

  it('rejects incomplete inquiry payloads', async () => {
    const response = await POST(new Request('http://test/api/v1/inquiries', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ mode: 'contact', name: 'A', organization: '', email: 'invalid', message: 'short' }) }));
    const body = await response.json();
    expect(response.status).toBe(422);
    expect(body.error.code).toBe('invalid_inquiry');
  });
});
