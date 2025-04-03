import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

// https://vitejs.dev/config/
export default defineConfig(({ mode }) => {
  // Load env file based on `mode` in the current directory.
  // Set the third parameter to '' to load all env regardless of the `VITE_` prefix.
  const env = loadEnv(mode, process.cwd(), '');
  
  return {
    plugins: [react()],
    root: '.',
    base: '/',
    define: {
      // Make env variables available in the client code
      'process.env': env
    },
    build: {
      outDir: 'dist',
      sourcemap: mode !== 'production', // Only generate sourcemaps in development
      minify: mode === 'production',
      rollupOptions: {
        input: path.resolve(__dirname, 'index.html'),
        output: {
          manualChunks: {
            vendor: ['react', 'react-dom', 'socket.io-client'],
            ui: ['lucide-react', 'react-icons'],
          }
        }
      }
    },
    resolve: {
      alias: {
        '@': path.resolve(__dirname, './src')
      }
    },
    server: {
      host: true,
      port: 5173,
      strictPort: false,
      proxy: {
        // Proxy WebSocket requests in development
        '/socket.io': {
          target: 'ws://localhost:3002',
          ws: true,
        }
      }
    },
    preview: {
      port: 5173,
      host: true
    }
  }
})
