import type { Metadata } from 'next'; import { RegistryRoute } from '@/ui/RegistryRoute'; import { getPublicEnvironment } from '@/authority/public-mode';
export const metadata: Metadata = { title: 'Public registry', alternates: { canonical: '/registry' } };
export default function Page() { return <RegistryRoute environment={getPublicEnvironment()} />; }
