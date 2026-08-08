import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
const require=createRequire(import.meta.url);
const pkg = JSON.parse(fs.readFileSync('package.json','utf8'));
const names = [...Object.keys(pkg.dependencies ?? {}), ...Object.keys(pkg.devDependencies ?? {})].sort();
fs.mkdirSync('LICENSES',{recursive:true});
for(const file of fs.readdirSync('LICENSES')) if(file!=='INDEX.json') fs.rmSync(path.join('LICENSES',file));
const records=[];
for(const name of names){
  let packageJson;
  try { packageJson = require.resolve(`${name}/package.json`); }
  catch {
    try {
      const entry=require.resolve(name);
      let dir=path.dirname(entry);
      while(dir!==path.dirname(dir) && !fs.existsSync(path.join(dir,'package.json'))) dir=path.dirname(dir);
      packageJson=path.join(dir,'package.json');
    } catch { continue; }
  }
  const dir=path.dirname(packageJson);
  const meta=JSON.parse(fs.readFileSync(packageJson,'utf8'));
  const candidates=fs.readdirSync(dir).filter((file)=>/^(licen[sc]e|copying|notice)(\.|$)/i.test(file));
  const safe=name.replace(/^@/,'').replaceAll('/','__');
  const copied=[];
  for(const file of candidates){
    const source=path.join(dir,file);
    if(!fs.statSync(source).isFile()) continue;
    const target=`LICENSES/${safe}__${file}`;
    fs.copyFileSync(source,target);
    copied.push(target);
  }
  records.push({name,version:meta.version,license:meta.license ?? 'SEE_PACKAGE',files:copied});
}
fs.writeFileSync('LICENSES/INDEX.json',JSON.stringify({generatedAt:new Date().toISOString(),packages:records},null,2));
console.log(`Collected ${records.length} direct package license records and ${records.reduce((sum,r)=>sum+r.files.length,0)} license files.`);
