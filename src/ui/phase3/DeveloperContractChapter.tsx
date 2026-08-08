'use client';

import { useMemo, useState } from 'react';
import Link from 'next/link';
import { useProvenanceStore } from '@/store/useProvenanceStore';
import { CodeSurface, Metric, ProofChapterHeader, StatePill } from './Shared';

type InterfaceType = 'REST' | 'TypeScript' | 'Python' | 'MCP';
type Operation = 'Verify' | 'Resolve registry' | 'Read events' | 'Replay webhook';

const operations: Record<Operation, { method: 'GET' | 'POST'; path: (publicId: string) => string; status: string }> = {
  Verify: { method: 'POST', path: () => '/api/v1/verify', status: 'Implemented fixture endpoint' },
  'Resolve registry': { method: 'GET', path: (publicId) => `/api/v1/registry/${publicId}`, status: 'Implemented fixture endpoint' },
  'Read events': { method: 'GET', path: (publicId) => `/api/v1/events?publicId=${publicId}`, status: 'Implemented fixture endpoint' },
  'Replay webhook': { method: 'POST', path: () => '/api/v1/webhooks/replay', status: 'Implemented fixture endpoint' }
};

export function DeveloperContractChapter() {
  const credential = useProvenanceStore((state) => state.credential);
  const fixtureKey = useProvenanceStore((state) => state.fixtureKey);
  const events = useProvenanceStore((state) => state.events);
  const [interfaceType, setInterfaceType] = useState<InterfaceType>('REST');
  const [operation, setOperation] = useState<Operation>('Verify');
  const example = useMemo(() => getDeveloperExample(interfaceType, operation, credential.publicId, fixtureKey), [interfaceType, operation, credential.publicId, fixtureKey]);
  const contract = operations[operation];

  return (
    <section className="p3-chapter p3-developer" aria-labelledby="p3-developer-title">
      <ProofChapterHeader
        index="06"
        eyebrow="DEVELOPER CONTRACT"
        title="The proof system is callable without granting machines unlimited authority."
        description="Implemented fixture endpoints expose the same credential, registry, event, and delivery state used by the human interface. MCP examples document a future scoped tool contract; they do not claim that a live MCP server is deployed."
        aside={<StatePill tone="cyan">CONTRACT V1 · TEST MODE</StatePill>}
      />

      <div className="p3-developer-grid">
        <aside className="p3-developer-controls">
          <fieldset><legend>Interface</legend>{(['REST', 'TypeScript', 'Python', 'MCP'] as const).map((item) => <button key={item} type="button" className={interfaceType === item ? 'active' : ''} onClick={() => setInterfaceType(item)}>{item}</button>)}</fieldset>
          <fieldset><legend>Operation</legend>{(Object.keys(operations) as Operation[]).map((item) => <button key={item} type="button" className={operation === item ? 'active' : ''} onClick={() => setOperation(item)}>{item}</button>)}</fieldset>
          <div className="p3-contract-meta">
            <Metric label="HTTP contract" value={`${contract.method} ${contract.path(credential.publicId)}`} detail={contract.status} />
            <Metric label="Record" value={credential.publicId} detail={credential.status} />
            <Metric label="Canonical digest" value={credential.integrityHash} detail={`${events.length} signed event references`} />
          </div>
          <div className="p3-contract-links"><Link href="/docs/quickstart">Quickstart</Link><Link href="/docs/api">API reference</Link><Link href="/docs/mcp">MCP boundary</Link><Link href="/developers">Developer overview</Link></div>
        </aside>

        <div className="p3-developer-code">
          <div className="p3-contract-status">
            <StatePill tone={interfaceType === 'MCP' ? 'warn' : 'good'}>{interfaceType === 'MCP' ? 'CONTRACT DOCUMENTED · RUNTIME NOT DEPLOYED' : contract.status.toUpperCase()}</StatePill>
            <span>{operation}</span>
          </div>
          <CodeSurface title={`${interfaceType} · ${operation}`} value={example} label="Copy example" />
          <div className="p3-response-strip"><span>Canonical response</span><strong>{credential.status === 'issued' ? `Tier ${credential.tier} · ${credential.lifecycle}` : `Eligible Tier ${credential.eligibleTier} · ${credential.authorization.status}`}</strong><code>{credential.integrityHash}</code></div>
        </div>
      </div>
    </section>
  );
}

function getDeveloperExample(iface: InterfaceType, operation: Operation, publicId: string, fixtureKey: string) {
  const contract = operations[operation];
  const path = contract.path(publicId);
  const body = operation === 'Verify'
    ? { publicId, fixtureKey }
    : operation === 'Replay webhook'
      ? { attemptId: 'wh_01', reason: 'Operator replay in deterministic Test Mode' }
      : null;

  if (iface === 'REST') return `${contract.method} ${path} HTTP/1.1\nHost: provenanceverified.org\nAuthorization: Bearer pv_test_••••••••\nContent-Type: application/json\nIdempotency-Key: demo-${publicId.toLowerCase()}\n\n${body ? JSON.stringify(body, null, 2) : ''}`;

  if (iface === 'TypeScript') {
    if (operation === 'Verify') return `const response = await fetch("/api/v1/verify", {\n  method: "POST",\n  headers: { "content-type": "application/json" },\n  body: JSON.stringify({ publicId: "${publicId}", fixtureKey: "${fixtureKey}" })\n});\n\nconst result = await response.json();\nconsole.log(result.data.integrityHash);`;
    if (operation === 'Resolve registry') return `const response = await fetch("/api/v1/registry/${publicId}");\nconst record = await response.json();\nconsole.log(record.integrityHash, record.lifecycle);`;
    if (operation === 'Read events') return `const response = await fetch("/api/v1/events?publicId=${publicId}");\nconst result = await response.json();\nconsole.log(result.data.map((event) => event.eventHash));`;
    return `await fetch("/api/v1/webhooks/replay", {\n  method: "POST",\n  headers: { "content-type": "application/json" },\n  body: JSON.stringify({ attemptId: "wh_01", reason: "Operator replay in deterministic Test Mode" })\n});`;
  }

  if (iface === 'Python') return `import requests\n\nresponse = requests.${contract.method === 'GET' ? 'get' : 'post'}(\n    "https://provenanceverified.org${path}",${body ? `\n    json=${JSON.stringify(body, null, 4).replace(/true/g, 'True').replace(/false/g, 'False')},` : ''}\n    headers={"Authorization": "Bearer pv_test_••••••••"},\n)\nresponse.raise_for_status()\nprint(response.json())`;

  return `Tool contract: provenance_${operation.toLowerCase().replaceAll(' ', '_')}\nRuntime status: NOT DEPLOYED\n\nArguments:\n${JSON.stringify({ mode: 'test', public_id: publicId, ...(operation === 'Replay webhook' ? { attempt_id: 'wh_01', reason: 'Operator replay' } : {}) }, null, 2)}\n\nRequired behavior:\n- resolve the same canonical fixture state\n- preserve claim scope and lifecycle\n- return explicit Test Mode metadata\n- never create evidence or issuer authority`;
}
