'use client';

import { useEffect, useRef, useState } from 'react';

type RuntimeEntry = {
  id: number;
  label: string;
  kind: string;
  state: 'queued' | 'executing' | 'resolved';
};

function describeControl(element: HTMLElement) {
  const href = element instanceof HTMLAnchorElement ? element.getAttribute('href') ?? '' : '';
  const label = element.dataset.liveLabel
    || element.getAttribute('aria-label')
    || element.textContent?.replace(/\s+/g, ' ').trim().slice(0, 64)
    || 'Interface control';
  if (href.startsWith('/api/') || href.includes('/api/')) return { label, kind: 'canonical_api' };
  if (href.startsWith('/app')) return { label, kind: 'operations_route' };
  if (href.startsWith('/registry') || href.startsWith('/verify')) return { label, kind: 'registry_resolution' };
  if (element.getAttribute('role') === 'tab') return { label, kind: 'state_projection' };
  if (element.tagName === 'BUTTON') return { label, kind: 'authority_action' };
  return { label, kind: href ? 'route_transition' : 'interface_action' };
}

export function LivingInterface() {
  const [entries, setEntries] = useState<RuntimeEntry[]>([]);
  const [pulse, setPulse] = useState<{ x: number; y: number; id: number } | null>(null);
  const sequence = useRef(0);

  useEffect(() => {
    const activeTimers: number[] = [];
    const sections = Array.from(document.querySelectorAll<HTMLElement>('main section, main > div'));
    const observer = typeof IntersectionObserver === 'undefined' ? null : new IntersectionObserver((items) => {
      items.forEach((item) => item.target.classList.toggle('pv-is-visible', item.isIntersecting));
    }, { threshold: 0.08, rootMargin: '-8% 0px -8% 0px' });
    if (observer) sections.forEach((section) => observer.observe(section));
    else sections.forEach((section) => section.classList.add('pv-is-visible'));

    let raf = 0;
    const updateScroll = () => {
      cancelAnimationFrame(raf);
      raf = requestAnimationFrame(() => {
        const max = Math.max(1, document.documentElement.scrollHeight - innerHeight);
        document.documentElement.style.setProperty('--pv-page-progress', String(scrollY / max));
        document.querySelectorAll<HTMLElement>('.pv2-section, .pv2-route-body, .p3-chapter').forEach((section) => {
          const rect = section.getBoundingClientRect();
          const local = Math.max(0, Math.min(1, (innerHeight - rect.top) / (innerHeight + rect.height)));
          section.style.setProperty('--pv-local-progress', String(local));
        });
      });
    };

    const onClick = (event: MouseEvent) => {
      const target = event.target instanceof Element ? event.target.closest<HTMLElement>('a[href],button,[role="tab"],[role="option"]') : null;
      if (!target || target.matches('[disabled],[aria-disabled="true"]') || target.classList.contains('skip-link')) return;
      const { label, kind } = describeControl(target);
      const id = ++sequence.current;
      setPulse({ x: event.clientX, y: event.clientY, id });
      setEntries((current) => [...current.slice(-2), { id, label, kind, state: 'queued' }]);
      const first = window.setTimeout(() => setEntries((current) => current.map((entry) => entry.id === id ? { ...entry, state: 'executing' } : entry)), 90);
      const second = window.setTimeout(() => setEntries((current) => current.map((entry) => entry.id === id ? { ...entry, state: 'resolved' } : entry)), 520);
      const third = window.setTimeout(() => setEntries((current) => current.filter((entry) => entry.id !== id)), 2500);
      activeTimers.push(first, second, third);
    };

    window.addEventListener('scroll', updateScroll, { passive: true });
    window.addEventListener('resize', updateScroll, { passive: true });
    document.addEventListener('click', onClick, true);
    updateScroll();
    return () => {
      observer?.disconnect();
      cancelAnimationFrame(raf);
      activeTimers.forEach((timer) => clearTimeout(timer));
      window.removeEventListener('scroll', updateScroll);
      window.removeEventListener('resize', updateScroll);
      document.removeEventListener('click', onClick, true);
    };
  }, []);

  const latest = entries.at(-1);

  return (
    <>
      <div className="pv-page-progress" aria-hidden="true"><i /></div>
      {pulse && <span key={pulse.id} className="pv-interaction-pulse" style={{ left: pulse.x, top: pulse.y }} aria-hidden="true" />}
      <aside className={latest ? 'pv-runtime-console is-active' : 'pv-runtime-console'} aria-live="polite" aria-label="Live interface execution">
        <header><span><i />LIVE INTERFACE</span><b>{latest ? latest.state.toUpperCase() : 'READY'}</b></header>
        <div>
          {latest ? (
            <p key={latest.id} data-state={latest.state}><code>{latest.state === 'resolved' ? '200' : latest.state === 'executing' ? '…' : '↳'}</code><span>{latest.kind}</span><strong>{latest.label}</strong></p>
          ) : <p><code>await</code><span>runtime</span><strong>user.intent()</strong></p>}
        </div>
      </aside>
    </>
  );
}
