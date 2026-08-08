'use client';
import { useEffect, useMemo, useRef, useState } from 'react';
import { useProvenanceStore } from '@/store/useProvenanceStore';
import { ProvenanceIdentityScene } from '@/identity/identity3d';
import { resolveIdentityState } from '@/identity/state';
import { CorporateMark } from '@/identity/CorporateIdentity';

export function SpatialEnvironment({ paused = false }: { paused?: boolean }) {
  const hostRef = useRef<HTMLDivElement>(null);
  const sceneRef = useRef<ProvenanceIdentityScene | null>(null);
  const noWebGL = useProvenanceStore((s) => s.noWebGL);
  const reducedMotion = useProvenanceStore((s) => s.reducedMotion);
  const stageIndex = useProvenanceStore((s) => s.stageIndex);
  const runState = useProvenanceStore((s) => s.runState);
  const lifecycle = useProvenanceStore((s) => s.credential.lifecycle);
  const issuanceStatus = useProvenanceStore((s) => s.credential.authorization.status);
  const blockers = useProvenanceStore((s) => s.credential.authorization.blockers);
  const [failed, setFailed] = useState(false);
  const identityState = useMemo(() => resolveIdentityState({ stageIndex, runState, lifecycle, issuanceStatus, blockers }), [stageIndex, runState, lifecycle, issuanceStatus, blockers]);

  useEffect(() => {
    if (!hostRef.current || noWebGL) return;
    // The scene is created once per WebGL mode. State, motion preference, and pause are synchronized by the effects below.
    let scene: ProvenanceIdentityScene | null = null;
    try {
      scene = new ProvenanceIdentityScene(hostRef.current, { opticalTier: 'master', quality: 'hero', initialState: identityState, interactive: true, transparent: true, certificationTier: 0, ariaPrefix: 'Live proof object. ', showGlyph: true, motionSpeed: 1.2 });
      scene.canvas.dataset.testid = 'spatial-canvas';
      scene.setReducedMotion(reducedMotion);
      if (paused) scene.pause();
      sceneRef.current = scene;
      queueMicrotask(() => setFailed(false));
    } catch { queueMicrotask(() => setFailed(true)); }
    const onLost = () => setFailed(true);
    const onRestored = () => setFailed(false);
    const onVisibility = () => {
      if (!sceneRef.current) return;
      if (document.hidden) sceneRef.current.pause();
      else if (!paused) sceneRef.current.resume();
    };
    scene?.canvas.addEventListener('webglcontextlost', onLost);
    scene?.canvas.addEventListener('webglcontextrestored', onRestored);
    document.addEventListener('visibilitychange', onVisibility);
    return () => { scene?.canvas.removeEventListener('webglcontextlost', onLost); scene?.canvas.removeEventListener('webglcontextrestored', onRestored); document.removeEventListener('visibilitychange', onVisibility); scene?.dispose(); sceneRef.current = null; };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [noWebGL]);
  useEffect(() => { sceneRef.current?.setState(identityState); }, [identityState]);
  useEffect(() => { sceneRef.current?.setReducedMotion(reducedMotion); }, [reducedMotion]);
  useEffect(() => { if (!sceneRef.current) return; if (paused) sceneRef.current.pause(); else sceneRef.current.resume(); }, [paused]);

  const fallback = noWebGL || failed;
  return <div className={fallback ? "spatial-environment is-fallback" : "spatial-environment"} data-state={identityState}><div className="spatial-static-base" aria-hidden={!fallback}><CorporateMark className="spatial-fallback-mark" priority /><span>{fallback ? (noWebGL ? "STATIC IDENTITY / WEBGL DISABLED" : "STATIC IDENTITY / RENDERER UNAVAILABLE") : "R5 CORPORATE MASTER MARK"}</span></div><div ref={hostRef} className={fallback ? "spatial-host spatial-host-hidden" : "spatial-host"} />{fallback && <span className="sr-only" data-testid="spatial-fallback">Static R5 identity fallback is active.</span>}<div className="witness-light" /><div className="evidence-plane" /></div>;
}
