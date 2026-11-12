// Run with Bun after `bun run build`. Uses Playwright + an installed Chromium.
// UI success is mocked; real database persistence is covered by api.integration.mjs.
// No DATABASE_URL is inherited and no data is written.
import assert from 'node:assert/strict';
import { mkdtemp, rm, mkdir } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';

delete process.env.DATABASE_URL;
const root = resolve(import.meta.dirname, '..');
const { chromium } = await import(process.env.PLAYWRIGHT_MODULE || 'playwright');
const { default: handler } = await import(pathToFileURL(join(root, 'dist/server/server.js')));
const originalCwd = process.cwd();
const temporary = await mkdtemp(join(tmpdir(), 'beef-waitlist-test-'));
const screenshots = process.env.SCREENSHOT_DIR && resolve(process.env.SCREENSHOT_DIR);
if (screenshots) await mkdir(screenshots, { recursive: true });
process.chdir(temporary);
const server = Bun.serve({
  hostname: '127.0.0.1', port: 0,
  async fetch(request) {
    const pathname = new URL(request.url).pathname;
    if (pathname.startsWith('/assets/') || /^\/beef-model-[\w-]+\.jpg$/.test(pathname)) {
      const file = Bun.file(join(root, 'dist/client', pathname));
      if (await file.exists()) return new Response(file);
    }
    return handler.fetch(request);
  },
});
let browser;
try {
  browser = await chromium.launch({
    executablePath: process.env.CHROMIUM_PATH || undefined,
    headless: true, args: ['--no-sandbox'],
  });
  const page = await browser.newPage({ viewport: { width: 1280, height: 900 }, reducedMotion: 'reduce' });
  // External fonts are irrelevant to behavior; tests remain local.
  await page.route('https://**/*', route => route.abort());
  await page.goto(server.url.href);
  const form = page.getByRole('form', { name: 'Join the BEEF waitlist' });
  const input = page.getByRole('textbox', { name: 'Email address' });
  const submit = form.getByRole('button');
  const status = page.getByRole('status');
  await page.getByRole('link', { name: 'Join the waitlist' }).first().click();
  assert.equal(new URL(page.url()).hash, '#join');
  assert.ok(await form.isVisible());
  assert.equal(await status.textContent(), '');
  await submit.click();
  assert.equal(await input.evaluate(el => el.validity.valueMissing), true);
  console.log('PASS anchor and empty-email validation');

  await input.fill('fictional-adult@example.test');
  let requests = 0;
  let release;
  const gate = new Promise(resolve => { release = resolve; });
  await page.route('**/*', async route => {
    if (route.request().method() !== 'POST') return route.fallback();
    requests++;
    await gate;
    await route.abort('failed');
  });
  await submit.click();
  await page.waitForFunction(() => document.querySelector('form').getAttribute('aria-busy') === 'true');
  assert.equal(await submit.isDisabled(), true);
  assert.equal(await input.getAttribute('readonly'), '');
  assert.match(await status.textContent(), /Saving your place/);
  await form.evaluate(el => { el.requestSubmit(); el.requestSubmit(); });
  release();
  await status.filter({ hasText: "couldn't confirm" }).waitFor();
  assert.equal(requests, 1);
  assert.equal(await submit.isEnabled(), true);
  assert.equal(await input.inputValue(), 'fictional-adult@example.test');
  console.log('PASS loading, duplicate-submit guard, network failure and retained input');
  if (screenshots) await page.screenshot({ path: join(screenshots, 'desktop-retry.png'), fullPage: true });
  await page.unroute('**/*');

  // Server validation exercises the real HTTP route without database access.
  await input.fill('adult@example.x');
  await submit.click();
  await status.filter({ hasText: 'undercooked' }).waitFor();
  assert.equal(await input.inputValue(), 'adult@example.x');
  console.log('PASS server validation error');

  await input.fill('fictional-adult@example.test');
  assert.equal(await status.textContent(), '');
  await page.route('**/api/waitlist', route => route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ ok: true }) }));
  await submit.click();
  await status.filter({ hasText: "You're on the waitlist" }).waitFor();
  assert.equal(await input.inputValue(), '');
  console.log('PASS retry and confirmed success UI (mock receipt; database tested separately)');
  await page.unroute('**/api/waitlist');

  await input.fill('another-fictional-adult@example.test');
  await submit.click();
  await status.filter({ hasText: "couldn't confirm" }).waitFor();
  assert.equal(await submit.isEnabled(), true);
  assert.equal(await input.inputValue(), 'another-fictional-adult@example.test');
  console.log('PASS storage failure recovers without false success');

  for (const width of [320, 390, 768, 1280]) {
    await page.setViewportSize({ width, height: 844 });
    await form.scrollIntoViewIfNeeded();
    assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), `overflow at ${width}`);
    await input.focus();
    await page.keyboard.press('Tab');
    assert.equal(await submit.evaluate(el => el === document.activeElement), true);
    assert.equal(await submit.evaluate(el => getComputedStyle(el).outlineStyle), 'solid');
  }
  assert.equal(await page.locator('.animate-marquee').evaluate(el => getComputedStyle(el).animationName), 'none');
  await page.setViewportSize({ width: 390, height: 844 });
  await form.scrollIntoViewIfNeeded();
  if (screenshots) await page.screenshot({ path: join(screenshots, 'mobile-retry.png') });
  console.log('PASS responsive widths, keyboard focus and reduced motion');
} finally {
  await browser?.close();
  server.stop(true);
  process.chdir(originalCwd);
  await rm(temporary, { recursive: true, force: true });
}
