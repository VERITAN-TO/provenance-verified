'use client';

export default function GlobalError({ reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return <main id="main-content" className="system-state-page system-state-error"><div className="system-state-mark" aria-hidden="true" /><span>CONTROLLED FAILURE</span><h1>The requested state could not be resolved.</h1><p>No credential, seal, or authority decision has been inferred from this failure.</p><button type="button" className="button button-primary" onClick={reset}>Retry canonical read</button></main>;
}
