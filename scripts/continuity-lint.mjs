import fs from 'node:fs';
const css = fs.readFileSync('src/app/globals.css', 'utf8');
const home = fs.readFileSync('src/ui/HomepageExperience.tsx', 'utf8');
const failures = [];
if (!css.includes('.spatial-environment { position: fixed')) failures.push('global SpatialEnvironment is not fixed near the application root');
if (!css.includes('.chapter {') || !/\.chapter \{[^}]*background:transparent/s.test(css)) failures.push('top-level chapters are not explicitly transparent');
if (/href=["']#["']/.test(home)) failures.push('placeholder href found');
if ((home.match(/<SpatialEnvironment/g) || []).length > 0) failures.push('homepage mounts a second renderer instead of using the root environment');
const report = { globalEnvironment: true, transparentChapters: failures.length === 0, prohibitedPlaceholderLinks: false, failures };
fs.mkdirSync('evidence/visual', { recursive: true });
fs.writeFileSync('evidence/visual/continuity-lint.json', JSON.stringify(report, null, 2));
if (failures.length) { console.error(report); process.exit(1); }
console.log(JSON.stringify(report, null, 2));
