import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
import path from 'node:path';

export default defineConfig({
  plugins: [react()],
  resolve: { alias: { '@': path.resolve(__dirname, './src'), 'server-only': path.resolve(__dirname, './tests/mocks/server-only.ts') } },
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./tests/setup.ts'],
    include: [
      'tests/unit/**/*.test.{ts,tsx}',
      'tests/integration/**/*.test.ts',
      'tests/security/**/*.test.ts',
      'tests/wave1/**/*.test.ts',
    ],
    exclude: [
      'tests/e2e/**',
      'tests/accessibility/**',
      'tests/visual/**',
      'tests/performance/**',
    ],
    coverage: {
      reporter: ['text', 'json-summary', 'html'],
      include: ['src/domain/**', 'src/adapters/**', 'src/store/**', 'src/identity/assets.ts', 'src/identity/state.ts', 'src/operations/kernel.ts', 'src/operations/permissions.ts', 'src/operations/repository.ts', 'src/operations/schemas.ts'],
    },
  },
});
