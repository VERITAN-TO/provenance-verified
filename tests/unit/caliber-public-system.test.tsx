import { fireEvent, render, screen } from '@testing-library/react';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { DocsIndex } from '@/ui/DocsIndex';
import { DeveloperWorkbench } from '@/ui/DeveloperWorkbench';
import { SignInAccess } from '@/ui/SignInAccess';

const push = vi.fn();
vi.mock('next/navigation', () => ({ useRouter: () => ({ push }) }));

describe('caliber public website interactions', () => {
  beforeEach(() => { push.mockReset(); window.localStorage.clear(); });

  it('searches documentation and exposes a designed empty state', () => {
    render(<DocsIndex />);
    const input = screen.getByLabelText('Search documentation');
    fireEvent.change(input, { target: { value: 'webhook' } });
    expect(screen.getByText(/result/i)).toBeInTheDocument();
    fireEvent.change(input, { target: { value: 'not-a-real-provenance-topic' } });
    expect(screen.getByText(/No documentation matched/)).toBeInTheDocument();
    fireEvent.click(screen.getByRole('button', { name: 'Clear search' }));
    expect(input).toHaveValue('');
  });

  it('switches developer examples while keeping the MCP boundary truthful', () => {
    render(<DeveloperWorkbench />);
    fireEvent.click(screen.getByRole('tab', { name: 'MCP' }));
    expect(screen.getByText(/runtime not deployed/)).toBeInTheDocument();
    expect(screen.getByText('CONTRACT ONLY')).toBeInTheDocument();
  });

  it('persists an explicit Test Mode role before entering operations', () => {
    render(<SignInAccess />);
    fireEvent.change(screen.getByLabelText('Operational role'), { target: { value: 'session_compliance' } });
    fireEvent.click(screen.getByRole('button', { name: 'Enter operational Test Mode' }));
    expect(window.localStorage.getItem('pv-test-session-id')).toBe('session_compliance');
    expect(push).toHaveBeenCalledWith('/app');
  });
});
