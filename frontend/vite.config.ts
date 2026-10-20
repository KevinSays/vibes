import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'
import tsconfigPaths from 'vite-tsconfig-paths'

// https://vitejs.dev/config/
export default defineConfig(({ mode }) => {
  // Load environment variables
  const env = loadEnv(mode, '.', '');
  
  // Get backend configuration from environment variables
  const backendHost = env.VITE_BACKEND_HOST || 'localhost';
  const backendPort = env.VITE_BACKEND_PORT || '8080';
  const backendUrl = `${backendHost}:${backendPort}`;

  return {
    plugins: [react(), tsconfigPaths()],
    build: {
      // Embedded into the Go binary (backend/cmd/web.go) and committed, so
      // running VIBES needs no Node/npm. Rebuild after frontend changes.
      outDir: '../backend/cmd/web',
      emptyOutDir: true,
      rollupOptions: {
        // No content hashes in filenames: Rollup 2 mixes absolute paths into
        // them, so builds from different checkouts (e.g. CI) never match the
        // committed bundle. The backend sends Cache-Control: no-cache instead.
        output: {
          entryFileNames: 'assets/[name].js',
          chunkFileNames: 'assets/[name].js',
          assetFileNames: 'assets/[name][extname]',
        },
      },
    },
    server: {
      proxy: {
        '/ws': {
          target: `ws://${backendUrl}`,
          ws: true,
        },
        '/api': {
          target: `http://${backendUrl}`,
          changeOrigin: true,
          secure: false
        }
      }
    }
  };
}); 