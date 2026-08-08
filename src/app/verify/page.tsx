import type { Metadata } from 'next'; import { VerifyRoute } from '@/ui/VerifyRoute';
export const metadata: Metadata = { title: 'Verify a record' };
export default function Page() { return <VerifyRoute />; }
