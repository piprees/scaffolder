import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  use: {
    baseURL: 'http://127.0.0.1:3000',
  },
  webServer: {
    command:
      'pnpm run build && HOSTNAME=127.0.0.1 PORT=3000 node .next/standalone/frontend/server.js',
    url: 'http://127.0.0.1:3000',
    reuseExistingServer: true,
  },
});
