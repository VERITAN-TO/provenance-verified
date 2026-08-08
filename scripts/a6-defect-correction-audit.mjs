import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import childProcess from 'node:child_process';
import { createRequire } from 'node:module';
const root=process.cwd();const evidence=path.join(root,'evidence/wave1-slice1-a6-correction');fs.mkdirSync(evidence,{recursive:true});
const temp=fs.mkdtempSync(path.join(os.tmpdir(),'pv-a6-correction-'));
const require=createRequire(import.meta.url);const ts=require(path.join(childProcess.execFileSync('npm',['root','-g'],{encoding:'utf8'}).trim(),'typescript'));
function compile(source,name){const output=ts.transpileModule(fs.readFileSync(source,'utf8'),{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.CommonJS,strict:true},fileName:source,reportDiagnostics:true});const errors=(output.diagnostics??[]).filter(d=>d.category===ts.DiagnosticCategory.Error);if(errors.length)throw new Error(`${source} transpile diagnostics ${errors.map(d=>d.code).join(',')}`);const target=path.join(temp,name);fs.writeFileSync(target,output.outputText);return target;}
function run(name,args){const result=childProcess.spawnSync(args[0],args.slice(1),{cwd:root,encoding:'utf8'});fs.writeFileSync(path.join(evidence,`${name}.txt`),`${result.stdout}${result.stderr}`);return{pass:result.status===0,status:result.status,output:`${result.stdout}${result.stderr}`};}
const signOut=compile('src/ui/authenticated/sign-out-controller.ts','sign-out-controller.cjs');
const publicErrors=compile('src/operations/public-error-mapper.ts','public-error-mapper.cjs');
const checks=[];
checks.push({id:'A4_SIGN_OUT_HARNESS',...run('A4_SIGN_OUT_HARNESS',['node','tests/a4/sign-out-controller-harness.cjs',signOut,root])});
checks.push({id:'A5_PUBLIC_ERROR_HARNESS',...run('A5_PUBLIC_ERROR_HARNESS',['node','tests/a5/public-error-mapper-harness.cjs',publicErrors])});
checks.push({id:'SOURCE_QUALITY',...run('SOURCE_QUALITY',['node','scripts/source-quality-audit.mjs'])});
checks.push({id:'OFFLINE_SECURITY',...run('OFFLINE_SECURITY',['node','scripts/offline-security-audit.mjs'])});
checks.push({id:'LINK_AUDIT',...run('LINK_AUDIT',['node','scripts/link-audit.mjs'])});
checks.push({id:'MIGRATION_CONTRACT',...run('MIGRATION_CONTRACT',['node','scripts/migration-contract-audit.mjs'])});
const failed=checks.filter(x=>!x.pass);const report={generatedAt:new Date().toISOString(),checks:checks.length,passed:checks.length-failed.length,failed:failed.length,results:checks.map(({output,...rest})=>rest)};fs.writeFileSync(path.join(evidence,'A6_DEFECT_CORRECTION_RESULTS.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report,null,2));fs.rmSync(temp,{recursive:true,force:true});if(failed.length)process.exit(1);
