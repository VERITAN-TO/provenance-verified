'use client';
import { useState } from 'react';
export function CopyButton({ value, label = 'Copy' }: { value: string; label?: string }) {
  const [copied, setCopied] = useState(false);
  return <button className="copy-button" onClick={async () => { await navigator.clipboard?.writeText(value); setCopied(true); window.setTimeout(() => setCopied(false), 1400); }} aria-label={`${label} to clipboard`}>{copied ? 'Copied' : label}</button>;
}
