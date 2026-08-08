const CACHE = 'provenance-public-shell-v3';
const PUBLIC_SHELL = ['/offline.html', '/manifest.webmanifest', '/r5/icons/app-icon-192.png', '/r5/icons/app-icon-512.png'];
const STATIC_PREFIXES = ['/_next/static/', '/r5/', '/fonts/', '/icons/'];
const STATIC_EXTENSIONS = /\.(?:css|js|mjs|woff2?|ttf|otf|svg|png|jpe?g|webp|avif|ico)$/i;

function isCacheablePublicAsset(request) {
  if (request.method !== 'GET') return false;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return false;
  if (url.pathname.startsWith('/api/') || url.pathname.startsWith('/app') || url.pathname.startsWith('/sign-in')) return false;
  if (request.headers.has('authorization') || request.headers.has('cookie')) return false;
  return STATIC_PREFIXES.some((prefix) => url.pathname.startsWith(prefix)) || STATIC_EXTENSIONS.test(url.pathname) || PUBLIC_SHELL.includes(url.pathname);
}
function responseIsPublic(response) {
  if (!response || !response.ok || response.type === 'opaque') return false;
  const control = response.headers.get('cache-control') ?? '';
  if (/private|no-store/i.test(control)) return false;
  if (response.headers.has('set-cookie')) return false;
  const type = response.headers.get('content-type') ?? '';
  return !/text\/html/i.test(type) || PUBLIC_SHELL.some((path) => response.url.endsWith(path));
}

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(PUBLIC_SHELL)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', (event) => {
  event.waitUntil(caches.keys().then((keys) => Promise.all(keys.filter((key) => key !== CACHE).map((key) => caches.delete(key)))).then(() => self.clients.claim()));
});
self.addEventListener('message', (event) => {
  if (event.data?.type === 'PURGE_PROTECTED_DATA' || event.data?.type === 'PURGE_ALL_CACHES') {
    const reply = event.ports?.[0];
    const purge = caches.keys()
      .then((keys) => Promise.all(keys.map((key) => caches.delete(key))))
      .then(() => caches.open(CACHE).then((cache) => cache.addAll(PUBLIC_SHELL)))
      .then(() => reply?.postMessage({ type: 'PURGE_COMPLETE' }))
      .catch(() => { reply?.postMessage({ type: 'PURGE_FAILED' }); throw new Error('SERVICE_WORKER_PURGE_FAILED'); });
    event.waitUntil(purge);
  }
});
self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.mode === 'navigate') {
    event.respondWith(fetch(request).catch(() => caches.match('/offline.html')));
    return;
  }
  if (!isCacheablePublicAsset(request)) return;
  event.respondWith(caches.match(request).then((cached) => cached || fetch(request).then((response) => {
    if (responseIsPublic(response)) caches.open(CACHE).then((cache) => cache.put(request, response.clone()));
    return response;
  })));
});
