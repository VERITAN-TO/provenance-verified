import type { ReactNode } from 'react';
import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import { ACCESS_COOKIE } from '@/authority/cookies';
import { getAuthorityRuntimeConfig } from '@/authority/config';
import { AuthenticatedProductShell } from '@/ui/authenticated/AuthenticatedProductShell';

export default async function ProtectedOperationsLayout({ children }: { children: ReactNode }) {
  const config = getAuthorityRuntimeConfig();
  if (config.environment === 'sandbox') {
    return <AuthenticatedProductShell environment="pilot">{children}</AuthenticatedProductShell>;
  }
  const store = await cookies();
  if (!store.get(ACCESS_COOKIE)?.value) redirect('/sign-in');
  return <AuthenticatedProductShell environment={config.environment}>{children}</AuthenticatedProductShell>;
}
