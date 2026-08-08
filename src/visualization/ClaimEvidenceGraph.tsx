'use client';

import { useMemo } from 'react';
import { hierarchy, tree } from 'd3';
import { useProvenanceStore } from '@/store/useProvenanceStore';

interface NodeDatum {
  name: string;
  type: 'root' | 'claim' | 'evidence';
  id?: string;
  children?: NodeDatum[];
}

export function ClaimEvidenceGraph() {
  const fixture = useProvenanceStore((state) => state.fixture);
  const selectedEvidenceId = useProvenanceStore((state) => state.selectedEvidenceId);
  const selectedClaimId = useProvenanceStore((state) => state.selectedClaimId);
  const selectEvidence = useProvenanceStore((state) => state.selectEvidence);
  const selectClaim = useProvenanceStore((state) => state.selectClaim);

  const layout = useMemo(() => {
    const data: NodeDatum = {
      name: 'Credential',
      type: 'root',
      children: fixture.claims.map((claim) => ({
        name: claim.label,
        id: claim.id,
        type: 'claim',
        children: claim.evidenceIds.map((id) => ({
          name: fixture.evidence.find((item) => item.id === id)?.label ?? id,
          id,
          type: 'evidence',
        })),
      })),
    };
    const root = hierarchy(data);
    tree<NodeDatum>().size([310, 620])(root);
    return root;
  }, [fixture]);

  return (
    <div className="graph-wrap">
      <svg className="claim-graph" viewBox="0 0 700 350" aria-hidden="true" focusable="false">
        <g transform="translate(30,20)">
          {layout.links().map((link, index) => {
            const sourceY = link.source.y ?? 0;
            const sourceX = link.source.x ?? 0;
            const targetY = link.target.y ?? 0;
            const targetX = link.target.x ?? 0;
            return (
              <path
                key={`${sourceY}-${sourceX}-${targetY}-${targetX}-${index}`}
                d={`M${sourceY},${sourceX} C${(sourceY + targetY) / 2},${sourceX} ${(sourceY + targetY) / 2},${targetX} ${targetY},${targetX}`}
                className="graph-link"
              />
            );
          })}
          {layout.descendants().map((node, index) => {
            const data = node.data;
            const selected = data.id === selectedEvidenceId || data.id === selectedClaimId;
            return (
              <g
                key={`${data.type}-${data.id ?? data.name}-${index}`}
                transform={`translate(${node.y},${node.x})`}
                className="graph-pointer-node"
                onClick={() => {
                  if (data.type === 'claim') selectClaim(data.id ?? null);
                  if (data.type === 'evidence') selectEvidence(data.id ?? null);
                }}
              >
                <circle r={data.type === 'root' ? 7 : 5} className={selected ? 'graph-node selected' : `graph-node ${data.type}`} />
                <text x={data.type === 'root' ? -10 : 10} y={4} textAnchor={data.type === 'root' ? 'end' : 'start'}>
                  {data.name.length > 28 ? `${data.name.slice(0, 28)}…` : data.name}
                </text>
              </g>
            );
          })}
        </g>
      </svg>

      <table className="data-table graph-equivalent">
        <caption>Accessible claim and evidence correspondence</caption>
        <thead>
          <tr><th>Claim</th><th>Status</th><th>Evidence</th></tr>
        </thead>
        <tbody>
          {fixture.claims.map((claim) => (
            <tr key={claim.id}>
              <td><button type="button" className="graph-table-action" onClick={() => selectClaim(claim.id)}>{claim.label}</button></td>
              <td>{claim.status}</td>
              <td>
                {claim.evidenceIds.length === 0
                  ? 'None'
                  : claim.evidenceIds.map((id, index) => (
                    <span key={`${claim.id}-${id}`}>
                      {index > 0 ? '; ' : ''}
                      <button type="button" className="graph-table-action" onClick={() => selectEvidence(id)}>
                        {fixture.evidence.find((item) => item.id === id)?.label ?? id}
                      </button>
                    </span>
                  ))}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
