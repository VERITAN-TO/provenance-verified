import { act, fireEvent, render, screen } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { useProvenanceStore } from '@/store/useProvenanceStore';
import { TierEducationChamber } from '@/ui/phase3/TierEducationChamber';
import { VerificationTransaction } from '@/ui/phase3/VerificationTransaction';
import { DeveloperContractChapter } from '@/ui/phase3/DeveloperContractChapter';
import { RegistryRoute } from '@/ui/RegistryRoute';
import { PublicRecord } from '@/ui/PublicRecord';

describe('Phase 3 public proof system', () => {
  beforeEach(() => {
    useProvenanceStore.getState().selectFixture('t4');
    useProvenanceStore.getState().setReducedMotion(true);
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.unstubAllGlobals();
  });

  it('keeps educational tier switching separate from certification-mark authorization', () => {
    useProvenanceStore.getState().selectFixture('t4MarkPending');
    render(<TierEducationChamber />);
    fireEvent.click(screen.getByRole('tab', { name: /Bronze/i }));
    expect(screen.getByRole('heading', { name: /Tier 2 · Bronze/i })).toBeInTheDocument();
    expect(screen.getByText(/EDUCATION ONLY · NOT ISSUANCE/i)).toBeInTheDocument();
    expect(screen.queryByAltText(/certification seal/i)).not.toBeInTheDocument();
    expect(screen.getByText(/No certification seal is authorized/i)).toBeInTheDocument();
  });

  it('projects a blocked Gold case across credential, registry, and mark consequences', () => {
    useProvenanceStore.getState().selectFixture('t4MissingSecondApproval');
    render(<VerificationTransaction />);
    expect(screen.getByText('Not issued')).toBeInTheDocument();
    expect(screen.getByText('Not published')).toBeInTheDocument();
    expect(screen.getByText('Withheld')).toBeInTheDocument();
    expect(screen.getByText(/second independent approval/i)).toBeInTheDocument();
  });

  it('labels MCP as a documented contract rather than a deployed runtime', () => {
    render(<DeveloperContractChapter />);
    fireEvent.click(screen.getByRole('button', { name: 'MCP' }));
    expect(screen.getByText(/CONTRACT DOCUMENTED · RUNTIME NOT DEPLOYED/i)).toBeInTheDocument();
    expect(screen.getByText(/Runtime status: NOT DEPLOYED/i)).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /Change lifecycle/i })).not.toBeInTheDocument();
  });

  it('filters the public registry by lifecycle and keeps unissued records excluded', async () => {
    vi.useFakeTimers();
    vi.stubGlobal('fetch', vi.fn((url: RequestInfo | URL) => {
      const u = typeof url === 'string' ? url : url.toString();
      if (u.includes('q=revoked')) {
        return Promise.resolve(new Response(JSON.stringify({ data: [{ publicId: 'PV-TEST-RV1004', lifecycle: 'revoked', tier: 4, tierName: 'Gold', description: '', claimCount: 0, evidenceCount: 0, markAuthorized: false, authoritative: false }] }), { status: 200 }));
      }
      return Promise.resolve(new Response(JSON.stringify({ data: [] }), { status: 200 }));
    }) as typeof fetch);
    render(<RegistryRoute />);
    fireEvent.change(screen.getByLabelText(/Search current and historical authority/i), { target: { value: 'revoked' } });
    await act(async () => { await vi.runAllTimersAsync(); });
    expect(screen.getByText('PV-TEST-RV1004')).toBeInTheDocument();
    expect(screen.queryByText('PV-TEST-A21008')).not.toBeInTheDocument();
  });

  it('renders claim scope, evidence depth, signed history, and machine projection from one public record', async () => {
    vi.stubGlobal('fetch', vi.fn((url: RequestInfo | URL) => {
      const u = typeof url === 'string' ? url : url.toString();
      if (u.includes('/history')) {
        return Promise.resolve(new Response(JSON.stringify({ data: { publicId: 'PV-TEST-T4D004', versions: [{ version: 1, signingKeyId: '' }], events: [], independentlyRebuildable: true } }), { status: 200 }));
      }
      return Promise.resolve(new Response(JSON.stringify({ data: { tier: 4, lifecycle: 'active', version: 1, claimScope: [] } }), { status: 200 }));
    }) as typeof fetch);
    render(<PublicRecord publicId="PV-TEST-T4D004" />);
    expect(await screen.findByRole('heading', { name: /One credential\. Exact claim outcomes\./i })).toBeInTheDocument();
    expect(screen.getByRole('heading', { name: /Private evidence remains protected/i })).toBeInTheDocument();
    expect(screen.getByRole('heading', { name: /No prior public authority is erased/i })).toBeInTheDocument();
    expect(screen.getByRole('heading', { name: /Current state and history resolve through the same API/i })).toBeInTheDocument();
  });
});
