import fs from 'node:fs';
const api=fs.readFileSync('supabase/functions/authority-api/index.ts','utf8');
const next=fs.readFileSync('src/authority/publicKeys.ts','utf8');
const policy=JSON.parse(fs.readFileSync('governance/CRYPTOGRAPHIC_AGILITY_POLICY.json','utf8'));
const checks=[
 ['public key endpoint', api.includes("path === '/api/v1/keys'")],
 ['active key default', api.includes("params.set('status', 'eq.active')")],
 ['historical key option', api.includes("includeHistorical")],
 ['PEM imported and JWK exported', api.includes("importKey('spki'") && api.includes("exportKey('jwk'")],
 ['service-separated key identity', api.includes('service: String(row.service_name)')],
 ['validity and policy metadata', api.includes('validFrom:') && api.includes('policyVersions:')],
 ['sandbox visibly non-authoritative', next.includes('authoritative: false')],
 ['remote missing keys fail closed', next.includes('AUTHORITY_VERIFICATION_KEYS_EMPTY')],
 ['well-known JWKS route', fs.existsSync('src/app/.well-known/jwks.json/route.ts')],
 ['no custom hash permitted', policy.prohibited.includes('stableHash')],
 ['approved algorithms bounded', policy.newSignatureAlgorithms.join(',')==='Ed25519,ES256'],
 ['service key separation required', policy.rotation.receiptKeysSeparatedByService===true],
];
const report={generatedAt:new Date().toISOString(),total:checks.length,passed:checks.filter(([,v])=>v).length,failed:checks.filter(([,v])=>!v).map(([n])=>n),checks:checks.map(([name,passed])=>({name,passed}))};
fs.mkdirSync('evidence/r3',{recursive:true});fs.writeFileSync('evidence/r3/key-discovery-audit.json',JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report,null,2));if(report.failed.length)process.exit(1);
