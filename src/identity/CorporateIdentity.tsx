import Image from 'next/image';
import { corporateAssets } from './assets';
import { R5IdentityObject } from './R5IdentityObject';

export function CorporateLockup({ compact = false, priority = false }: { compact?: boolean; priority?: boolean }) {
  return <span className={`corporate-lockup${compact ? ' corporate-lockup-compact' : ''}`}><Image src={corporateAssets.lockupHorizontal} alt="PROVENANCE VERIFIED™" width={compact ? 210 : 360} height={compact ? 42 : 72} priority={priority} unoptimized /></span>;
}

export function CorporateMark({ className = '', priority = false }: { className?: string; priority?: boolean }) {
  return <Image className={className} src={corporateAssets.masterMark} alt="PROVENANCE VERIFIED™ corporate master mark" width={620} height={620} priority={priority} unoptimized />;
}

export function CorporateMark3D({ className = '', compact = false, interactive = false, priority = false }: { className?: string; compact?: boolean; interactive?: boolean; priority?: boolean }) {
  return <R5IdentityObject variant="corporate" compact={compact} interactive={interactive} priority={priority} className={className} />;
}
