import { build } from 'esbuild';
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const aliases = new Map([
  ['next/link', path.join(root, 'src/standalone/next-link.tsx')],
  ['next/image', path.join(root, 'src/standalone/next-image.tsx')],
  ['next/navigation', path.join(root, 'src/standalone/next-navigation.ts')],
  ['next/server', path.join(root, 'src/standalone/next-server.ts')],
  [path.join(root, 'src/operations/runtime.ts'), path.join(root, 'src/standalone/runtime.ts')],
]);
const aliasPlugin = { name: 'standalone-aliases', setup(build) {
  build.onResolve({ filter: /^next\/(link|image|navigation|server)$/ }, (args) => ({ path: aliases.get(args.path) }));
  build.onResolve({ filter: /^@\/operations\/runtime$/ }, () => ({ path: path.join(root, 'src/standalone/runtime.ts') }));
  build.onResolve({ filter: /operations\/runtime$/ }, (args) => {
    const resolved = path.resolve(args.resolveDir, args.path);
    if (resolved === path.join(root, 'src/operations/runtime') || resolved === path.join(root, 'src/operations/runtime.ts')) return { path: path.join(root, 'src/standalone/runtime.ts') };
    return null;
  });
}};
const result = await build({
  entryPoints: [path.join(root, 'src/standalone/main.tsx')], bundle: true, minify: true,
  format: 'iife', platform: 'browser', target: ['es2022'], write: false, metafile: true, outdir: path.join(root, '.standalone-build'),
  tsconfig: path.join(root, 'tsconfig.json'), plugins: [aliasPlugin],
  define: {
    'process.env.NODE_ENV': '"production"',
    'process.env.PV_SERVICE_MODE': '"test"',
    'process.env.PV_OPERATION_PERSISTENCE': '"browser-local-storage"',
    'process.env.NEXT_PUBLIC_CANONICAL_URL': '"https://provenanceverified.org"',
  },
  loader: { '.svg': 'dataurl', '.png': 'dataurl', '.jpg': 'dataurl', '.jpeg': 'dataurl', '.webp': 'dataurl' },
});
let js = result.outputFiles.find((file) => file.path.endsWith('.js'))?.text ?? '';
let css = result.outputFiles.find((file) => file.path.endsWith('.css'))?.text ?? '';
if (!js || !css) throw new Error('Unified standalone build did not emit both JavaScript and CSS.');
const assetPattern = /\/r5\/[A-Za-z0-9_./-]+\.(?:svg|png|jpe?g|webp)/g;
const refs = new Set([...(js.match(assetPattern) ?? []), ...(css.match(assetPattern) ?? [])]);
for (const ref of refs) {
  const file = path.join(root, 'public', ref.slice(1));
  const bytes = await readFile(file);
  const ext = path.extname(file).slice(1).replace('jpg','jpeg');
  const mime = ext === 'svg' ? 'image/svg+xml' : `image/${ext}`;
  const encoded = ext === 'svg' ? `data:${mime};utf8,${encodeURIComponent(bytes.toString('utf8')).replace(/'/g, '%27').replace(/\(/g, '%28').replace(/\)/g, '%29')}` : `data:${mime};base64,${bytes.toString('base64')}`;
  js = js.split(ref).join(encoded);
  css = css.split(ref).join(encoded);
}
const html = `<!doctype html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="color-scheme" content="dark"><meta name="theme-color" content="#03090d"><title>PROVENANCE VERIFIED™ — Unified Review</title><style>${css}</style></head><body><div id="root"></div><script>${js}</script></body></html>`;
const outDir = path.join(root, 'review'); await mkdir(outDir, { recursive: true });
const output = path.join(outDir, 'PROVENANCE_CX_UNIFIED_FOUR_LAYER_R8_FINAL_VISUAL_STANDALONE.html');
await writeFile(output, html);
await writeFile(path.join(outDir, 'PROVENANCE_CX_UNIFIED_FOUR_LAYER_R8_FINAL_VISUAL_STANDALONE.meta.json'), JSON.stringify({ bytes: Buffer.byteLength(html), embeddedAssets: refs.size, inputs: Object.keys(result.metafile.inputs).length, outputs: result.metafile.outputs }, null, 2));
console.log(JSON.stringify({ output, bytes: Buffer.byteLength(html), embeddedAssets: refs.size, modules: Object.keys(result.metafile.inputs).length }, null, 2));
