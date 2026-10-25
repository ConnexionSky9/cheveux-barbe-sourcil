import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// En développement, l'API (backend, port 3000) est servie via le proxy : même origine que le site.
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: { '/api': { target: 'http://localhost:3000', changeOrigin: false } },
    fs: { allow: ['..'] },   // accès à ../shared/theme.css
  },
  build: { outDir: 'dist', sourcemap: false, assetsInlineLimit: 2048 },
});
