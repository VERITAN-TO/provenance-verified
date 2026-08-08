'use client';

import { useEffect, useMemo, useRef, useState, type CSSProperties } from 'react';

interface ScrollCodeBlockProps {
  code: string;
  ariaLabel: string;
  className?: string;
  speed?: number;
}

export function ScrollCodeBlock({ code, ariaLabel, className = '', speed = 5 }: ScrollCodeBlockProps) {
  const rootRef = useRef<HTMLPreElement>(null);
  const [visible, setVisible] = useState(0);
  const [active, setActive] = useState(false);
  const lines = useMemo(() => code.split('\n').length, [code]);

  useEffect(() => {
    const node = rootRef.current;
    if (!node) return;
    if (typeof IntersectionObserver === 'undefined') {
      const timer = window.setTimeout(() => setActive(true), 0);
      return () => window.clearTimeout(timer);
    }
    const observer = new IntersectionObserver(([entry]) => {
      if (entry.isIntersecting) {
        setActive(true);
        observer.disconnect();
      }
    }, { threshold: 0.32, rootMargin: '0px 0px -8% 0px' });
    observer.observe(node);
    return () => observer.disconnect();
  }, [code]);

  useEffect(() => {
    if (!active) return;
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      const frame = requestAnimationFrame(() => setVisible(code.length));
      return () => cancelAnimationFrame(frame);
    }
    let frame = 0;
    let last = performance.now();
    let current = 0;
    const tick = (now: number) => {
      const elapsed = now - last;
      if (elapsed >= speed) {
        const chunk = Math.max(1, Math.floor(elapsed / speed) * 2);
        current = Math.min(code.length, current + chunk);
        setVisible(current);
        last = now;
      }
      if (current < code.length) frame = requestAnimationFrame(tick);
    };
    frame = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frame);
  }, [active, code, speed]);

  const complete = visible >= code.length;
  const progress = Math.round((visible / Math.max(code.length, 1)) * 100);
  const style = { '--pv-code-progress': `${progress}%` } as CSSProperties;
  return (
    <pre ref={rootRef} role="region" className={`pv-live-code ${active ? 'is-running' : ''} ${complete ? 'is-complete' : ''} ${className}`.trim()} tabIndex={0} aria-label={ariaLabel} aria-busy={!complete} data-progress={progress} style={style}>
      <code aria-hidden={!complete}>{code.slice(0, visible)}</code>
      {!complete && <span className="sr-only">{code}</span>}
      {!complete && <span className="pv-live-code-cursor" aria-hidden="true" />}
      <span className="pv-live-code-meta" aria-hidden="true">{complete ? `${lines} lines resolved` : `loading ${progress}%`}</span>
    </pre>
  );
}
