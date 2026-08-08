import fs from 'node:fs';
import path from 'node:path';

const roots = ['evidence', 'coverage', 'docs'];
const extensions = new Set(['.json','.jsonl','.md','.txt','.log','.html','.lcov','.yaml','.yml','.xml']);
const substitutions = [
  [/\/mnt\/data\/provenance_build\/PROVENANCE_CX_WEBSITE_VICTORY_BUILD_R1/g, '<PROJECT_ROOT>'],
  [/\/mnt\/data\/provenance_validation\/PROVENANCE_CX_WEBSITE_VICTORY_BUILD_R1/g, '<CLEAN_ROOM_ROOT>'],
  [/\/mnt\/data\/provenance_validation[^\s"'<]*/g, '<CLEAN_ROOM_PATH>'],
  [/\/opt\/nvm\/versions\/node\/v22\.16\.0\/bin\/node/g, '<NODE_RUNTIME>/bin/node'],
  [/\/home\/oai/g, '<HOME>'],
];
let filesChanged = 0;
let replacements = 0;
function walk(dir) {
  if (!fs.existsSync(dir)) return;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full);
    else if (extensions.has(path.extname(entry.name)) || entry.name === 'lcov.info') {
      let text;
      try { text = fs.readFileSync(full, 'utf8'); } catch { continue; }
      const before = text;
      for (const [pattern, value] of substitutions) {
        const matches = text.match(pattern);
        if (matches) replacements += matches.length;
        text = text.replace(pattern, value);
      }
      if (text !== before) { fs.writeFileSync(full, text); filesChanged += 1; }
    }
  }
}
for (const dir of roots) walk(dir);
const output = { filesChanged, replacements, sanitizedRoots: roots, status: 'passed' };
fs.mkdirSync('evidence/build', { recursive: true });
fs.writeFileSync('evidence/build/report-path-sanitization.json', JSON.stringify(output, null, 2));
console.log(JSON.stringify(output));
