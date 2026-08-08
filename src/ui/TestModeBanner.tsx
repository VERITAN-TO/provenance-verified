'use client';
import { useProvenanceStore } from '@/store/useProvenanceStore';
import { getPublicEnvironment } from '@/authority/public-mode';

export function TestModeBanner() {
  const noWebGL = useProvenanceStore((s) => s.noWebGL);
  const reducedMotion = useProvenanceStore((s) => s.reducedMotion);
  const setNoWebGL = useProvenanceStore((s) => s.setNoWebGL);
  const setReducedMotion = useProvenanceStore((s) => s.setReducedMotion);
  const environment = getPublicEnvironment();
  const labels = [
    'SYSTEM STATUS: INTERNAL / LOCAL / PLUG-IN READY',
    'STAGING STATUS: NOT DEPLOYED',
    'PRODUCTION AUTHORITY: DISABLED',
    'TM-GATE-01: BLOCKED',
  ];
  return (
    <div className="test-banner" role="region" aria-label={`${environment} environment boundary`} data-environment={environment}>
      <div className="test-banner-labels">{labels.map((label) => <strong key={label}>{label}</strong>)}</div>
      <div className="test-banner-actions">
        <label><input aria-label="Disable WebGL" type="checkbox" checked={noWebGL} onChange={(e) => setNoWebGL(e.target.checked)} /> No WebGL</label>
        <label><input aria-label="Enable reduced motion" type="checkbox" checked={reducedMotion} onChange={(e) => setReducedMotion(e.target.checked)} /> Reduced motion</label>
      </div>
    </div>
  );
}
