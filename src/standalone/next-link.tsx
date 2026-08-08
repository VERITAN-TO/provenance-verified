import type { AnchorHTMLAttributes, MouseEvent, ReactNode } from 'react';

type Props = AnchorHTMLAttributes<HTMLAnchorElement> & { href: string; children: ReactNode };
function routeHref(href: string) { return href.startsWith('#') ? href : `#${href}`; }
export default function Link({ href, children, onClick, ...props }: Props) {
  const external = /^(https?:|mailto:|tel:)/.test(href);
  return <a {...props} href={external ? href : routeHref(href)} onClick={(event: MouseEvent<HTMLAnchorElement>) => {
    onClick?.(event);
    if (event.defaultPrevented || external) return;
    event.preventDefault();
    if (href.startsWith('/api/')) {
      window.dispatchEvent(new CustomEvent('pv:api-inspect', { detail: href }));
      return;
    }
    const [route, anchor] = href.split('#');
    window.location.hash = route || '/';
    window.dispatchEvent(new Event('pv:navigate'));
    if (anchor) window.setTimeout(() => document.getElementById(anchor)?.scrollIntoView({ behavior: 'smooth' }), 30);
    else window.scrollTo({ top: 0, behavior: 'instant' });
  }}>{children}</a>;
}
