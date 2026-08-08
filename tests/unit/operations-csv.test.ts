import { describe, expect, it } from 'vitest';
import { parseGemstoneCsv } from '@/operations/csv';

const header = 'serial,material,shape,weightCarats,lengthMm,widthMm,depthMm,colorDescription,identifyingFeatures';

describe('Phase 4 CSV importer', () => {
  it('parses quoted fields and escaped quotes', () => {
    const csv = `${header}\nCSV-001,Natural sapphire,Oval,1.2,6,4,3,"Royal, vivid blue","needle at 2 o""clock|feather"`;
    const result = parseGemstoneCsv(csv);
    expect(result.errors).toEqual([]);
    expect(result.assets).toHaveLength(1);
    expect(result.assets[0].colorDescription).toBe('Royal, vivid blue');
    expect(result.assets[0].identifyingFeatures).toContain('needle at 2 o"clock');
  });

  it('rejects duplicate serials inside the same file', () => {
    const csv = `${header}\nDUP-001,Ruby,Oval,1,6,4,3,,\nDUP-001,Ruby,Cushion,2,7,5,4,,`;
    const result = parseGemstoneCsv(csv);
    expect(result.assets).toHaveLength(1);
    expect(result.errors[0].message).toContain('Duplicate serial DUP-001');
  });

  it('rejects missing required headers', () => {
    const result = parseGemstoneCsv('serial,material\nA-001,Ruby');
    expect(result.assets).toEqual([]);
    expect(result.errors[0].message).toContain('Missing required columns');
  });

  it('accepts exactly 5,000 rows and rejects rows beyond the request limit', () => {
    const rows = Array.from({ length: 5001 }, (_, index) => `ROW-${index + 1},Sapphire,Oval,1,6,4,3,,`);
    const result = parseGemstoneCsv(`${header}\n${rows.join('\n')}`);
    expect(result.assets).toHaveLength(5000);
    expect(result.errors).toContainEqual({ row: 5002, message: 'CSV exceeds the 5,000-row request limit.' });
  });
});
