export type PublicEnvironment = 'sandbox' | 'pilot' | 'production';

export function getPublicEnvironment(): PublicEnvironment {
  const value = (process.env.NEXT_PUBLIC_PV_ENVIRONMENT ?? 'sandbox').toLowerCase();
  if (value === 'pilot') return 'pilot';
  if (value === 'production') return 'production';
  return 'sandbox';
}
