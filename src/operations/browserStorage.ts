export function safeStorageGet(key: string): string | null {
  try { return globalThis.localStorage?.getItem(key) ?? null; } catch { return null; }
}
export function safeStorageSet(key: string, value: string): void {
  try { globalThis.localStorage?.setItem(key, value); } catch { /* storage is optional in private/opaque review contexts */ }
}
export function safeStorageRemove(key: string): void {
  try { globalThis.localStorage?.removeItem(key); } catch { /* storage is optional in private/opaque review contexts */ }
}
