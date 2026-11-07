// Run against a local release web build with the existing source-a.pdf fixture.
const {chromium} = require(process.env.RECALL_PLAYWRIGHT_MODULE || 'playwright');
const assert = require('node:assert/strict');
const path = require('node:path');
(async () => {
  const browser = await chromium.launch({channel: 'msedge', headless: true});
  try {
    const page = await browser.newPage({viewport: {width: 1100, height: 850}});
    page.setDefaultTimeout(30000);
    const errors = [];
    page.on('pageerror', e => errors.push(String(e)));
    const button = name => page.getByRole('button', {name, exact: true});
    const data = () => page.evaluate(() => {
      const value = JSON.parse(localStorage.getItem('flutter.recall.data.v3'));
      return typeof value === 'string' ? JSON.parse(value) : value;
    });
    await page.goto(process.env.RECALL_READER_TEST_URL || 'http://127.0.0.1:5218/');
    await page.locator('flt-semantics-placeholder').dispatchEvent('click');
    await button('Recall Reader').click();
    const [chooser] = await Promise.all([
      page.waitForEvent('filechooser'), button('PDF 열기').first().click()
    ]);
    await chooser.setFiles(path.resolve(__dirname, '../build/reader-learning-fixtures/source-a.pdf'));
    await button('1 / 5').waitFor();
    const text = page.getByText('Skin effect', {exact: true}).nth(1);
    await text.waitFor();
    const rect = await text.boundingBox();
    await page.mouse.move(rect.x - 3, rect.y + rect.height / 2);
    await page.mouse.down();
    await page.mouse.move(rect.x + rect.width + 3, rect.y + rect.height / 2, {steps: 20});
    await page.mouse.up();
    await button('내 단어장에 추가').click();
    const fields = page.getByRole('textbox');
    await fields.nth(0).fill('personal skin effect');
    await fields.nth(1).fill('직접 입력한 뜻');
    await fields.nth(2).fill('내 설명');
    await fields.nth(3).fill('Editable source sentence.');
    await button('저장').click();
    await page.waitForTimeout(1000);
    await button('1 / 5').waitFor();
    const saved = (await data()).entries.find(e => e.collector === 'reader:personal');
    assert(saved, 'manual entry must be persisted');
    assert.equal(saved.example, 'Editable source sentence.');
    assert(saved.source.includes('1쪽'));
    await page.reload();
    await page.waitForTimeout(2000);
    assert.deepEqual((await data()).entries.find(e => e.id === saved.id), saved);
    assert.deepEqual(errors, []);
    console.log('PASS: PDF drag selection, personal dialog, manual meaning/note/context, source page, same reading page, web reload persistence; no JS errors.');
  } finally {
    await browser.close();
  }
})().catch(e => {console.error(e); process.exitCode = 1;});
