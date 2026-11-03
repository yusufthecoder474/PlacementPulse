import { defineConfig } from '@playwright/test';

// The backend is NOT started by this config. Start it separately first:
//   cd backend && bundle exec rails server -p 3000
// (with PostgreSQL and Redis running, and seeds applied). This config only
// starts the Vite dev server, and reuses it if one is already running.
export default defineConfig({
  testDir: './e2e',
  timeout: 60_000,
  expect: { timeout: 10_000 },
  fullyParallel: false,
  retries: 0,
  reporter: 'list',
  use: {
    baseURL: 'http://localhost:5173',
    trace: 'on-first-retry',
  },
  webServer: {
    command: 'npm run dev -- --port 5173',
    url: 'http://localhost:5173',
    reuseExistingServer: true,
    timeout: 120_000,
  },
});
