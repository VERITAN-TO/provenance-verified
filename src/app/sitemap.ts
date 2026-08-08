import type { MetadataRoute } from 'next';

const routes = ['', '/verify', '/registry', '/provenance-verified', '/developers', '/docs', '/docs/quickstart', '/docs/api', '/docs/sdk', '/docs/webhooks', '/docs/mcp', '/security', '/trust', '/status', '/changelog', '/brand/trademark', '/company', '/access', '/contact', '/sign-in', '/legal/privacy', '/legal/terms', '/legal/certification-policy', '/legal/evidence-policy', '/legal/revocation-policy', '/standard', '/certification', '/about', '/support'];

export default function sitemap(): MetadataRoute.Sitemap {
  return routes.map((route) => ({ url: `https://provenanceverified.org${route}`, lastModified: new Date('2026-07-20T00:00:00Z'), changeFrequency: route === '' ? 'weekly' : 'monthly', priority: route === '' ? 1 : route === '/verify' || route === '/registry' ? .9 : .7 }));
}
