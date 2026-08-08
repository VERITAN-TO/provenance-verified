import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { JSDOM } from 'jsdom';

const root = process.cwd();
const readJson = (file) => JSON.parse(fs.readFileSync(path.join(root, file), 'utf8'));
const htmlPath = path.join(root, 'review/PROVENANCE_CX_UNIFIED_FOUR_LAYER_R8_FINAL_VISUAL_STANDALONE.html');
const html = fs.readFileSync(htmlPath, 'utf8');
const dom = new JSDOM(html);
const doc = dom.window.document;
const resourceAttributes = [];
for (const element of [...doc.querySelectorAll('[src], [href]')]) {
  for (const attribute of ['src', 'href']) {
    const value = element.getAttribute(attribute);
    if (value && /^(https?:)?\/\//i.test(value)) resourceAttributes.push({ tag: element.tagName.toLowerCase(), attribute, value });
  }
}
const meta = readJson('review/PROVENANCE_CX_UNIFIED_FOUR_LAYER_R8_FINAL_VISUAL_STANDALONE.meta.json');
const allMetaText = JSON.stringify(meta);
const requiredModules = [
  'src/standalone/StandaloneApplication.tsx',
  'src/standalone/apiBridge.ts',
  'src/ui/CaliberHomepage.tsx',
  'src/ui/VerifyRoute.tsx',
  'src/ui/RegistryRoute.tsx',
  'src/ui/operations/ReviewWorkspace.tsx',
  'src/app/api/v1/operations/review/[caseId]/decision/route.ts',
  'src/app/api/v1/operations/review/[caseId]/lifecycle/route.ts',
  'src/app/api/v1/operations/review/[caseId]/corrections/route.ts',
  'src/services/deterministic.ts',
  'src/identity/identity3d.ts',
];
const modulePresence = Object.fromEntries(requiredModules.map((module) => [module, allMetaText.includes(module)]));
const appManifest = readJson('.next/app-path-routes-manifest.json');
const routes = [...new Set(Object.values(appManifest))].sort();
const classify = (route) => {
  if (route.startsWith('/app') || route.startsWith('/api/v1/operations')) return 'operations';
  if (route === '/verify' || route.startsWith('/registry') || ['/api/v1/verify','/api/v1/events'].includes(route) || route.startsWith('/api/v1/registry')) return 'registry';
  if (route === '/developers' || route.startsWith('/docs') || route.startsWith('/api/v1/webhooks')) return 'developer';
  if (route.startsWith('/_') || route === '/icon.png' || route === '/robots.txt' || route === '/sitemap.xml') return 'system';
  return 'public-authority';
};
const routeInventory = routes.map((route) => ({ route, layer: classify(route), dynamic: route.includes('[') }));
const chunksRoot = path.join(root, '.next/static');
const files = [];
function walk(directory) {
  if (!fs.existsSync(directory)) return;
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const full = path.join(directory, entry.name);
    if (entry.isDirectory()) walk(full);
    else files.push(full);
  }
}
walk(chunksRoot);
const bundleFiles = files.filter((file) => /\.(js|css)$/.test(file)).map((file) => {
  const bytes = fs.readFileSync(file);
  return { file: path.relative(root, file), type: path.extname(file).slice(1), bytes: bytes.length, gzipBytes: zlib.gzipSync(bytes).length };
}).sort((a,b)=>b.gzipBytes-a.gzipBytes);
const sourceText = fs.readdirSync(path.join(root,'src'), { recursive: true }).filter((file)=>typeof file==='string' && /\.(ts|tsx|js|jsx)$/.test(file)).map((file)=>fs.readFileSync(path.join(root,'src',file),'utf8')).join('\n');
const functional = readJson('evidence/r8/functional-browser-audit.json');
const tierWebgl = readJson('evidence/r8/R8_TIER_WEBGL_AUDIT.json');
const corporateWebgl = readJson('evidence/r8/R8_CORPORATE_WEBGL_AUDIT.json');
const staticVisual = readJson('evidence/r8/R8_STATIC_VISUAL_AUDIT.json');
const phase4 = readJson('evidence/phase4/HTTP_SMOKE.json');
const caliber = readJson('evidence/caliber/HTTP_SMOKE.json');
const audit = {
  generatedAt: new Date().toISOString(),
  release: 'PROVENANCE VERIFIED™ Release',
  classification: 'deterministic Test Mode website; production authority adapters intentionally unconnected',
  standalone: {
    file: path.relative(root, htmlPath), bytes: Buffer.byteLength(html), gzipBytes: zlib.gzipSync(Buffer.from(html)).length,
    inlineScripts: doc.querySelectorAll('script:not([src])').length,
    inlineStyles: doc.querySelectorAll('style').length,
    iframes: doc.querySelectorAll('iframe').length,
    externalResourceAttributes: resourceAttributes,
    embeddedAssets: meta.embeddedAssets,
    bundledSourceModules: meta.inputs,
    requiredModulePresence: modulePresence,
    oldStandaloneAssemblyReference: /R3_STANDALONE|readFile\([^)]*\.html/i.test(fs.readFileSync(path.join(root,'scripts/build-unified-standalone.mjs'),'utf8')),
  },
  architecture: {
    routes: routeInventory,
    routeCounts: routeInventory.reduce((acc, item) => ((acc[item.layer] = (acc[item.layer] ?? 0) + 1), acc), {}),
    serviceContractPresent: fs.existsSync(path.join(root,'src/services/contract.ts')),
    deterministicAdapterPresent: fs.existsSync(path.join(root,'src/services/deterministic.ts')),
    webglRendererConstructors: (sourceText.match(/new THREE\.WebGLRenderer|new WebGLRenderer/g) ?? []).length,
    iframeReferencesInSource: (sourceText.match(/<iframe|createElement\(['\"]iframe/gi) ?? []).length,
  },
  validation: {
    canonicalStandaloneBrowser: functional.pass,
    liveWebGL: tierWebgl.pass && corporateWebgl.pass,
    liveFourTierR5Geometry: tierWebgl.pass,
    liveCorporateR5Geometry: corporateWebgl.pass,
    staticVisualFallback: staticVisual.pass,
    publicApiCampaign: caliber.passed === true,
    operationsCampaign: phase4.passed === true,
    operationsChecks: phase4.checks,
    publicApiChecks: caliber.checks,
    accessibilityViolations: Object.values(functional.accessibility).reduce((sum, items) => sum + items.length, 0),
    consoleErrors: functional.consoleErrors.length + tierWebgl.errors.length + corporateWebgl.errors.length + staticVisual.errors.length,
    pageErrors: functional.pageErrors.length + tierWebgl.pageErrors.length + corporateWebgl.pageErrors.length + staticVisual.pageErrors.length,
    mobileOverflowPixels: functional.responsive.mobileOverflow,
  },
  bundle: {
    files: bundleFiles.length,
    rawBytes: bundleFiles.reduce((sum,item)=>sum+item.bytes,0),
    gzipBytes: bundleFiles.reduce((sum,item)=>sum+item.gzipBytes,0),
    largest: bundleFiles.slice(0,12),
  },
  browserMatrix: {
    chromiumStandalone: 'passed',
    chromiumLiveWebGL: 'passed',
    chromiumDirectLocalhostNavigation: 'blocked-by-managed-URLBlocklist',
    firefox: 'blocked-engine-unavailable-and-download-DNS-failed',
    webkitSafari: 'blocked-engine-unavailable-and-download-DNS-failed',
    iosSafariPhysical: 'blocked-no-physical-device',
    androidChromePhysical: 'blocked-no-physical-device',
    chromiumMobileViewport390x844: 'passed',
  },
};
audit.pass = audit.standalone.iframes === 0
  && audit.standalone.externalResourceAttributes.length === 0
  && Object.values(modulePresence).every(Boolean)
  && !audit.standalone.oldStandaloneAssemblyReference
  && audit.architecture.serviceContractPresent
  && audit.architecture.deterministicAdapterPresent
  && audit.architecture.webglRendererConstructors === 1
  && audit.architecture.iframeReferencesInSource === 0
  && Object.values(audit.validation).every((value) => typeof value !== 'boolean' || value);
fs.writeFileSync(path.join(root,'evidence/r8/route-inventory.json'), JSON.stringify({ routes: routeInventory, counts: audit.architecture.routeCounts }, null, 2) + '\n');
fs.writeFileSync(path.join(root,'evidence/r8/release-audit.json'), JSON.stringify(audit, null, 2) + '\n');
dom.window.close();
console.log(JSON.stringify(audit, null, 2));
if (!audit.pass) process.exitCode = 1;
