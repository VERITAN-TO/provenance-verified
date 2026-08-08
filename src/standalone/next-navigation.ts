import { useSyncExternalStore } from 'react';
function subscribe(callback: () => void) {
  window.addEventListener('hashchange', callback);
  window.addEventListener('pv:navigate', callback);
  return () => { window.removeEventListener('hashchange', callback); window.removeEventListener('pv:navigate', callback); };
}
function snapshot() {
  const hash = window.location.hash.replace(/^#/, '') || '/';
  return hash.split('?')[0].split('#')[0] || '/';
}
export function usePathname() { return useSyncExternalStore(subscribe, snapshot, () => '/'); }
export function useRouter() { return { push: (href: string) => { window.location.hash = href; window.dispatchEvent(new Event('pv:navigate')); }, replace: (href: string) => { history.replaceState(null, '', `#${href}`); window.dispatchEvent(new Event('pv:navigate')); }, back: () => history.back(), refresh: () => window.dispatchEvent(new Event('pv:navigate')) }; }
export function notFound(): never { throw new Error('NOT_FOUND'); }
