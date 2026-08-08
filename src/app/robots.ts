import type { MetadataRoute } from 'next';

export default function robots(): MetadataRoute.Robots {
  return { rules: [{ userAgent: '*', allow: ['/', '/verify', '/registry', '/developers', '/docs', '/security', '/trust', '/knowledge.json', '/llms.txt', '/.well-known/security.txt', '/.well-known/jwks.json'], disallow: ['/app/', '/api/'] }], sitemap: 'https://provenanceverified.org/sitemap.xml' };
}
