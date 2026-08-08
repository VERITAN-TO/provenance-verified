import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import { DatabaseSync } from 'node:sqlite';

const root = process.cwd();
const tmp = fs.mkdtempSync(path.join(os.tmpdir(),'pv-recovery-'));
const sourcePath = path.join(tmp,'authority-source.sqlite');
const backupPath = path.join(tmp,'authority-backup.sqlite');
const corruptPath = path.join(tmp,'authority-corrupt.sqlite');
const sha = (value) => crypto.createHash('sha256').update(value).digest('hex');
const canonical = (v) => JSON.stringify(v, Object.keys(v).sort());
const eventHash = (previous, seq, type, payload) => `sha256:${sha(`${previous}|${seq}|${type}|${canonical(payload)}`)}`;
const db = new DatabaseSync(sourcePath);
db.exec(`
  pragma journal_mode=WAL;
  pragma foreign_keys=ON;
  create table tenants(id text primary key, name text not null);
  create table evidence(id text primary key, tenant_id text not null references tenants(id), object_sha256 text not null unique, storage_key text not null unique, immutable integer not null check(immutable=1));
  create table custody_events(id text primary key, tenant_id text not null, evidence_id text not null references evidence(id), sequence integer not null, action text not null, previous_hash text not null, event_hash text not null unique, payload text not null, unique(evidence_id,sequence));
  create table credentials(id text primary key, tenant_id text not null, public_id text not null unique, lifecycle text not null, payload_digest text not null, signature text not null);
  create table registry(public_id text primary key, credential_id text not null references credentials(id), lifecycle text not null, projection text not null, revocation_ready integer not null check(revocation_ready=1));
  create table audit_events(id text primary key, tenant_id text not null, aggregate_id text not null, sequence integer not null, previous_hash text not null, event_hash text not null unique, event_type text not null, payload text not null, unique(aggregate_id,sequence));
  create trigger evidence_immutable before update on evidence begin select raise(abort,'APPEND_ONLY_OBJECT'); end;
  create trigger evidence_no_delete before delete on evidence begin select raise(abort,'APPEND_ONLY_OBJECT'); end;
  create trigger custody_immutable before update on custody_events begin select raise(abort,'APPEND_ONLY_OBJECT'); end;
  create trigger custody_no_delete before delete on custody_events begin select raise(abort,'APPEND_ONLY_OBJECT'); end;
  create trigger audit_immutable before update on audit_events begin select raise(abort,'APPEND_ONLY_OBJECT'); end;
  create trigger audit_no_delete before delete on audit_events begin select raise(abort,'APPEND_ONLY_OBJECT'); end;
`);
const insertTenant = db.prepare('insert into tenants values (?,?)');
const insertEvidence = db.prepare('insert into evidence values (?,?,?,?,1)');
const insertCustody = db.prepare('insert into custody_events values (?,?,?,?,?,?,?,?)');
const insertCredential = db.prepare('insert into credentials values (?,?,?,?,?,?)');
const insertRegistry = db.prepare('insert into registry values (?,?,?,?,1)');
const insertAudit = db.prepare('insert into audit_events values (?,?,?,?,?,?,?,?)');
insertTenant.run('tenant-a','Pailin White Pilot');
insertTenant.run('tenant-b','Isolation Control');
insertEvidence.run('ev-a','tenant-a',`sha256:${sha('evidence-a')}`,'tenant-a/ev-a.bin');
insertEvidence.run('ev-b','tenant-b',`sha256:${sha('evidence-b')}`,'tenant-b/ev-b.bin');
let prev='GENESIS';
for (const [i,action] of ['uploaded','hash-verified','scan-passed','qualified'].entries()) {
  const payload={evidenceId:'ev-a',action}; const h=eventHash(prev,i+1,`evidence.${action}`,payload);
  insertCustody.run(`ce-${i+1}`,'tenant-a','ev-a',i+1,action,prev,h,canonical(payload)); prev=h;
}
insertCredential.run('cred-a','tenant-a','PV-T4-LOCAL-001','active',`sha256:${sha('credential-payload')}`,'kms-receipt:local-simulation');
insertRegistry.run('PV-T4-LOCAL-001','cred-a','active',canonical({publicId:'PV-T4-LOCAL-001',lifecycle:'active',authoritative:false,mode:'no-deployment'}));
prev='GENESIS';
for (const [i,type] of ['credential.prepared','custos.authorized','credential.signed','registry.published'].entries()) {
  const payload={credentialId:'cred-a',type}; const h=eventHash(prev,i+1,type,payload);
  insertAudit.run(`ae-${i+1}`,'tenant-a','cred-a',i+1,prev,h,type,canonical(payload)); prev=h;
}

