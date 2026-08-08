import fs from 'node:fs';

const base = process.env.BASE_URL ?? 'http://127.0.0.1:3100';
const routes = [
  '/', '/verify', '/registry', '/registry/PV-TEST-T4D004', '/provenance-verified', '/developers', '/docs',
  '/docs/quickstart', '/docs/api', '/docs/sdk', '/docs/mcp', '/docs/webhooks', '/docs/events', '/docs/test-mode',
  '/security', '/trust', '/status', '/changelog', '/access', '/company', '/contact', '/sign-in',
  '/legal/privacy', '/legal/terms', '/legal/certification-policy', '/legal/evidence-policy', '/legal/revocation-policy',
  '/brand/trademark',
];

const results = [];
for (const route of routes) {
  const response = await fetch(`${base}${route}`, { redirect: 'manual' });
  const body = await response.text();
  results.push({
    route,
    status: response.status,
    contentType: response.headers.get('content-type'),
    bytes: Buffer.byteLength(body),
    hasHeading: /<h1[\s>]/i.test(body),
    hasTestBoundary: route === '/' || route.startsWith('/verify') || route.startsWith('/registry')
      ? body.includes('NOT A PRODUCTION CREDENTIAL')
      : null,
  });
}
const output = {
  generatedAt: new Date().toISOString(),
  baseURL: '<LOCAL_ACCEPTANCE_SERVER>',
  total: results.length,
  failures: results.filter((item) => item.status >= 400 || !item.hasHeading),
  results,
};
fs.mkdirSync('evidence/routes', { recursive: true });
fs.writeFileSync('evidence/routes/route-status-audit.json', JSON.stringify(output, null, 2));
console.log(JSON.stringify({ total: output.total, failures: output.failures.length }));
if (output.failures.length) process.exitCode = 1;
