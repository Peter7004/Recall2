// Development-only browser check. Uses an externally installed Playwright;
// this is not an application dependency. Supply the two real manual PDF fixtures.
const { chromium } = require(process.env.RECALL_PLAYWRIGHT_MODULE || 'playwright');
const assert = require('node:assert/strict');
const path = require('node:path');
const fs = require('node:fs');
const root = path.resolve(__dirname, '..');
const fixtures = process.env.RECALL_PDF_FIXTURE_DIR || path.join(root, 'output', 'pdf');
const output = path.join(root, 'build', 'reader-navigation-smoke');
fs.mkdirSync(output, { recursive: true });

(async () => {
  const browser = await chromium.launch({ headless: true, channel: process.env.RECALL_BROWSER_CHANNEL || 'msedge' });
  const page = await browser.newPage({ viewport: { width: 1100, height: 850 }, hasTouch: true });
  page.setDefaultTimeout(20000);
  const errors = [];
  page.on('pageerror', e => errors.push(String(e)));
  const button = name => page.getByRole('button', { name, exact: true });
  const settle = ms => page.waitForTimeout(ms);
  const at = number => button(`${number} / 5`).waitFor();

  async function input(number) {
    const field = page.getByRole('textbox', { name: 'PDF 페이지 번호' });
    await field.focus();
    await field.press('Control+A');
    await field.pressSequentially(`${number}`);
    await settle(200);
    assert.equal(await field.inputValue(), `${number}`);
  }

  async function open(version = '1.0.3') {
    await page.mouse.move(700, 700);
    await settle(800); // Dismiss a tooltip left over from a previous import.
    await button('PDF 열기').last().waitFor();
    await settle(500); // Wait for route/tooltip animations before pointer input.
    const initial = await button('PDF 열기').count() > 1;
    const [chooser] = await Promise.all([
      page.waitForEvent('filechooser'),
      page.mouse.click(initial ? 550 : 1080, initial ? 453 : 28),
    ]);
    await chooser.setFiles(path.join(fixtures, `Recall_User_Manual_v${version}_ko.pdf`));
    await button('본문 검색').waitFor();
    await settle(1200);
  }

  async function enter(number, current) {
    await button(`${current} / 5`).click();
    await input(number);
    await button('이동').click();
    await at(number);
    await settle(500);
  }

  try {
    await page.goto(process.env.RECALL_READER_TEST_URL || 'http://127.0.0.1:5202/Recall2/', { waitUntil: 'networkidle' });
    await page.locator('flt-semantics-placeholder').dispatchEvent('click');
    await button('Recall Reader').click();
    await open();
    await at(1);
    await button('1 / 5').click();
    await input(6);
    await button('이동').click();
    await page.getByText('1부터 5 사이의 정수를 입력해 주세요.', { exact: true }).waitFor();
    await settle(500);
    await input(4);
    await button('이동').click();
    await at(4);
    await settle(600);
    await page.mouse.click(1070, 140);
    await at(1);
    await settle(500);
    await page.mouse.move(1070, 140);
    await page.mouse.down();
    await page.mouse.move(1070, 814, { steps: 20 });
    await at(1); // Preview must not navigate until pointer release.
    await page.mouse.up();
    await at(5);
    await settle(600);
    await page.mouse.click(1040, 28);
    await settle(1200);
    await at(5);
    await page.mouse.click(1070, 140);
    await at(1);
    await settle(600);
    await page.mouse.click(1070, 814);
    await at(5);
    await settle(600);
    await enter(2, 5);
    await page.screenshot({ path: path.join(output, 'paged.png') });
    await page.reload({ waitUntil: 'networkidle' });
    const semantics = page.locator('flt-semantics-placeholder');
    if (await semantics.count()) await semantics.dispatchEvent('click');
    await button('Recall Reader').click();
    await open();
    await at(2);
    await open('1.0.2');
    await at(1);
    await open();
    await at(2);
    await button('본문 검색').click();
    await settle(500);
    const query = page.getByRole('textbox', { name: 'PDF 본문 검색' });
    await query.focus();
    await query.pressSequentially('Skin effect');
    await page.getByText(/검색 결과 [1-9]/).waitFor();
    await page.mouse.click(300, 150);
    await at(2);
    await settle(1000);
    await page.screenshot({ path: path.join(output, 'search.png') });
    assert.deepEqual(errors, []);
    console.log('PASS: page entry, rail preview/release in both modes, mode preservation, reload/reopen, independent documents, search navigation.');
  } catch (error) {
    console.error(errors);
    await page.screenshot({ path: path.join(output, 'failure.png') });
    throw error;
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
