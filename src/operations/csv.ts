import { gemstoneAssetInputSchema } from './schemas';
import type { z } from 'zod';

export type GemstoneAssetInput = z.infer<typeof gemstoneAssetInputSchema>;

export interface CsvImportResult {
  assets: GemstoneAssetInput[];
  errors: Array<{ row: number; message: string }>;
}

function parseRows(text: string): string[][] {
  const rows: string[][] = [];
  let row: string[] = [];
  let field = '';
  let quoted = false;
  for (let index = 0; index < text.length; index += 1) {
    const char = text[index];
    if (quoted) {
      if (char === '"' && text[index + 1] === '"') { field += '"'; index += 1; }
      else if (char === '"') quoted = false;
      else field += char;
      continue;
    }
    if (char === '"') quoted = true;
    else if (char === ',') { row.push(field.trim()); field = ''; }
    else if (char === '\n') { row.push(field.trim()); rows.push(row); row = []; field = ''; }
    else if (char !== '\r') field += char;
  }
  if (field.length || row.length) { row.push(field.trim()); rows.push(row); }
  return rows.filter((item) => item.some(Boolean));
}

function nullableNumber(value: string) {
  if (!value.trim()) return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : Number.NaN;
}

export function parseGemstoneCsv(text: string): CsvImportResult {
  const rows = parseRows(text);
  if (rows.length < 2) return { assets: [], errors: [{ row: 1, message: 'CSV requires a header and at least one data row.' }] };
  const headers = rows[0].map((header) => header.trim());
  const index = new Map(headers.map((header, position) => [header, position]));
  const required = ['serial', 'material', 'shape', 'weightCarats', 'lengthMm', 'widthMm', 'depthMm'];
  const missing = required.filter((header) => !index.has(header));
  if (missing.length) return { assets: [], errors: [{ row: 1, message: `Missing required columns: ${missing.join(', ')}` }] };
  const get = (row: string[], key: string) => row[index.get(key) ?? -1] ?? '';
  const assets: GemstoneAssetInput[] = [];
  const errors: CsvImportResult['errors'] = [];
  const serials = new Set<string>();
  rows.slice(1, 5001).forEach((row, offset) => {
    const rowNumber = offset + 2;
    const serial = get(row, 'serial').trim().toUpperCase();
    if (serials.has(serial)) { errors.push({ row: rowNumber, message: `Duplicate serial ${serial}.` }); return; }
    const candidate = {
      serial,
      lotId: get(row, 'lotId') || undefined,
      material: get(row, 'material'),
      shape: get(row, 'shape'),
      cut: get(row, 'cut'),
      colorDescription: get(row, 'colorDescription'),
      clarityDescription: get(row, 'clarityDescription'),
      treatmentDisclosure: get(row, 'treatmentDisclosure') || 'Unknown / not declared',
      originClaim: get(row, 'originClaim') || 'Not claimed',
      supplierReference: get(row, 'supplierReference'),
      laboratoryReportReference: get(row, 'laboratoryReportReference'),
      identifyingFeatures: get(row, 'identifyingFeatures').split('|').map((item) => item.trim()).filter(Boolean),
      measurements: {
        weightCarats: nullableNumber(get(row, 'weightCarats')),
        lengthMm: nullableNumber(get(row, 'lengthMm')),
        widthMm: nullableNumber(get(row, 'widthMm')),
        depthMm: nullableNumber(get(row, 'depthMm')),
      },
    };
    const parsed = gemstoneAssetInputSchema.safeParse(candidate);
    if (!parsed.success) { errors.push({ row: rowNumber, message: parsed.error.issues.map((issue) => `${issue.path.join('.')}: ${issue.message}`).join('; ') }); return; }
    serials.add(serial);
    assets.push(parsed.data);
  });
  if (rows.length > 5001) errors.push({ row: 5002, message: 'CSV exceeds the 5,000-row request limit.' });
  return { assets, errors };
}
