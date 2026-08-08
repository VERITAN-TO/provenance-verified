'use client';

const encoder = new TextEncoder();
export async function readBlobBytes(blob: Blob): Promise<ArrayBuffer> {
  if (typeof blob.arrayBuffer === 'function') return blob.arrayBuffer();
  return new Promise<ArrayBuffer>((resolve, reject) => { const reader=new FileReader(); reader.onload=()=>resolve(reader.result as ArrayBuffer); reader.onerror=()=>reject(reader.error ?? new Error('BLOB_READ_FAILED')); reader.readAsArrayBuffer(blob); });
}
export async function sha256Blob(blob: Blob): Promise<string> {
  const digest=await crypto.subtle.digest('SHA-256',await readBlobBytes(blob));
  return `sha256:${Array.from(new Uint8Array(digest),(byte)=>byte.toString(16).padStart(2,'0')).join('')}`;
}
export async function generateOfflineKey(): Promise<CryptoKey> {
  return crypto.subtle.generateKey({name:'AES-GCM',length:256},false,['encrypt','decrypt']);
}
export function randomBytes(length:number): Uint8Array { return crypto.getRandomValues(new Uint8Array(length)); }
export async function encryptOfflineBytes(key:CryptoKey,bytes:ArrayBuffer,additionalData?:Uint8Array):Promise<{iv:Uint8Array;ciphertext:ArrayBuffer}>{
  const iv=randomBytes(12); const ciphertext=await crypto.subtle.encrypt({name:'AES-GCM',iv,additionalData},key,bytes); return {iv,ciphertext};
}
export async function decryptOfflineBytes(key:CryptoKey,iv:Uint8Array,ciphertext:ArrayBuffer,additionalData?:Uint8Array):Promise<ArrayBuffer>{
  return crypto.subtle.decrypt({name:'AES-GCM',iv,additionalData},key,ciphertext);
}
export function offlineAad(scope:string,purpose:string,keyId:string,version:number):Uint8Array { return encoder.encode(`PROVENANCE-VERIFIED|offline-v2|${scope}|${purpose}|${keyId}|${version}`); }
export function base64Url(bytes:ArrayBuffer|Uint8Array):string { const data=bytes instanceof Uint8Array?bytes:new Uint8Array(bytes); let binary=''; for(const byte of data) binary+=String.fromCharCode(byte); return btoa(binary).replaceAll('+','-').replaceAll('/','_').replace(/=+$/,''); }
export function fromBase64Url(value:string):Uint8Array { const normalized=value.replaceAll('-','+').replaceAll('_','/').padEnd(Math.ceil(value.length/4)*4,'='); const binary=atob(normalized); return Uint8Array.from(binary,(char)=>char.charCodeAt(0)); }
