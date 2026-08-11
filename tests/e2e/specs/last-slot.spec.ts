import { expect, test, type Page } from '@playwright/test';

import { enableFlutterAccessibility } from '../support/flutter.js';

const competitors = ['Ada Lovelace', 'Linus Torvalds'] as const;

async function openBooking(page: Page, customerName: string): Promise<void> {
  await page.goto('/book');
  await enableFlutterAccessibility(page);
  await expect(
    page.getByRole('heading', { name: 'One slot. Two browsers. One correct result.' }),
  ).toBeVisible();
  await expect(page.getByText('Architecture review', { exact: true })).toBeVisible();
  const nameField = page.getByRole('textbox', { name: 'Your name' });
  await nameField.click();
  await page.waitForTimeout(100);
  await nameField.pressSequentially(customerName);
}

test('two visitors compete for the last slot and exactly one persisted booking wins', async ({
  browser,
}) => {
  const visitorA = await browser.newContext();
  const visitorB = await browser.newContext();
  const pageA = await visitorA.newPage();
  const pageB = await visitorB.newPage();

  try {
    await Promise.all([
      openBooking(pageA, competitors[0]),
      openBooking(pageB, competitors[1]),
    ]);

    await Promise.all([
      pageA.getByRole('button', { name: 'Book the last slot' }).click(),
      pageB.getByRole('button', { name: 'Book the last slot' }).click(),
    ]);

    await expect
      .poll(async () => {
        const pages = [pageA, pageB];
        const successes = await Promise.all(
          pages.map((page) =>
            page
                .locator('span')
                .filter({ hasText: /^Booking confirmed$/u })
                .isVisible(),
          ),
        );
        const conflicts = await Promise.all(
          pages.map((page) =>
            page
                .locator('span')
                .filter({ hasText: /^Slot already booked$/u })
                .isVisible(),
          ),
        );
        return `${successes.filter(Boolean).length}:${conflicts.filter(Boolean).length}`;
      })
      .toBe('1:1');

    const admin = await browser.newPage();
    await admin.goto('/admin');
    await enableFlutterAccessibility(admin);
    await expect(admin.getByText('Booked', { exact: true })).toBeVisible();
    await expect(admin.getByText('1 confirmed booking', { exact: true })).toBeVisible();
    await expect(admin.getByText(/^(?:Ada Lovelace|Linus Torvalds)$/u)).toBeVisible();

    await Promise.all([pageA.reload(), pageB.reload()]);
    await Promise.all([
      enableFlutterAccessibility(pageA),
      enableFlutterAccessibility(pageB),
    ]);
    await expect(pageA.getByText('Booked', { exact: true })).toBeVisible();
    await expect(pageB.getByText('Booked', { exact: true })).toBeVisible();
  } finally {
    await visitorA.close();
    await visitorB.close();
  }
});
