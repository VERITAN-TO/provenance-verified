'use client';

import { decryptOfflineBytes, encryptOfflineBytes, generateOfflineKey, offlineAad, randomBytes, readBlobBytes, base64Url, fromBase64Url } from './crypto';
import { getPublicEnvironment } from '@/authority/public-mode';

const DB_NAME='provenance-operations'; const DB_VERSION=3;
const SNAPSHOTS='snapshots'; const MEDIA='media'; const KEYS='keys'; const META='metadata';
interface EncryptedPayload { version:2; keyId:string; keyVersion:number; iv:Uint8Array; ciphertext:ArrayBuffer; savedAt:string; }
interface EncryptedMediaPayload extends EncryptedPayload { name:string; type:string; size:number; lastModified:number; }
interface KeyRecord { version:2; keyId:string; keyVersion:number; key:CryptoKey; createdAt:string; credentialId?:string; assurance:'non-exportable'|'passkey-verified'; }
interface Tombstone { revokedAt:string; reason:string; }
function openDb():Promise<IDBDatabase>{ return new Promise((resolve,reject)=>{ if(typeof indexedDB==='undefined')return reject(new Error('INDEXEDDB_UNAVAILABLE')); const request=indexedDB.open(DB_NAME,DB_VERSION); request.onupgradeneeded=()=>{const db=request.result; for(const store of [SNAPSHOTS,MEDIA,KEYS,META]) if(!db.objectStoreNames.contains(store))db.createObjectStore(store);}; request.onsuccess=()=>resolve(request.result); request.onerror=()=>reject(request.error??new Error('INDEXEDDB_OPEN_FAILED'));}); }
async function tx<T>(storeName:string,mode:IDBTransactionMode,action:(store:IDBObjectStore)=>IDBRequest<T>):Promise<T|undefined>{ const db=await openDb(); try{return await new Promise<T|undefined>((resolve,reject)=>{const transaction=db.transaction(storeName,mode);const request=action(transaction.objectStore(storeName));request.onsuccess=()=>resolve(request.result);request.onerror=()=>reject(request.error??new Error('INDEXEDDB_REQUEST_FAILED'));transaction.onerror=()=>reject(transaction.error??new Error('INDEXEDDB_TRANSACTION_FAILED'));});}finally{db.close();}}
async function put(store:string,key:string,value:unknown){await tx(store,'readwrite',(objectStore)=>objectStore.put(value,key));}
async function get<T>(store:string,key:string):Promise<T|null>{return (await tx<T>(store,'readonly',(objectStore)=>objectStore.get(key)))??null;}
async function remove(store:string,key:string){await tx(store,'readwrite',(objectStore)=>objectStore.delete(key));}
async function clear(store:string){await tx(store,'readwrite',(objectStore)=>objectStore.clear());}
function scopeKey(scope:string){return `scope:${scope}`;} function tombstoneKey(scope:string){return `tombstone:${scope}`;}
async function requireDeviceVerification(record:KeyRecord):Promise<void>{
  if(getPublicEnvironment()==='sandbox') return;
  if(!record.credentialId) throw new Error('OFFLINE_DEVICE_ANCHOR_REQUIRED');
  if(typeof PublicKeyCredential==='undefined'||!navigator.credentials) throw new Error('WEBAUTHN_UNAVAILABLE');
  const assertion=await navigator.credentials.get({publicKey:{challenge:randomBytes(32),allowCredentials:[{type:'public-key',id:fromBase64Url(record.credentialId)}],userVerification:'required',timeout:60_000}});
  if(!assertion) throw new Error('DEVICE_USER_VERIFICATION_FAILED');
}
async function offlineKey(scope:string,verify=true):Promise<KeyRecord>{
  const tombstone=await get<Tombstone>(META,tombstoneKey(scope)); if(tombstone) throw new Error('OFFLINE_SCOPE_REVOKED');
  let record=await get<KeyRecord>(KEYS,scopeKey(scope));
  if(!record){ const key=await generateOfflineKey(); record={version:2,keyId:`offline_${base64Url(randomBytes(18))}`,keyVersion:1,key,createdAt:new Date().toISOString(),assurance:'non-exportable'}; await put(KEYS,scopeKey(scope),record); }
  if(verify) await requireDeviceVerification(record); return record;
}
export async function enrollOfflineDeviceAnchor(scope:string,userName:string,displayName:string):Promise<{credentialId:string;keyId:string}>{
  if(typeof PublicKeyCredential==='undefined'||!navigator.credentials) throw new Error('WEBAUTHN_UNAVAILABLE');
  const userId=new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(userName)));
  const created=await navigator.credentials.create({publicKey:{challenge:randomBytes(32),rp:{name:'PROVENANCE VERIFIED'},user:{id:userId,name:userName,displayName},pubKeyCredParams:[{type:'public-key',alg:-8},{type:'public-key',alg:-7}],authenticatorSelection:{residentKey:'preferred',userVerification:'required'},attestation:'none',timeout:60_000}}) as PublicKeyCredential|null;
  if(!created) throw new Error('DEVICE_ENROLLMENT_FAILED');
  const record=await offlineKey(scope,false); const credentialId=base64Url(created.rawId); const anchored={...record,credentialId,assurance:'passkey-verified' as const}; await put(KEYS,scopeKey(scope),anchored); return {credentialId,keyId:record.keyId};
}
export async function saveOfflineSnapshot(key:string,value:unknown):Promise<void>{const record=await offlineKey(key);const bytes=new TextEncoder().encode(JSON.stringify(value));const aad=offlineAad(key,'snapshot',record.keyId,record.keyVersion);const encrypted=await encryptOfflineBytes(record.key,bytes.buffer,aad);await put(SNAPSHOTS,key,{version:2,keyId:record.keyId,keyVersion:record.keyVersion,...encrypted,savedAt:new Date().toISOString()} satisfies EncryptedPayload);}
export async function loadOfflineSnapshot<T>(key:string):Promise<T|null>{const payload=await get<EncryptedPayload>(SNAPSHOTS,key);if(!payload)return null;const record=await offlineKey(key);if(payload.keyId!==record.keyId||payload.keyVersion!==record.keyVersion)throw new Error('OFFLINE_KEY_VERSION_MISMATCH');const clear=await decryptOfflineBytes(record.key,new Uint8Array(payload.iv),payload.ciphertext,offlineAad(key,'snapshot',record.keyId,record.keyVersion));return JSON.parse(new TextDecoder().decode(clear)) as T;}
export async function clearOfflineSnapshot(key:string){await remove(SNAPSHOTS,key);}
export async function saveOfflineMedia(key:string,file:File):Promise<void>{const record=await offlineKey(key);const aad=offlineAad(key,'media',record.keyId,record.keyVersion);const encrypted=await encryptOfflineBytes(record.key,await readBlobBytes(file),aad);await put(MEDIA,key,{version:2,keyId:record.keyId,keyVersion:record.keyVersion,...encrypted,name:file.name,type:file.type,size:file.size,lastModified:file.lastModified,savedAt:new Date().toISOString()} satisfies EncryptedMediaPayload);}
export async function loadOfflineMedia(key:string):Promise<File|null>{const payload=await get<EncryptedMediaPayload>(MEDIA,key);if(!payload)return null;const record=await offlineKey(key);if(payload.keyId!==record.keyId||payload.keyVersion!==record.keyVersion)throw new Error('OFFLINE_KEY_VERSION_MISMATCH');const clear=await decryptOfflineBytes(record.key,new Uint8Array(payload.iv),payload.ciphertext,offlineAad(key,'media',record.keyId,record.keyVersion));return new File([clear],payload.name,{type:payload.type,lastModified:payload.lastModified});}
export async function clearOfflineMedia(key:string){await remove(MEDIA,key);}
export async function rotateOfflineScopeKey(scope:string):Promise<{keyId:string;keyVersion:number}>{const current=await offlineKey(scope);await clearOfflineSnapshot(scope).catch(()=>undefined);await clearOfflineMedia(scope).catch(()=>undefined);const key=await generateOfflineKey();const next:KeyRecord={version:2,keyId:`offline_${base64Url(randomBytes(18))}`,keyVersion:current.keyVersion+1,key,createdAt:new Date().toISOString(),credentialId:current.credentialId,assurance:current.assurance};await put(KEYS,scopeKey(scope),next);return{keyId:next.keyId,keyVersion:next.keyVersion};}
export async function revokeOfflineScope(scope:string,reason='remote-revocation'):Promise<void>{await Promise.all([clearOfflineSnapshot(scope).catch(()=>undefined),clearOfflineMedia(scope).catch(()=>undefined),remove(KEYS,scopeKey(scope)).catch(()=>undefined)]);await put(META,tombstoneKey(scope),{revokedAt:new Date().toISOString(),reason} satisfies Tombstone);}
export async function clearAllOfflineData():Promise<void>{await Promise.all([clear(SNAPSHOTS),clear(MEDIA),clear(KEYS),clear(META)]);}
export async function purgeServiceWorkerCaches():Promise<void>{
  if(typeof globalThis==='undefined')return;
  if('caches' in globalThis){
    const names=await globalThis.caches.keys();
    await Promise.all(names.map((name)=>globalThis.caches.delete(name)));
  }
  if(typeof navigator==='undefined'||!navigator.serviceWorker)return;
  const registrations=await navigator.serviceWorker.getRegistrations();
  await Promise.all(registrations.map(async(registration)=>{
    const worker=registration.active??registration.waiting??registration.installing;
    if(!worker)return;
    await new Promise<void>((resolve,reject)=>{
      const channel=new MessageChannel();
      const timeout=setTimeout(()=>reject(new Error('SERVICE_WORKER_PURGE_TIMEOUT')),5000);
      channel.port1.onmessage=(event)=>{clearTimeout(timeout);event.data?.type==='PURGE_COMPLETE'?resolve():reject(new Error('SERVICE_WORKER_PURGE_FAILED'));};
      worker.postMessage({type:'PURGE_PROTECTED_DATA'},[channel.port2]);
    });
  }));
}
