import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    include: ['tests/**/*.test.ts'],
    fileParallelism: false,       // une seule base de test partagée
    testTimeout: 20000,
  },
});
