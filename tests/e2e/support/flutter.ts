import type { Page } from '@playwright/test';

const accessibilityPlaceholder = /^(?:Enable accessibility|Barrierefreiheit aktivieren)$/u;

export async function enableFlutterAccessibility(page: Page): Promise<void> {
  try {
    await page.locator('flt-semantics [role]').first().waitFor({
      state: 'visible',
      timeout: 2_000,
    });
    return;
  } catch {
    // Flutter may require its browser-provided accessibility control below.
  }

  const placeholder = page.getByRole('button', {
    name: accessibilityPlaceholder,
  });
  try {
    await placeholder.waitFor({ state: 'visible', timeout: 15_000 });
    await placeholder.press('Enter');
  } catch {
    // The following role assertions fail closed if semantics are unavailable.
  }
}
