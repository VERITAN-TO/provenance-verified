import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { execFileSync } from 'node:child_process';

const root=process.cwd();
const read=(p)=>fs.readFileSync(path.join(root,p),'utf8');
const exists=(p)=>fs.existsSync(path.join(root,p));
const sha=(b)=>crypto.createHash('sha256').update(b).digest('hex');
const checks=[]; const check=(id,pass,detail='')=>checks.push({id,pass:Boolean(pass),detail});
const pkg=JSON.parse(read('package.json'));
const lock=JSON.parse(read('package-lock.json'));
const sbom=JSON.parse(read('SBOM.json'));
const licenses=JSON.parse(read('LICENSES/INDEX.json'));
const docker=read('Dockerfile');
const workflow=read('.github/workflows/production-authority.yml');

check('lockfile-v3',lock.lockfileVersion===3,`lockfileVersion=${lock.lockfileVersion}`);
check('package-lock-root-version',lock.packages?.['']?.version===pkg.version,`${lock.packages?.['']?.version} / ${pkg.version}`);
const direct={...(pkg.dependencies??{}),...(pkg.devDependencies??{})};
check('direct-dependencies-exact',Object.values(direct).every((v)=>/^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$/.test(String(v))),`${Object.keys(direct).length} direct dependencies`);
const directMismatches=[];
for(const [name,version] of Object.entries(direct)){
 const locked=lock.packages?.[`node_modules/${name}`]?.version;
 if(locked!==version) directMismatches.push(`${name}:${version}/${locked}`);
}
check('direct-lockfile-alignment',directMismatches.length===0,directMismatches.join(','));
const missingIntegrity=[];
for(const [loc,entry] of Object.entries(lock.packages??{})){
 if(!loc||!entry.version||entry.link) continue;
 if(!entry.integrity) missingIntegrity.push(loc);
}
check('transitive-integrity-present',missingIntegrity.length===0,missingIntegrity.slice(0,10).join(','));
const lockComponents=new Set(Object.entries(lock.packages??{}).filter(([loc,e])=>loc&&e.version).map(([loc,e])=>`${loc.replace(/^node_modules\//,'')}@${e.version}`));
const sbomComponents=new Set((sbom.components??[]).map((c)=>`${c.name}@${c.version}`));
const sbomMissing=[...lockComponents].filter((v)=>!sbomComponents.has(v));
check('sbom-lockfile-complete',sbomMissing.length===0,`${sbomComponents.size}/${lockComponents.size}`);
check('sbom-r3-identity',String(sbom.metadata?.component?.name??'').includes('R3') && String(sbom.metadata?.component?.version??'').startsWith(pkg.version),JSON.stringify(sbom.metadata?.component??{}));
const licenseRecords=new Map((licenses.packages??[]).map((r)=>[r.name,r]));
const missingLicense=[...Object.keys(direct)].filter((name)=>!licenseRecords.has(name));
const missingLicenseFiles=[...(licenses.packages??[])].filter((r)=>!(r.files??[]).length).map((r)=>r.name);
check('direct-license-index-complete',missingLicense.length===0,missingLicense.join(','));
check('direct-license-files-present',missingLicenseFiles.length===0,missingLicenseFiles.join(','));
check('container-lockfile-install',/RUN npm ci --ignore-scripts/.test(docker));
check('container-nonroot-runtime',/distroless\/nodejs22-debian12:nonroot/.test(docker) && /--chown=nonroot:nonroot/.test(docker));
check('container-no-secret-copy',!/\.env(?:\.|\s|$)/.test(docker) && exists('.dockerignore'));
check('ci-complete-r3-gates',[
 'npm ci --ignore-scripts','npm run lint','npm run typecheck','npm run test','npm run build',
 'scripts/provider-contract-audit.py','scripts/migration-contract-audit.mjs','scripts/supply-chain-audit.mjs',
 'scripts/verify-r3-authority-ledgers.py','scripts/security-header-audit.mjs'
].every((token)=>workflow.includes(token)));
check('ci-no-production-deploy',!/(vercel\s+--prod|terraform\s+apply|aws\s+cloudformation\s+deploy|supabase\s+db\s+push)/.test(workflow));

const tracked=execFileSync('git',['ls-files','-co','--exclude-standard'],{encoding:'utf8'}).trim().split('\n').filter(Boolean)
 .filter((f)=>!f.startsWith('review/')&&!f.startsWith('evidence/')&&!f.startsWith('.git/')&&!/\.(png|jpg|jpeg|webp|zip|pdf|woff2?)$/i.test(f));
const secretPatterns=[
 ['aws-access-key',/\bAKIA[0-9A-Z]{16}\b/g],
 ['openai-secret',/\bsk-(?:proj-)?[A-Za-z0-9_-]{20,}\b/g],
 ['github-token',/\bgh[pousr]_[A-Za-z0-9]{30,}\b/g],
 ['private-key',/-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/g],
 ['supabase-service-role-jwt',/\beyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b/g],
];
const findings=[];
for(const file of tracked){
 let text; try{text=read(file);}catch{continue;}
 for(const [kind,re] of secretPatterns){ for(const match of text.matchAll(re)) findings.push({file,kind,preview:match[0].slice(0,12)}); }
}
check('repository-secret-scan',findings.length===0,JSON.stringify(findings.slice(0,10)));

const criticalFiles=['package.json','package-lock.json','Dockerfile','.github/workflows/production-authority.yml','SBOM.json','LICENSES/INDEX.json'];
const manifest={generatedAt:new Date().toISOString(),commit:null,files:{}};
try{manifest.commit=execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim();}catch{}
for(const file of criticalFiles) manifest.files[file]=`sha256:${sha(fs.readFileSync(path.join(root,file)))}`;
fs.mkdirSync(path.join(root,'evidence','r3'),{recursive:true});
fs.writeFileSync(path.join(root,'evidence','r3','release-provenance-input.json'),JSON.stringify(manifest,null,2)+'\n');
const failed=checks.filter((c)=>!c.pass);
const report={generatedAt:new Date().toISOString(),scope:'R3 lockfile, SBOM, licenses, secret scan, container and CI release-custody audit',summary:{checks:checks.length,passed:checks.length-failed.length,failed:failed.length,verdict:failed.length?'FAIL':'PASS'},checks,secretFindings:findings};
fs.writeFileSync(path.join(root,'evidence','r3','supply-chain-audit.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report.summary,null,2));
if(failed.length){console.error(JSON.stringify(failed,null,2));process.exit(1);}
