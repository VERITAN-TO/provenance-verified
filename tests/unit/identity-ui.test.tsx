import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { CorporateLockup, CorporateMark } from '@/identity/CorporateIdentity';
import { TierSeal } from '@/ui/TierSeal';

describe('R5 identity projections', () => {
  it('renders the corporate identity independently from certification seals', () => {
    render(<><CorporateLockup /><CorporateMark /></>);
    expect(screen.getByAltText('PROVENANCE VERIFIED™')).toHaveAttribute('src', expect.stringContaining('provenance-lockup-horizontal.svg'));
    expect(screen.getByAltText('PROVENANCE VERIFIED™ corporate master mark')).toHaveAttribute('src', expect.stringContaining('provenance-master-mark.svg'));
  });

  it('renders the exact controlled seal only when mark use is authorized', () => {
    const { rerender } = render(<TierSeal tier={4} authorized />);
    expect(screen.getByAltText('Provenance Verified™ Tier 4 — Gold certification seal')).toHaveAttribute('src', expect.stringContaining('tier-4-gold-display.svg'));

    rerender(<TierSeal tier={4} authorized={false} />);
    expect(screen.queryByAltText(/certification seal/i)).not.toBeInTheDocument();
    expect(screen.getByLabelText(/Eligible Tier 4 — Gold; credential or certification mark not authorized/i)).toBeInTheDocument();
  });
});
