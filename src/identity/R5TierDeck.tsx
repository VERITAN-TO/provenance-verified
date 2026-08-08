'use client';

import Image from 'next/image';
import Link from 'next/link';
import { useEffect, useRef, useState } from 'react';
import type { CertificationTier } from '@/domain/types';
import { certificationSealAssets } from './assets';
import { R5IdentityObject } from './R5IdentityObject';

const tiers: Array<{ tier: CertificationTier; label: string; description: string }> = [
  { tier: 1, label: 'Self-Reported', description: 'Asset fingerprint and declared record. No independent corroboration.' },
  { tier: 2, label: 'Bronze', description: 'Legally accountable attestation. Signature does not create independence.' },
  { tier: 3, label: 'Silver', description: 'Independent corroboration for explicitly supported claims.' },
  { tier: 4, label: 'Gold', description: 'Complete documented provenance chain with dual review and authority gates.' },
];

export function R5TierDeck({ compact = false }: { compact?: boolean }) {
  const rootRef = useRef<HTMLDivElement>(null);
  const [activeTier, setActiveTier] = useState<CertificationTier>(4);
  const [running, setRunning] = useState(false);
  const [paused, setPaused] = useState(false);

  useEffect(() => {
    const root = rootRef.current;
    if (!root || typeof IntersectionObserver === 'undefined') {
      setRunning(true);
      return;
    }
    const observer = new IntersectionObserver(([entry]) => setRunning(Boolean(entry?.isIntersecting)), { rootMargin: '180px 0px', threshold: 0.08 });
    observer.observe(root);
    return () => observer.disconnect();
  }, []);

  useEffect(() => {
    if (!running || paused) return;
    const timer = window.setInterval(() => setActiveTier((current) => (current === 4 ? 1 : current + 1) as CertificationTier), 6200);
    return () => window.clearInterval(timer);
  }, [paused, running]);

  const active = tiers.find((item) => item.tier === activeTier)!;

  return (
    <div
      ref={rootRef}
      className={`r5-tier-deck ${compact ? 'is-compact' : ''}`}
      data-active-tier={activeTier}
      onPointerEnter={() => setPaused(true)}
      onPointerLeave={() => setPaused(false)}
      onFocusCapture={() => setPaused(true)}
      onBlurCapture={(event) => { if (!event.currentTarget.contains(event.relatedTarget as Node | null)) setPaused(false); }}
    >
      <div className="r5-tier-deck-stage">
        <div className="r5-tier-deck-live-object">
          <R5IdentityObject
            key={`r5-certification-${activeTier}`}
            variant="certification"
            tier={activeTier}
            compact={compact}
            interactive={!compact}
            priority
            label={`Live R5 Three.js Provenance Verified Tier ${activeTier} ${active.label} certification seal`}
          />
        </div>
        <div className="r5-tier-deck-copy" aria-live="polite">
          <span>PROVENANCE VERIFIED™ / TIER 0{activeTier}</span>
          <h3>{active.label}</h3>
          <p>{active.description}</p>
          <small>Real R5 certification geometry · Three.js · exact controlled SVG fallback</small>
        </div>
      </div>
      <div className="r5-tier-deck-controls" role="tablist" aria-label="Provenance Verified certification tiers">
        {tiers.map((item) => (
          <button
            key={item.tier}
            type="button"
            role="tab"
            aria-selected={activeTier === item.tier}
            onClick={() => setActiveTier(item.tier)}
          >
            <Image src={certificationSealAssets[item.tier].compact} alt="" width={96} height={96} unoptimized />
            <span>0{item.tier}</span>
            <strong>{item.label}</strong>
            {!compact && <small>{item.description}</small>}
            <i aria-hidden="true" />
          </button>
        ))}
      </div>
      <div className="r5-tier-deck-footer">
        <span>{running ? (paused ? 'LIVE R5 / INSPECTION PAUSED' : 'LIVE R5 / AUTO-CYCLING FOUR-TIER SCENE') : 'R5 SCENE ARMED'}</span>
        <Link href="/provenance-verified">Inspect requirements ↗</Link>
      </div>
    </div>
  );
}
