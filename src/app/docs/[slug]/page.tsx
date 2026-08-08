import { notFound } from 'next/navigation'; import type { Metadata } from 'next'; import { PolicyDocument } from '@/ui/RouteShell'; import { docsContent } from '@/ui/content';
export async function generateStaticParams() { return Object.keys(docsContent).map((slug) => ({ slug })); }
export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }): Promise<Metadata> { const { slug } = await params; return { title: docsContent[slug]?.title ?? 'Documentation' }; }
export default async function Page({ params }: { params: Promise<{ slug: string }> }) { const { slug } = await params; const doc = docsContent[slug]; if (!doc) notFound(); return <PolicyDocument title={doc.title} summary={doc.lede} sections={doc.sections} />; }
