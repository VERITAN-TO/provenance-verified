'use client';

import Link from 'next/link';
import { useMemo, useState } from 'react';
import { docsContent } from './content';

export function DocsIndex() {
  const [query, setQuery] = useState('');
  const results = useMemo(() => {
    const normalized = query.trim().toLowerCase();
    return Object.entries(docsContent).filter(([, document]) => {
      if (!normalized) return true;
      const haystack = [document.title, document.lede, ...document.sections.flatMap((section) => [section.heading, section.body])].join(' ').toLowerCase();
      return haystack.includes(normalized);
    });
  }, [query]);

  return (
    <div className="docs-index" data-results={results.length}>
      <div className="docs-search">
        <div>
          <label htmlFor="docs-search">Search documentation</label>
          <small>Searches guides, API contracts, events, webhooks, SDKs, MCP boundaries, and Test Mode.</small>
        </div>
        <input
          id="docs-search"
          type="search"
          placeholder="Search quickstart, API, events, webhooks, MCP…"
          value={query}
          onChange={(event) => setQuery(event.target.value)}
          autoComplete="off"
        />
        <span aria-live="polite">{results.length} result{results.length === 1 ? '' : 's'}</span>
      </div>
      <div className="docs-result-grid">
        {results.map(([slug, document], index) => (
          <Link key={slug} href={`/docs/${slug}`}>
            <span>{String(index + 1).padStart(2, '0')}</span>
            <div><h2>{document.title}</h2><p>{document.lede}</p></div>
            <em aria-hidden="true">↗</em>
          </Link>
        ))}
      </div>
      {results.length === 0 && (
        <div className="docs-no-results" role="status">
          <strong>No documentation matched “{query}”.</strong>
          <p>Try evidence, registry, events, SDK, webhook, lifecycle, or Test Mode.</p>
          <button type="button" onClick={() => setQuery('')}>Clear search</button>
        </div>
      )}
    </div>
  );
}
