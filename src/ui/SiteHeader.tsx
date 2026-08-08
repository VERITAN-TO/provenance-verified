'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useState } from 'react';
import { CorporateLockup } from '@/identity/CorporateIdentity';
import { TestModeBanner } from './TestModeBanner';

const nav = [
  ['Home', '/'],
  ['Verify', '/verify'],
  ['Registry', '/registry'],
  ['Standard', '/standard'],
  ['Developers', '/developers'],
  ['Certification', '/certification'],
  ['About', '/about'],
  ['Support', '/support'],
] as const;

export function SiteHeader() {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);
  if (pathname.startsWith('/app')) return null;

  return <>
    <TestModeBanner />
    <header className="site-header pv2-site-header">
      <div className="header-inner pv2-header-inner">
        <Link className="brand-link pv2-brand-link" href="/" aria-label="PROVENANCE VERIFIED home"><CorporateLockup compact priority /></Link>
        <button className="mobile-menu-button pv2-menu-button" aria-expanded={open} aria-controls="primary-nav" onClick={() => setOpen((value) => !value)}><span>{open ? 'Close' : 'Menu'}</span><i aria-hidden="true" /></button>
        <nav id="primary-nav" className={open ? 'primary-nav pv2-primary-nav is-open' : 'primary-nav pv2-primary-nav'} aria-label="Primary navigation">
          {nav.map(([label, href]) => <Link key={href} href={href} onClick={() => setOpen(false)}>{label}</Link>)}
        </nav>
        <div className="header-actions pv2-header-actions"><Link href="/docs" className="pv2-header-link">Docs</Link><Link href="/sign-in" className="pv2-header-link">Sign in</Link><Link href="/access" className="pv2-header-cta">Request access <span>↗</span></Link></div>
      </div>
    </header>
  </>;
}
