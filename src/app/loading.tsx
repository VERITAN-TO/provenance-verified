export default function Loading() {
  // No id="main-content" here: this is a Suspense fallback that can be present in the
  // DOM at the same time as the real route's own <main id="main-content"> during
  // streaming, which produced two elements sharing that id — invalid HTML, and the
  // actual cause of #main-content becoming ambiguous right after a skip-link jump.
  return <main className="system-state-page" aria-busy="true"><div className="system-state-mark" aria-hidden="true" /><span>PROVENANCE VERIFIED™</span><h1>Resolving canonical state</h1><p>Loading evidence, authority, registry, and lifecycle projections.</p><div className="system-progress" aria-hidden="true"><i /></div></main>;
}
