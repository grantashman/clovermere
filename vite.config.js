import { defineConfig } from 'vite';
import { resolve } from 'node:path';

export default defineConfig({
  base: process.env.GITHUB_PAGES ? '/hobbit-moon/' : '/',
  build: {
    rollupOptions: {
      input: {
        main: resolve(import.meta.dirname, 'index.html'),
        game: resolve(import.meta.dirname, 'game.html')
      }
    }
  }
});
