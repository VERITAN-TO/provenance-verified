import type { Metadata } from 'next';
import { headers } from 'next/headers';
import { redirect } from 'next/navigation';
import { NextRequest } from 'next/server';
import { authorizeWave1Request } from '@/operations/http';
import { OrganizationAdmin } from '@/ui/operations/OrganizationAdmin';

export const metadata: Metadata = { title: 'Organization authority' };

export default async function OrganizationSettingsPage() {
  const incoming = await headers();
  const requestHeaders = new Headers();
  incoming.forEach((value, key) => requestHeaders.set(key, value));
  const request = new NextRequest('https://provenance.internal/app/settings', { headers: requestHeaders });
  try {
    await authorizeWave1Request(request, {
      action: 'membership/manage',
      resourceType: 'membership',
      resourceId: 'settings',
      quotaOperation: 'settings/read',
      metadata: { route: '/app/settings', method: 'GET' },
    });
  } catch {
    redirect('/app?denied=settings');
  }
  return <OrganizationAdmin />;
}
