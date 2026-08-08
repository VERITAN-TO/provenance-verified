import type { CertificationTier } from '@/domain/types';

export const corporateAssets = {
  lockupHorizontal: '/r5/lockups/provenance-lockup-horizontal.svg',
  lockupStacked: '/r5/lockups/provenance-lockup-stacked.svg',
  symbol: '/r5/lockups/provenance-symbol-only.svg',
  wordmark: '/r5/lockups/provenance-wordmark-only.svg',
  masterMark: '/r5/marks/provenance-master-mark.svg',
  masterMarkFallback: '/r5/marks/provenance-master-mark-fallback.svg',
} as const;

export const certificationSealAssets: Record<CertificationTier, { display: string; compact: string; label: string }> = {
  1: { display: '/r5/seals/01_provenance-verified-tier-1-self-reported-display.svg', compact: '/r5/seals/01_provenance-verified-tier-1-self-reported-compact.svg', label: 'Tier 1 — Self-Reported' },
  2: { display: '/r5/seals/02_provenance-verified-tier-2-bronze-display.svg', compact: '/r5/seals/02_provenance-verified-tier-2-bronze-compact.svg', label: 'Tier 2 — Bronze' },
  3: { display: '/r5/seals/03_provenance-verified-tier-3-silver-display.svg', compact: '/r5/seals/03_provenance-verified-tier-3-silver-compact.svg', label: 'Tier 3 — Silver' },
  4: { display: '/r5/seals/04_provenance-verified-tier-4-gold-display.svg', compact: '/r5/seals/04_provenance-verified-tier-4-gold-compact.svg', label: 'Tier 4 — Gold' },
};
