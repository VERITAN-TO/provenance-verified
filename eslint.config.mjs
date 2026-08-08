import nextVitals from 'eslint-config-next/core-web-vitals';
import nextTs from 'eslint-config-next/typescript';

const config = [
  ...nextVitals,
  ...nextTs,
  { ignores: ['.next/**', 'coverage/**', 'evidence/**', 'node_modules/**', 'supabase/functions/**', '.audit-types/**', 'scripts/**'] },
  { files: ['**/*.cjs'], rules: { '@typescript-eslint/no-require-imports': 'off' } },
  {
    rules: {
      'react-hooks/set-state-in-effect': 'warn',
    },
  },
];

export default config;
