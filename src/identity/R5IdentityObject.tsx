'use client';

import Image from 'next/image';
import { useEffect, useMemo, useRef, useState } from 'react';
import type { CertificationTier } from '@/domain/types';
import { useProvenanceStore } from '@/store/useProvenanceStore';
import { ProvenanceIdentityScene } from './identity3d';
import { certificationSealAssets, corporateAssets } from './assets';

export type R5IdentityVariant = 'corporate' | 'certification';

interface R5IdentityObjectProps {
  variant?: R5IdentityVariant;
  tier?: CertificationTier;
  compact?: boolean;
  interactive?: boolean;
  className?: string;
  priority?: boolean;
  label?: string;
}

// No separate capability probe: ProvenanceIdentityScene's own constructor already
// creates a real WebGL context and fails closed (caught below) if unavailable — an
// R5IdentityObject-only probe context was redundant work that, under software
// rendering, contended with the main SpatialEnvironment scene's concurrent
// construction and was the dominant cost in a measured multi-second stall.

// A page can render several R5IdentityObject instances (corporate marks, certification
// seals) whose IntersectionObserver callbacks are batched together by the browser, so
// without this they'd all attempt WebGL context creation in the same synchronous burst
// — a real jank source on software rendering, not just a test artifact. Serialize scene
// construction across every instance and yield one animation frame between each so the
// browser can actually paint/respond in between, instead of one long blocking task.
let sceneConstructionQueue: Promise<void> = Promise.resolve();
function scheduleSceneConstruction(build: () => void): void {
  sceneConstructionQueue = sceneConstructionQueue.then(
    () => new Promise<void>((resolve) => {
      requestAnimationFrame(() => { build(); resolve(); });
    })
  );
}


export function R5IdentityObject({
  variant = 'corporate',
  tier,
  compact = false,
  interactive = false,
  className = '',
  priority = false,
  label,
}: R5IdentityObjectProps) {
  const hostRef = useRef<HTMLDivElement>(null);
  const sceneRef = useRef<ProvenanceIdentityScene | null>(null);
  const [renderMode, setRenderMode] = useState<'fallback' | 'live' | 'failed'>('fallback');
  const noWebGL = useProvenanceStore((state) => state.noWebGL);
  const reducedMotion = useProvenanceStore((state) => state.reducedMotion);
  const certificationTier = variant === 'certification' ? (tier ?? 1) : 0;

  const fallbackAsset = useMemo(() => {
    if (variant === 'certification') {
      const seal = certificationSealAssets[tier ?? 1];
      return compact ? seal.compact : seal.display;
    }
    return corporateAssets.masterMark;
  }, [compact, tier, variant]);

  const accessibleLabel = label ?? (variant === 'certification'
    ? `Provenance Verified™ ${certificationSealAssets[tier ?? 1].label} live R5 certification seal`
    : 'PROVENANCE VERIFIED™ live R5 corporate master mark');

  useEffect(() => {
    const host = hostRef.current;
    if (!host || noWebGL) {
      setRenderMode('fallback');
      return;
    }

    let scene: ProvenanceIdentityScene | null = null;
    let disposed = false;
    let visible = false;
    // bindTimer below polls until it knows the outcome. Without this, a failed
    // construction (scene stays null, e.g. no WebGL support) left it polling forever —
    // a real, pre-existing timer leak, not just a test artifact; it happened to be
    // masked in test environments only because the old capability probe short-circuited
    // the whole effect before this code ever ran there.
    let constructionSettled = false;

    const createScene = () => {
      if (scene || disposed) return;
      scheduleSceneConstruction(() => {
        if (scene || disposed) return;
        try {
          scene = new ProvenanceIdentityScene(host, {
            opticalTier: compact ? 'micro' : certificationTier ? 'compact' : 'master',
            quality: compact ? 'mini' : 'standard',
            initialState: certificationTier ? 'approve' : 'verify',
            interactive: interactive && !reducedMotion,
            transparent: true,
            certificationTier,
            ariaPrefix: `${accessibleLabel}. `,
            showGlyph: certificationTier === 0,
            motionSpeed: certificationTier ? 0.72 : 0.9,
          });
          scene.canvas.dataset.r5Identity = variant;
          scene.canvas.dataset.r5Tier = String(certificationTier);
          scene.canvas.setAttribute('aria-hidden', 'true');
          scene.setReducedMotion(reducedMotion);
          if (!visible) scene.pause();
          sceneRef.current = scene;
          setRenderMode('live');
        } catch {
          setRenderMode('failed');
        } finally {
          constructionSettled = true;
        }
      });
    };

    const observer = typeof IntersectionObserver === 'undefined'
      ? null
      : new IntersectionObserver((entries) => {
          const entry = entries[0];
          visible = Boolean(entry?.isIntersecting);
          if (visible) {
            createScene();
            scene?.resume();
          } else {
            scene?.pause();
          }
        }, { rootMargin: '180px 0px', threshold: 0.02 });

    if (observer) observer.observe(host);
    else {
      visible = true;
      createScene();
    }

    const onLost = () => setRenderMode('failed');
    const onRestored = () => {
      scene?.renderOnce();
      setRenderMode('live');
    };

    const bindContextEvents = () => {
      if (!scene) return;
      scene.canvas.addEventListener('webglcontextlost', onLost);
      scene.canvas.addEventListener('webglcontextrestored', onRestored);
    };

    const bindTimer = window.setInterval(() => {
      if (scene) {
        bindContextEvents();
        window.clearInterval(bindTimer);
      } else if (constructionSettled) {
        window.clearInterval(bindTimer);
      }
    }, 40);

    return () => {
      disposed = true;
      window.clearInterval(bindTimer);
      observer?.disconnect();
      if (scene) {
        scene.canvas.removeEventListener('webglcontextlost', onLost);
        scene.canvas.removeEventListener('webglcontextrestored', onRestored);
        scene.dispose();
      }
      sceneRef.current = null;
    };
  }, [accessibleLabel, certificationTier, compact, interactive, noWebGL, reducedMotion, variant]);

  useEffect(() => {
    sceneRef.current?.setReducedMotion(reducedMotion);
  }, [reducedMotion]);

  return (
    <span
      className={`r5-identity-object r5-identity-${variant} ${compact ? 'is-compact' : ''} ${className}`.trim()}
      data-render-mode={renderMode}
      data-certification-tier={certificationTier}
      role="img"
      aria-label={accessibleLabel}
    >
      <Image
        className="r5-identity-fallback"
        src={fallbackAsset}
        alt={variant === 'certification'
          ? `Provenance Verified™ ${certificationSealAssets[tier ?? 1].label} certification seal`
          : 'PROVENANCE VERIFIED™ corporate master mark'}
        width={compact ? 128 : 640}
        height={compact ? 128 : 640}
        priority={priority}
        unoptimized
      />
      <span ref={hostRef} className="r5-identity-webgl" aria-hidden="true" />
      <span className="r5-identity-status" aria-hidden="true">
        {renderMode === 'live' ? 'LIVE R5 / THREE.JS' : renderMode === 'failed' ? 'R5 STATIC FALLBACK' : 'R5 IDENTITY'}
      </span>
    </span>
  );
}
