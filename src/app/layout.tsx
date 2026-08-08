import type { Metadata, Viewport } from 'next';
import { headers } from 'next/headers';
import './site.css';
import './caliber-r2.css';
import { SiteHeader } from '@/ui/SiteHeader';
import { SiteFooter } from '@/ui/SiteFooter';
import { AccessibleStatus } from '@/ui/AccessibleStatus';
import { PwaRegistration } from '@/ui/operations/PwaRegistration';
import { LivingInterface } from '@/ui/LivingInterface';
import { StructuredData } from '@/ui/StructuredData';

export const metadata: Metadata = {
  title: { default: 'PROVENANCE VERIFIED™ — Independent gemstone provenance certification', template: '%s — PROVENANCE VERIFIED™' },
  description: 'Turn physical evidence into claim-scoped credentials, public registry records, lifecycle events, and machine-readable provenance through one canonical authority system.',
  applicationName: 'PROVENANCE VERIFIED™',
  metadataBase: new URL('https://provenanceverified.org'),
  icons: { icon: [{ url: '/r5/icons/favicon-optical-16.svg', sizes: '16x16', type: 'image/svg+xml' }, { url: '/r5/icons/favicon-optical-32.svg', sizes: '32x32', type: 'image/svg+xml' }], apple: '/r5/icons/app-icon-192.png' },
  openGraph: { title: 'PROVENANCE VERIFIED™', description: 'Independent gemstone provenance certification.', type: 'website', siteName: 'PROVENANCE VERIFIED™' },
  twitter: { card: 'summary_large_image', title: 'PROVENANCE VERIFIED™', description: 'Independent gemstone provenance certification.' },
  robots: { index: true, follow: true },
  manifest: '/manifest.webmanifest',
  alternates: { canonical: 'https://provenanceverified.org' },
  verification: { other: { 'knowledge-authority': 'https://provenanceverified.org/knowledge.json' } }
};
export const viewport: Viewport = { width: 'device-width', initialScale: 1, themeColor: '#03090d', colorScheme: 'dark' };

export default async function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  // proxy.ts (middleware) already sets a per-request nonce on the CSP response header.
  // Reading it here via next/headers is what makes Next.js apply that same nonce to the
  // script tags it renders for this request — without this call, Next has no way to know
  // a nonce exists, so its own scripts render without one and the browser's CSP blocks
  // every script on the page. See https://nextjs.org/docs/app/guides/content-security-policy.
  await headers();
  return (
    <html lang="en">
      <body>
        <StructuredData />
        <a className="skip-link" href="#main-content">Skip to content</a>
        <div className="site-chrome">
          <SiteHeader />
          {children}
          <SiteFooter />
        </div>
        <AccessibleStatus />
        <LivingInterface />
        <PwaRegistration />
      </body>
    </html>
  );
}
