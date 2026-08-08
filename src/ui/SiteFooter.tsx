'use client';

import { usePathname } from 'next/navigation';
import { InstitutionalFooter } from './phase3/AuthorityBoundary';

export function SiteFooter() {
  const pathname = usePathname();
  if (pathname.startsWith('/app')) return null;
  return <InstitutionalFooter />;
}
