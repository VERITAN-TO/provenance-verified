import Link from 'next/link';
import type { ReactNode } from 'react';
import { CorporateMark3D } from '@/identity/CorporateIdentity';

export function RouteShell({ eyebrow, title, lede, children, aside }: { eyebrow: string; title: string; lede: string; children: ReactNode; aside?: ReactNode }) {
  return <main id="main-content" className="route-main pv2-route-main">
    <section className="route-hero pv2-route-hero">
      <div className="pv2-route-copy"><div className="pv2-route-kicker"><span>{eyebrow}</span><i /></div><h1>{title}</h1><p>{lede}</p><div className="pv2-route-proofline"><span>Canonical records</span><span>Fail-closed authority</span><span>Lifecycle continuity</span></div></div>
      <div className="pv2-route-aside">{aside ?? <div className="pv2-route-master-mark"><CorporateMark3D priority interactive /></div>}</div>
    </section>
    <div className="route-body pv2-route-body">{children}</div>
    <section className="route-closing pv2-route-closing"><div><span>CANONICAL AUTHORITY</span><h2>Trust remains inspectable.</h2><p>Every Test Mode result carries its evidence scope, policy result, signature state, lifecycle state, registry projection, and machine-readable response.</p></div><div><Link href="/verify" className="pv2-button pv2-button-primary">Run verification <span>↗</span></Link><Link href="/docs/quickstart" className="pv2-button pv2-button-ghost">Quickstart</Link></div></section>
  </main>;
}

export function PolicyDocument({ title, summary, sections, aside, lead }: { title: string; summary: string; sections: { heading: string; body: string }[]; aside?: ReactNode; lead?: ReactNode }) {
  return <RouteShell eyebrow="PUBLIC AUTHORITY" title={title} lede={summary} aside={aside}>{lead}<div className="document-layout"><nav aria-label={`${title} contents`}><strong>Contents</strong>{sections.map((section) => <a key={section.heading} href={`#${slug(section.heading)}`}>{section.heading}</a>)}</nav><article className="policy-document">{sections.map((section) => <section key={section.heading} id={slug(section.heading)}><h2>{section.heading}</h2>{section.body.split('\n').map((paragraph) => <p key={paragraph}>{paragraph}</p>)}</section>)}</article></div></RouteShell>;
}

function slug(value: string) { return value.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, ''); }
