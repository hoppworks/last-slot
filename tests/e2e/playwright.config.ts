import path from 'node:path';

import { defineConfig, devices } from '@playwright/test';

const repositoryRoot = path.resolve(import.meta.dirname, '../..');

export default defineConfig({
  expect: { timeout: 10_000 },
  forbidOnly: true,
  fullyParallel: false,
  outputDir: path.join(repositoryRoot, 'build/playwright/results'),
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'], browserName: 'chromium' },
    },
  ],
  reporter: [
    ['list'],
    ['html', { open: 'never', outputFolder: path.join(repositoryRoot, 'build/playwright/html') }],
    ['junit', { outputFile: path.join(repositoryRoot, 'build/playwright/junit.xml') }],
  ],
  retries: 0,
  testDir: path.join(import.meta.dirname, 'specs'),
  timeout: 90_000,
  use: {
    baseURL: process.env.APP_URL ?? 'http://127.0.0.1:8081',
    locale: 'en-US',
    screenshot: 'only-on-failure',
    trace: 'on',
    video: 'retain-on-failure',
    viewport: { height: 900, width: 1440 },
  },
  workers: 1,
});
