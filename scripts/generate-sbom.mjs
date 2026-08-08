import fs from 'node:fs';
import crypto from 'node:crypto';
const lock=JSON.parse(fs.readFileSync('package-lock.json','utf8'));
const components=[];
for(const [location,entry] of Object.entries(lock.packages ?? {})){
  if(!location || !entry.version) continue;
  const match=location.match(/node_modules\/(.+)$/);
  if(!match) continue;
  const name=match[1];
  const purl=`pkg:npm/${encodeURIComponent(name).replace('%40','@')}@${entry.version}`;
  components.push({
    type:'library',
    'bom-ref':purl,
    name,
    version:entry.version,
    scope:entry.dev ? 'optional' : 'required',
    licenses:entry.license ? [{license:{id:entry.license}}] : undefined,
    hashes:entry.integrity ? [{alg:'SHA-512',content:entry.integrity.replace(/^sha512-/,'')}] : undefined,
    purl,
  });
}
components.sort((a,b)=>a.purl.localeCompare(b.purl));
const serial=crypto.createHash('sha256').update(JSON.stringify(components)).digest('hex');
const sbom={
  bomFormat:'CycloneDX',
  specVersion:'1.5',
  serialNumber:`urn:uuid:${serial.slice(0,8)}-${serial.slice(8,12)}-${serial.slice(12,16)}-${serial.slice(16,20)}-${serial.slice(20,32)}`,
  version:1,
  metadata:{
    timestamp:new Date().toISOString(),
    tools:{components:[{type:'application',name:'provenance-sbom-generator',version:'1.0.0'}]},
    component:{type:'application',name:'PROVENANCE_CX_R8_1_PRODUCTION_AUTHORITY_R3_CORRECTIVE',version:'8.1.0-r3'},
  },
  components,
};
fs.writeFileSync('SBOM.json',JSON.stringify(sbom,null,2));
console.log(`SBOM components: ${components.length}`);
