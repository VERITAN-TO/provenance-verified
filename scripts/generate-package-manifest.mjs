import fs from 'node:fs'; import path from 'node:path'; import crypto from 'node:crypto';
const root=process.cwd();
const excludedDirs=new Set(['.git','node_modules','.next','.local-build','coverage','playwright-report','test-results','__pycache__']);
const excludedFiles=new Set(['MANIFEST.json','SHA256SUMS.txt','SOURCE_COMMIT.txt','evidence/corrective/package-manifest-verification.json']);
const files=[];
function walk(dir){for(const e of fs.readdirSync(dir,{withFileTypes:true}).sort((a,b)=>a.name.localeCompare(b.name))){if(e.isDirectory()&&excludedDirs.has(e.name))continue;const full=path.join(dir,e.name);if(e.isDirectory())walk(full);else{const rel=path.relative(root,full).replaceAll(path.sep,'/');if(!excludedFiles.has(rel)&&!rel.endsWith('.pyc'))files.push(rel);}}}
walk(root);
const entries=files.map(file=>{const bytes=fs.readFileSync(file);return{path:file,size:bytes.length,sha256:crypto.createHash('sha256').update(bytes).digest('hex')}});
const manifest={generatedAt:new Date().toISOString(),artifact:'PROVENANCE_CX_R8_PRODUCTION_AUTHORITY_BUILD_R2_NO_DEPLOYMENT_COMPLETE',scope:'complete no-deployment source, build contracts, standalone, tests and evidence',fileCount:entries.length,totalBytes:entries.reduce((n,x)=>n+x.size,0),files:entries};
fs.writeFileSync('MANIFEST.json',JSON.stringify(manifest,null,2)+'\n');
fs.writeFileSync('SHA256SUMS.txt',entries.map(x=>`${x.sha256}  ${x.path}`).join('\n')+'\n');
console.log(JSON.stringify({fileCount:manifest.fileCount,totalBytes:manifest.totalBytes},null,2));
