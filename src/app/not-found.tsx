import Link from 'next/link';

export default function NotFound() {
  return <main id="main-content" className="system-state-page"><div className="system-state-mark" aria-hidden="true" /><span>404 · NO CANONICAL RECORD</span><h1>This route or record does not exist.</h1><p>Absence is not proof. Verify the public identifier or return to the authority website.</p><div className="system-state-actions"><Link href="/verify" className="button button-primary">Verify an identifier</Link><Link href="/" className="button button-secondary">Return home</Link></div></main>;
}
