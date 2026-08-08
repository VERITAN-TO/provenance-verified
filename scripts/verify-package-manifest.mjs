import fs from 'node:fs'; import crypto from 'node:crypto';
const m=JSON.parse(fs.readFileSync('MANIFEST.json','utf8')); const failures=[];
for(const e of m.files){if(!fs.existsSync(e.path)){failures.push({path:e.path,error:'missing'});continue;}const b=fs.readFileSync(e.path);const h=crypto.createHash('sha256').update(b).digest('hex');if(h!==e.sha256||b.length!==e.size)failures.push({path:e.path,error:'mismatch',expected:e.sha256,actual:h});}
const sums=fs.readFileSync('SHA256SUMS.txt','utf8').trim().split(/\n/).filter(Boolean);
if(sums.length!==m.files.length)failures.push({path:'SHA256SUMS.txt',error:'entry-count-mismatch'});
const report={generatedAt:new Date().toISOString(),filesVerified:m.files.length,failures,status:failures.length?'failed':'passed'};
fs.mkdirSync('evidence/corrective',{recursive:true});fs.writeFileSync('evidence/corrective/package-manifest-verification.json',JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report,null,2));if(failures.length)process.exit(1);
