import { randomBytes } from 'node:crypto';
import { NextRequest, NextResponse } from 'next/server';
import { ACCESS_COOKIE, TENANT_COOKIE } from '@/authority/cookies';

function environment() {
  const value = (process.env.PV_ENVIRONMENT ?? process.env.PV_SERVICE_MODE ?? 'sandbox').toLowerCase();
  if (value === 'test') return 'sandbox';
  if (!['sandbox', 'pilot', 'production'].includes(value)) throw new Error('PV_ENVIRONMENT_INVALID');
  return value as 'sandbox' | 'pilot' | 'production';
}

function isLocalAuthorityRoute(pathname: string) {
  return pathname.startsWith('/api/v1/auth/');
}


function mutationMethod(method: string) { return !['GET','HEAD','OPTIONS'].includes(method.toUpperCase()); }
function browserCommandDenied(request: NextRequest) {
  if (!mutationMethod(request.method)) return false;
  const fetchSite=request.headers.get('sec-fetch-site');
  if (fetchSite==='cross-site') return true;
  const origin=request.headers.get('origin');
  const cookieAuthenticated=Boolean(request.cookies.get(ACCESS_COOKIE)?.value || request.cookies.get('pv_refresh_token')?.value);
  if (origin && origin!==request.nextUrl.origin) return true;
  if (cookieAuthenticated && !origin) return true;
  return false;
}

function csp(nonce: string, mode: 'sandbox' | 'pilot' | 'production') {
  const directives = [
    "default-src 'self'",
    `script-src 'self' 'nonce-${nonce}' 'strict-dynamic'${mode === 'sandbox' ? " 'unsafe-eval'" : ''}`,
    // R8.1 uses three narrow runtime style attributes for geometric positioning. This
    // exception is render-protected and documented in CSP_CONTROLLED_EXCEPTION.md.
    "style-src 'self' 'unsafe-inline'",
    "img-src 'self' data: blob:",
    "font-src 'self' data:",
    "connect-src 'self'",
    "worker-src 'self' blob:",
    "manifest-src 'self'",
    "media-src 'self' blob:",
    "object-src 'none'",
    "base-uri 'self'",
    "form-action 'self'",
    "frame-ancestors 'none'",
    "frame-src 'none'",
    mode === 'production' ? 'upgrade-insecure-requests' : '',
  ].filter(Boolean);
  return directives.join('; ');
}

function withSecurityHeaders(response: NextResponse, nonce: string, mode: 'sandbox' | 'pilot' | 'production') {
  response.headers.set('Content-Security-Policy', csp(nonce, mode));
  response.headers.set('x-provenance-environment', mode);
  response.headers.set('x-provenance-csp-nonce', nonce);
  return response;
}

export async function proxy(request: NextRequest) {
  const mode = environment();
  const nonce = randomBytes(16).toString('base64');
  const requestHeaders = new Headers(request.headers);
  requestHeaders.set('x-nonce', nonce);
  requestHeaders.set('Content-Security-Policy', csp(nonce, mode));

  const isAuthorityApi = request.nextUrl.pathname.startsWith('/api/v1/');
  if (isAuthorityApi && browserCommandDenied(request)) {
    return withSecurityHeaders(NextResponse.json({ error: { code: 'browser_command_origin_denied', message: 'Cookie-authenticated mutations require a same-origin browser context.' }, meta: { failClosed: true } }, { status: 403 }), nonce, mode);
  }
  if (!isAuthorityApi || mode === 'sandbox' || isLocalAuthorityRoute(request.nextUrl.pathname)) {
    return withSecurityHeaders(NextResponse.next({ request: { headers: requestHeaders } }), nonce, mode);
  }

  const base = process.env.PV_AUTHORITY_API_URL?.replace(/\/$/, '');
  if (!base) {
    return withSecurityHeaders(NextResponse.json({
      error: { code: 'authority_api_unavailable', message: 'The configured authority plane is unavailable. No sandbox fallback was used.' },
      meta: { environment: mode, authoritative: false, failClosed: true },
    }, { status: 503 }), nonce, mode);
  }

  const target = new URL(`${base}${request.nextUrl.pathname}${request.nextUrl.search}`);
  const cookieToken = request.cookies.get(ACCESS_COOKIE)?.value;
  const tenantId = request.headers.get('x-provenance-tenant') ?? request.cookies.get(TENANT_COOKIE)?.value;
  if (cookieToken) requestHeaders.set('authorization', `Bearer ${cookieToken}`);
  if (tenantId) requestHeaders.set('x-provenance-tenant', tenantId);
  requestHeaders.set('x-provenance-environment', mode);
  requestHeaders.delete('cookie');
  requestHeaders.delete('host');

  return withSecurityHeaders(NextResponse.rewrite(target, { request: { headers: requestHeaders } }), nonce, mode);
}

export const config = {
  matcher: [
    {
      source: '/((?!_next/static|_next/image|favicon.ico|icon.png|apple-touch-icon.png|manifest.webmanifest|sw.js|offline.html|.*\\.(?:svg|png|jpg|jpeg|gif|webp|ico|woff2?)$).*)',
      missing: [
        { type: 'header', key: 'next-router-prefetch' },
        { type: 'header', key: 'purpose', value: 'prefetch' },
      ],
    },
  ],
};
