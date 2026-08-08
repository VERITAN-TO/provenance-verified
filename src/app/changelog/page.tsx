import type { Metadata } from 'next'; import { RouteShell } from '@/ui/RouteShell';
export const metadata: Metadata = { title: 'Changelog' };
const entries = [
  ['2026-07-16','Website Victory Build R1','Deterministic four-tier kernel, canonical store, complete verification transaction, evidence and claim workbenches, registry parity, signed events, webhook retry/replay, lifecycle control, developer lab, continuous spatial environment, accessibility and fallback paths.'],
  ['2026-07-15','V15 Core authority locked','Hero headline, editorial composition, proof object role, operational state stack, machine output, and seven-stage rail established as governing authority.'],
  ['2026-07-14','Identity authority integrated','Corporate master mark role separated from Provenance Verified™ certification-tier seals.']
];
export default function Page() { return <RouteShell eyebrow="CHANGELOG" title="Versioned product and authority changes." lede="Every entry describes the public contract that changed. Historical labels do not override current governing policy."><div className="changelog-list">{entries.map(([date,title,body]) => <article key={date+title}><time>{date}</time><div><h2>{title}</h2><p>{body}</p></div></article>)}</div></RouteShell>; }
