'use client';

import { useState } from 'react';

export function ContactForm({ mode = 'contact' }: { mode?: 'contact' | 'access' }) {
  const [state, setState] = useState<{ status: 'idle' | 'submitting' | 'success' | 'error'; receiptId?: string; message?: string }>({ status: 'idle' });

  async function submit(form: HTMLFormElement) {
    const values = Object.fromEntries(new FormData(form).entries());
    setState({ status: 'submitting' });
    try {
      const response = await fetch('/api/v1/inquiries', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ mode, ...values, consent: values.consent === 'on', consentPolicyVersion: 'privacy-r3.1' }),
      });
      const body = await response.json();
      if (!response.ok) throw new Error(body.error?.message ?? 'The request was not accepted.');
      setState({ status: 'success', receiptId: body.data.receiptId });
    } catch (error) {
      setState({ status: 'error', message: error instanceof Error ? error.message : 'The request was not accepted.' });
    }
  }

  if (state.status === 'success') return (
    <div className="form-success" role="status">
      <span>INQUIRY RECEIPT</span>
      <strong>Request validated and recorded.</strong>
      <code>{state.receiptId}</code>
      <p>The receipt confirms intake only. It does not create an account, credential, pilot authorization, or certification decision.</p>
      <button type="button" onClick={() => setState({ status: 'idle' })}>Record another request</button>
    </div>
  );

  return (
    <form className="contact-form" onSubmit={(event) => { event.preventDefault(); void submit(event.currentTarget); }}>
      <label>Full name<input required name="name" autoComplete="name" /></label>
      <label>Organization<input required name="organization" autoComplete="organization" /></label>
      <label>Email<input required type="email" name="email" autoComplete="email" /></label>
      <label className="sr-only" aria-hidden="true">Website<input name="website" tabIndex={-1} autoComplete="off" /></label>
      <label>{mode === 'access' ? 'Integration objective' : 'Message'}<textarea required name="message" rows={6} minLength={20} /></label>
      {mode === 'access' && <label>Primary workflow<select required name="workflow" defaultValue=""><option value="" disabled>Select a workflow</option><option>Verification API</option><option>Public registry</option><option>Evidence onboarding</option><option>Certification operations</option><option>Webhook and event integration</option></select></label>}
      <label className="contact-consent"><input required type="checkbox" name="consent" /> I agree that PROVENANCE VERIFIED™ may process this inquiry under the privacy policy.</label>
      {state.status === 'error' && <p className="form-error" role="alert">{state.message}</p>}
      <button className="button button-primary" type="submit" disabled={state.status === 'submitting'}>{state.status === 'submitting' ? 'Validating request…' : mode === 'access' ? 'Request pilot access' : 'Send inquiry'}</button>
      <small>Sandbox records locally without delivery. Pilot and Production encrypt and queue the inquiry through the authority plane.</small>
    </form>
  );
}
