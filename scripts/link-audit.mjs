import fs from 'node:fs';
import path from 'node:path';
const root = process.cwd();
const files = [];
function walk(dir) { for (const entry of fs.readdirSync(dir, { withFileTypes: true })) { const p = path.join(dir, entry.name); if (entry.isDirectory()) walk(p); else if (/\.(tsx|ts|css)$/.test(entry.name)) files.push(p); } }
walk(path.join(root, 'src'));
const hrefs = [];
for (const file of files) { const text = fs.readFileSync(file, 'utf8'); for (const match of text.matchAll(/href=["'`]([^"'`]+)["'`]/g)) hrefs.push({ file: path.relative(root, file), href: match[1] }); }
const placeholders = hrefs.filter(({ href }) => href === '#' || href.startsWith('javascript:'));
const required = ['/', '/verify', '/registry', '/provenance-verified', '/developers', '/docs', '/security', '/trust', '/status', '/changelog', '/access', '/company', '/contact', '/sign-in', '/legal/privacy', '/legal/terms', '/legal/certification-policy', '/legal/evidence-policy', '/legal/revocation-policy', '/brand/trademark', '/app', '/app/lots', '/app/intake', '/app/batches', '/app/search', '/app/review', '/app/labels', '/app/exceptions', '/app/audit', '/app/settings'];
const source = files.map((f) => fs.readFileSync(f, 'utf8')).join('\n');
const missing = required.filter((route) => !source.includes(route));
const report = { scannedFiles: files.length, hrefCount: hrefs.length, placeholders, requiredRoutes: required, missing };
fs.writeFileSync(path.join(root, 'evidence', 'route-link-audit.json'), JSON.stringify(report, null, 2));
if (placeholders.length || missing.length) { console.error(report); process.exit(1); }
console.log(JSON.stringify(report, null, 2));
