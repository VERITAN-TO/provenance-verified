import type { ReactNode } from 'react';
import { CopyButton } from '@/ui/CopyButton';

export function ProofChapterHeader({ index, eyebrow, title, description, aside }: {
  index: string;
  eyebrow: string;
  title: string;
  description: string;
  aside?: ReactNode;
}) {
  return (
    <header className="p3-chapter-header">
      <div className="p3-chapter-index" aria-hidden="true">{index}</div>
      <div className="p3-chapter-heading">
        <div className="eyebrow"><span />{eyebrow}</div>
        <h2>{title}</h2>
        <p>{description}</p>
      </div>
      {aside ? <div className="p3-chapter-aside">{aside}</div> : null}
    </header>
  );
}

export function StatePill({ tone = 'neutral', children }: { tone?: 'neutral' | 'good' | 'warn' | 'danger' | 'cyan'; children: ReactNode }) {
  return <span className={`p3-state-pill ${tone}`}>{children}</span>;
}

export function Metric({ label, value, detail }: { label: string; value: ReactNode; detail?: ReactNode }) {
  return <div className="p3-metric"><span>{label}</span><strong>{value}</strong>{detail ? <small>{detail}</small> : null}</div>;
}

export function CodeSurface({ title, value, label = 'Copy' }: { title: string; value: string; label?: string }) {
  return (
    <div className="p3-code-surface">
      <div className="p3-code-head"><span>{title}</span><CopyButton value={value} label={label} /></div>
      <pre tabIndex={0} aria-label={title}><code>{value}</code></pre>
    </div>
  );
}

export function BoundaryNote({ title, children }: { title: string; children: ReactNode }) {
  return <aside className="p3-boundary-note"><strong>{title}</strong><p>{children}</p></aside>;
}
