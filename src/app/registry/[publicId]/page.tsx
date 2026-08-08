import type { Metadata } from 'next'; import { PublicRecord } from '@/ui/PublicRecord';
export async function generateMetadata({ params }: { params: Promise<{ publicId: string }> }): Promise<Metadata> { const { publicId } = await params; return { title: `Registry ${publicId}` }; }
export default async function Page({ params }: { params: Promise<{ publicId: string }> }) { const { publicId } = await params; return <PublicRecord publicId={decodeURIComponent(publicId).toUpperCase()} />; }
