const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const controller = require(process.argv[2]);
const root = process.argv[3];
const results = [];
async function test(name, fn) {
  try { await fn(); results.push({ name, pass: true }); }
  catch (error) { results.push({ name, pass: false, error: String(error) }); }
}
function deferred() { let resolve; let reject; const promise = new Promise((r,j)=>{resolve=r;reject=j}); return {promise,resolve,reject}; }
(async()=>{
  await test('SIGN_OUT_INVOKES_SERVER_INVALIDATION', async()=>{
    let calls=0; await controller.executeAuthenticatedSignOut({terminateAuthoritySession:async()=>{calls++},clearAllOfflineData:async()=>{},purgeServiceWorkerCaches:async()=>{},clearNonAuthoritativeClientState:()=>{}}); assert.equal(calls,1);
  });
  await test('SIGN_OUT_AWAITS_OFFLINE_DATA_PURGE', async()=>{
    const gate=deferred(); let finished=false; const run=controller.executeAuthenticatedSignOut({terminateAuthoritySession:async()=>{},clearAllOfflineData:()=>gate.promise,purgeServiceWorkerCaches:async()=>{},clearNonAuthoritativeClientState:()=>{}}).then(()=>{finished=true}); await Promise.resolve(); assert.equal(finished,false); gate.resolve(); await run; assert.equal(finished,true);
  });
  await test('SIGN_OUT_AWAITS_SERVICE_WORKER_CACHE_PURGE', async()=>{
    const gate=deferred(); let finished=false; const run=controller.executeAuthenticatedSignOut({terminateAuthoritySession:async()=>{},clearAllOfflineData:async()=>{},purgeServiceWorkerCaches:()=>gate.promise,clearNonAuthoritativeClientState:()=>{}}).then(()=>{finished=true}); await Promise.resolve(); assert.equal(finished,false); gate.resolve(); await run; assert.equal(finished,true);
  });
  await test('NON_AUTHORITATIVE_STATE_CLEARED', async()=>{
    let cleared=false; const result=await controller.executeAuthenticatedSignOut({terminateAuthoritySession:async()=>{},clearAllOfflineData:async()=>{},purgeServiceWorkerCaches:async()=>{},clearNonAuthoritativeClientState:()=>{cleared=true}}); assert.equal(cleared,true); assert.equal(result.status,'SIGNED_OUT');
  });
  await test('PURGE_FAILURE_DOES_NOT_RESTORE_SESSION', async()=>{
    const result=await controller.executeAuthenticatedSignOut({terminateAuthoritySession:async()=>{},clearAllOfflineData:async()=>{throw new Error('secret')},purgeServiceWorkerCaches:async()=>{},clearNonAuthoritativeClientState:()=>{}}); assert.equal(result.status,'LOCAL_CLEANUP_FAILED'); assert.notEqual(result.status,'AUTHENTICATED');
  });
  await test('PURGE_FAILURE_DOES_NOT_RENDER_PROTECTED_UI', async()=>{
    const shell=fs.readFileSync(path.join(root,'src/ui/authenticated/AuthenticatedProductShell.tsx'),'utf8'); assert.match(shell,/SIGNED_OUT_CLEANUP_REQUIRED/); assert.match(shell,/Protected access remains disabled/); assert.ok(shell.indexOf("state.status === 'AUTHENTICATED'") < shell.indexOf("state.status === 'SIGNED_OUT_CLEANUP_REQUIRED'"));
  });
  await test('PURGE_FAILURE_PRODUCES_SAFE_USER_MESSAGE', async()=>{
    const shell=fs.readFileSync(path.join(root,'src/ui/authenticated/AuthenticatedProductShell.tsx'),'utf8'); assert.match(shell,/protected browser data could not be fully removed/i); assert.doesNotMatch(shell,/cleanupFailures\.join|error\.message|stack/i);
  });
  await test('RETRY_CLEANUP_SUCCEEDS', async()=>{
    let count=0; const result=await controller.retrySignedOutCleanup({clearAllOfflineData:async()=>{count++},purgeServiceWorkerCaches:async()=>{count++},clearNonAuthoritativeClientState:()=>{count++}}); assert.equal(result.status,'SIGNED_OUT'); assert.equal(count,3);
  });
  await test('SUCCESSFUL_LOGOUT_CLEARS_ALL_PROTECTED_INDEXEDDB_STORES', async()=>{
    const db=fs.readFileSync(path.join(root,'src/operations/offline/indexedDb.ts'),'utf8'); assert.match(db,/clearAllOfflineData\(\):Promise<void>\{await Promise\.all\(\[clear\(SNAPSHOTS\),clear\(MEDIA\),clear\(KEYS\),clear\(META\)\]\)/);
  });
  await test('SUCCESSFUL_LOGOUT_PURGES_AND_ACKNOWLEDGES_SERVICE_WORKER_CACHE', async()=>{
    const db=fs.readFileSync(path.join(root,'src/operations/offline/indexedDb.ts'),'utf8'); const sw=fs.readFileSync(path.join(root,'public/sw.js'),'utf8'); assert.match(db,/PURGE_COMPLETE/); assert.match(db,/globalThis\.caches\.keys/); assert.match(db,/globalThis\.caches\.delete/); assert.match(db,/await Promise\.all\(registrations\.map/); assert.match(sw,/keys\.map\(\(key\) => caches\.delete\(key\)\)/); assert.match(sw,/PURGE_COMPLETE/);
  });
  const failed=results.filter(x=>!x.pass); console.log(JSON.stringify({checks:results.length,passed:results.length-failed.length,failed:failed.length,results},null,2)); if(failed.length)process.exit(1);
})();
