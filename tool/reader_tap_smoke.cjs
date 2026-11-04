const { chromium } = require(process.env.RECALL_PLAYWRIGHT_MODULE || 'playwright');
const assert = require('node:assert/strict');
const path = require('node:path');

async function verify(browser, touch) {
  const page = await browser.newPage({ viewport: { width: 1100, height: 850 }, hasTouch: touch });
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  const button = name => page.getByRole('button', { name, exact: true });
  const save = button('단어 저장: Skin effect');
  const term = page.getByText('Skin effect', { exact: true });
  async function tapTerm(index) {
    const box = await term.nth(index).boundingBox();
    assert(box);
    const x = box.x + box.width / 2;
    const y = box.y + box.height / 2;
    if (touch) await page.touchscreen.tap(x, y);
    else await page.mouse.click(x, y);
    await save.waitFor();
  }
  try {
    await page.goto(process.env.RECALL_READER_TEST_URL || 'http://127.0.0.1:5206/Recall2/',
      { waitUntil: 'networkidle' });
    const semantics = page.locator('flt-semantics-placeholder');
    if (await semantics.count()) await semantics.dispatchEvent('click');
    await button('Recall Reader').click();
    const [chooser] = await Promise.all([
      page.waitForEvent('filechooser'), button('PDF 열기').first().click(),
    ]);
    await chooser.setFiles(path.resolve(__dirname, '../build/reader-safety-fixtures/concurrency.pdf'));
    await button('1 / 1').waitFor();
    await term.nth(1).waitFor();
    await tapTerm(1);
    await save.click();
    await page.waitForFunction(() => {
      const raw = localStorage.getItem('flutter.recall.reader.learning.v1');
      if (!raw) return false;
      const value = JSON.parse(raw);
      return (typeof value === 'string' ? JSON.parse(value) : value).occurrences.length === 1;
    });
    const occurrence = await page.evaluate(() => {
      const value = JSON.parse(localStorage.getItem('flutter.recall.reader.learning.v1'));
      return (typeof value === 'string' ? JSON.parse(value) : value).occurrences[0];
    });
    assert.equal(occurrence.text, 'Skin effect');
    assert(occurrence.context.lastIndexOf('Skin effect') > occurrence.context.indexOf('Skin effect'));
    assert(occurrence.rects[0][1] > 0.24, 'Expected the lower occurrence');
    console.log(`PASS: ${touch ? 'touch' : 'mouse'} lookup and exact source save`);
    await button('닫기').click();
    await button('확대').click();
    await page.waitForTimeout(650);
    await tapTerm(0);
    if (touch) {
      await button('닫기').click();
      const box = await term.first().boundingBox();
      assert(box);
      const x = Math.round(box.x + box.width / 2);
      const y = Math.round(box.y + box.height / 2);
      const session = await page.context().newCDPSession(page);
      await session.send('Input.dispatchTouchEvent', {
        type: 'touchStart', touchPoints: [{ x, y }],
      });
      for (let delta = 20; delta <= 100; delta += 20) {
        await session.send('Input.dispatchTouchEvent', {
          type: 'touchMove', touchPoints: [{ x, y: y + delta }],
        });
      }
      await session.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
      await page.waitForTimeout(750);
      assert.equal(await save.count(), 0, 'A touch drag must not open the term popup');
    }
    assert.deepEqual(errors, []);
    console.log(`PASS: ${touch ? 'touch' : 'mouse'} lookup, exact source save, and zoomed lookup`);
  } finally {
    await page.close();
  }
}

(async () => {
  const browser = await chromium.launch({ channel: process.env.RECALL_BROWSER_CHANNEL || 'msedge' });
  try {
    await verify(browser, false);
    await verify(browser, true);
  } finally {
    await browser.close();
  }
})().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
