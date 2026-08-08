import { mkdir, writeFile } from 'node:fs/promises';
const base = process.env.BASE_URL || 'http://127.0.0.1:3100';
const results = [];
async function check(name, path, options = {}, expected = 200, predicate = () => true) {
  const response = await fetch(base + path, options);
  const text = await response.text();
  let body; try { body = JSON.parse(text); } catch { body = text; }
  const pass = response.status === expected && predicate(body, response);
  results.push({ name, method: options.method || 'GET', path, expected, actual: response.status, pass });
  if (!pass) throw new Error(`${name} failed: ${response.status} ${text.slice(0, 500)}`);
  return body;
}
const pages = [
  ['authority homepage', '/', 'Trust.'],
  ['public verifier', '/verify', 'VERIFICATION ENTRY'],
  ['public registry', '/registry', 'PUBLIC REGISTRY'],
  ['certification standard', '/provenance-verified', 'Provenance Verified'],
  ['developer surface', '/developers', 'DEVELOPER INTEGRATION'],
  ['documentation search', '/docs', 'Search documentation'],
  ['security surface', '/security', 'Security architecture'],
  ['trust surface', '/trust', 'TRUST CENTER'],
  ['test identity surface', '/sign-in', 'OPERATOR ACCESS / TEST MODE'],
  ['operational command', '/app', 'Jeweler command center'],
  ['operational review', '/app/review', 'Evidence review'],
];
for (const [name, path, text] of pages) await check(name, path, {}, 200, body => String(body).includes(text));
await check('issued Tier 4 verification', '/api/v1/verify', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ publicId: 'PV-TEST-T4D004', fixtureKey: 't4' }) }, 200, body => body.data.status === 'issued' && body.data.authorization.sealAuthorized === true);
await check('blocked Tier 4 verification', '/api/v1/verify', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ publicId: 'PV-TEST-A21008', fixtureKey: 't4MissingSecondApproval' }) }, 409, body => body.error.code === 'credential_not_issued' && body.authorization.blockers.length > 0);
await check('issued registry record', '/api/v1/registry/PV-TEST-T4D004', {}, 200, body => body.data.publicId === 'PV-TEST-T4D004');
await check('unissued record absent from registry', '/api/v1/registry/PV-TEST-A21008', {}, 404);
await check('valid Test Mode inquiry', '/api/v1/inquiries', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ mode: 'access', name: 'Avery Stone', organization: 'Northstar Jewelry Group', email: 'avery@example.com', message: 'Evaluate the canonical verification and registry workflow for an authorized jeweler pilot.', workflow: 'Verification API' }) }, 202, body => body.data.status === 'recorded-test-mode' && body.meta.delivered === false);
await check('invalid inquiry rejected', '/api/v1/inquiries', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ mode: 'contact', name: 'A', organization: '', email: 'invalid', message: 'short' }) }, 422, body => body.error.code === 'invalid_inquiry');
await check('sitemap generated', '/sitemap.xml', {}, 200, body => String(body).includes('https://provenanceverified.org/verify'));
await check('robots protects operations', '/robots.txt', {}, 200, body => String(body).includes('Disallow: /app/'));
const report = { base, checks: results.length, passed: results.every(item => item.pass), results };
await mkdir('evidence/caliber', { recursive: true });
await writeFile('evidence/caliber/HTTP_SMOKE.json', JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify(report, null, 2));
