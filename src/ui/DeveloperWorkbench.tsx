'use client';

import { useMemo, useState } from 'react';
import { CopyButton } from './CopyButton';
import { ScrollCodeBlock } from './ScrollCodeBlock';

const examples = {
  TypeScript: `const result = await provenance.verify({\n  publicId: 'PV-TEST-T4D004',\n  mode: 'test'\n});\n\nif (result.credential.status !== 'issued') {\n  console.log(result.authorization.blockers);\n}`,
  Python: `result = provenance.verify(\n    public_id="PV-TEST-T4D004",\n    mode="test",\n)\n\nif result.credential.status != "issued":\n    print(result.authorization.blockers)`,
  cURL: `curl --request POST https://provenanceverified.org/api/v1/verify \\\n  --header 'content-type: application/json' \\\n  --data '{"publicId":"PV-TEST-T4D004","fixtureKey":"t4"}'`,
  MCP: `// Contract documented; runtime not deployed\nprovenance_verify({\n  mode: 'test',\n  public_id: 'PV-TEST-T4D004'\n})`,
} as const;

type ExampleName = keyof typeof examples;

export function DeveloperWorkbench() {
  const [active, setActive] = useState<ExampleName>('TypeScript');
  const code = useMemo(() => examples[active], [active]);
  return (
    <section className="developer-workbench" aria-labelledby="developer-workbench-title">
      <div className="developer-workbench-copy">
        <span>ONE CANONICAL RESPONSE</span>
        <h2 id="developer-workbench-title">Integrate the proof transaction without recreating authority logic.</h2>
        <p>Clients consume evidence scope, policy eligibility, issuer authorization, lifecycle, registry state, signature state, and mark authorization from the same response.</p>
        <dl>
          <div><dt>Eligibility</dt><dd>Evidence and protocol result</dd></div>
          <div><dt>Issuance</dt><dd>Human and issuer authority result</dd></div>
          <div><dt>Registry</dt><dd>Canonical public projection</dd></div>
          <div><dt>Mark</dt><dd>Separate controlled authorization</dd></div>
        </dl>
      </div>
      <div className="developer-code-panel">
        <div className="developer-code-tabs" role="tablist" aria-label="SDK examples">
          {Object.keys(examples).map((name) => <button key={name} role="tab" aria-selected={active === name} data-live-label={`Load ${name} SDK example`} onClick={() => setActive(name as ExampleName)}>{name}</button>)}
          <CopyButton value={code} />
        </div>
        <ScrollCodeBlock key={active} code={code} ariaLabel={`${active} SDK example`} speed={6} />
        <footer><span>TEST MODE</span><span>{active === 'MCP' ? 'CONTRACT ONLY' : 'DETERMINISTIC FIXTURE'}</span></footer>
      </div>
    </section>
  );
}
