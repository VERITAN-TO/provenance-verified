import { PublicRecordClient } from './PublicRecordClient';

export function PublicRecord({ publicId }: { publicId: string }) {
  return <PublicRecordClient publicId={publicId} />;
}