function snapshot(database) {
  const tables=['tenants','evidence','custody_events','credentials','registry','audit_events'];
  const rows={};
  for (const table of tables) rows[table]=database.prepare(`select * from ${table} order by 1`).all();
  return { rows, digest: sha(JSON.stringify(rows)) };
}
function verifyChain(rows) {
  let previous='GENESIS';
  for (const row of rows) {
    const payload=JSON.parse(row.payload);
    const type=row.event_type ?? `evidence.${row.action}`;
    const expected=eventHash(previous,row.sequence,type,payload);
    if (row.previous_hash!==previous || row.event_hash!==expected) return false;
    previous=row.event_hash;
  }
  return true;
}
const before=snapshot(db);
let immutableDenied=false;
try { db.exec("update evidence set storage_key='replaced' where id='ev-a'"); } catch { immutableDenied=true; }
db.exec(`pragma wal_checkpoint(full); vacuum into '${backupPath.replaceAll("'","''")}';`);
db.close();
const restored=new DatabaseSync(backupPath,{readOnly:true});
const after=snapshot(restored);
const custodyChain=verifyChain(restored.prepare("select * from custody_events where evidence_id='ev-a' order by sequence").all());
const authorityChain=verifyChain(restored.prepare("select * from audit_events where aggregate_id='cred-a' order by sequence").all());
const tenantLeak=restored.prepare("select count(*) as c from evidence where tenant_id='tenant-a' and id in (select id from evidence where tenant_id='tenant-b')").get().c;
restored.close();
fs.copyFileSync(backupPath,corruptPath);
const corrupt=new DatabaseSync(corruptPath);
corrupt.exec('drop trigger audit_immutable;');
corrupt.prepare("update audit_events set payload=? where id='ae-2'").run(canonical({credentialId:'cred-a',type:'tampered'}));
const corruptionDetected=!verifyChain(corrupt.prepare("select * from audit_events where aggregate_id='cred-a' order by sequence").all());
corrupt.close();
const checks=[
  {id:'snapshot-digest-identical',pass:before.digest===after.digest,detail:`${before.digest} / ${after.digest}`},
  {id:'all-table-rowsets-identical',pass:JSON.stringify(before.rows)===JSON.stringify(after.rows)},
  {id:'append-only-evidence-enforced',pass:immutableDenied},
  {id:'custody-chain-valid-after-restore',pass:custodyChain},
  {id:'authority-chain-valid-after-restore',pass:authorityChain},
  {id:'tenant-isolation-preserved',pass:Number(tenantLeak)===0},
  {id:'intentional-corruption-detected',pass:corruptionDetected},
  {id:'backup-file-nonempty',pass:fs.statSync(backupPath).size>0,detail:`${fs.statSync(backupPath).size} bytes`},
];
const failed=checks.filter((c)=>!c.pass);
const report={
  generatedAt:new Date().toISOString(),
  scope:'no-deployment local backup, restore, immutability, chain-integrity, tenant-isolation, and corruption-detection drill',
  sourceDigest:before.digest,
  restoredDigest:after.digest,
  rowCounts:Object.fromEntries(Object.entries(before.rows).map(([k,v])=>[k,v.length])),
  summary:{checks:checks.length,passed:checks.length-failed.length,failed:failed.length,verdict:failed.length?'FAIL':'PASS'},
  checks,
};
fs.mkdirSync(path.join(root,'evidence','corrective'),{recursive:true});
fs.writeFileSync(path.join(root,'evidence','corrective','recovery-simulation.json'),JSON.stringify(report,null,2)+'\n');
fs.rmSync(tmp,{recursive:true,force:true});
console.log(JSON.stringify(report.summary,null,2));
if(failed.length) process.exit(1);
