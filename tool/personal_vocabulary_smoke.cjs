// Run against a local release web build with the existing source-a.pdf fixture.
const {chromium} = require(process.env.RECALL_PLAYWRIGHT_MODULE || 'playwright');
const assert = require('node:assert/strict');
const path = require('node:path');
const fs = require('node:fs');
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
    const plainText = process.env.RECALL_TEST_UNHIGHLIGHTED === '1';
    const selectedText = plainText ? 'Reader source fixture source-a, page 1' : 'Skin effect';
    const text = page.getByText(selectedText, {exact: true}).nth(plainText ? 0 : 1);
    await text.waitFor();
    const rect = await text.boundingBox();
    await page.mouse.move(rect.x - 3, rect.y + rect.height / 2);
    await page.mouse.down();
    await page.mouse.move(rect.x + rect.width + 3, rect.y + rect.height / 2, {steps: 20});
    await page.mouse.up();
    if (plainText) {
      await page.getByText('정의를 찾을 수 없습니다 (Definition not available).', {exact: true}).waitFor();
    }
    await button('내 단어장에 추가').click();
    await page.getByRole('textbox', {name: /단어 또는 전문용어/}).click();
    await page.waitForTimeout(200);
    assert.equal(await page.getByRole('textbox', {name: /단어 또는 전문용어/}).inputValue(), selectedText);
    async function type(name, value) {
      const field = page.getByRole('textbox', {name});
      await field.click();
      await field.press('ControlOrMeta+A');
      await field.pressSequentially(value);
      await page.waitForTimeout(100);
    }
    if (!plainText) await type(/단어 또는 전문용어/, 'personal skin effect');
    await type(/내가 작성한 뜻/, '직접 입력한 뜻');
    await type(/설명 \/ 메모/, '내 설명');
    await type(/원문 문장/, 'Editable source sentence.');
    const screenshots = path.resolve(__dirname, '../build/personal-vocabulary-ui');
    fs.mkdirSync(screenshots, {recursive: true});
    await page.screenshot({path: path.join(screenshots, 'desktop.png')});
    await page.setViewportSize({width: 390, height: 844});
    await page.waitForTimeout(500);
    await page.screenshot({path: path.join(screenshots, 'mobile.png')});
    await button('저장').click();
    await page.waitForTimeout(1000);
    await button('1 / 5').waitFor();
    const saved = (await data()).entries.find(e => e.collector === 'reader:personal');
    assert(saved, 'manual entry must be persisted');
    if (plainText) assert.equal(saved.front, selectedText);
    assert.equal(saved.meanings[0].explanation_ko, '내 설명');
    assert.equal(saved.example, 'Editable source sentence.');
    assert(saved.source.includes('1쪽'));
    await page.reload();
    await page.waitForTimeout(2000);
    assert.deepEqual((await data()).entries.find(e => e.id === saved.id), saved);
    assert.deepEqual(errors, []);
    console.log(`PASS (${plainText ? 'unhighlighted text, no dictionary match' : 'dictionary term'}): PDF drag selection, personal dialog, manual meaning/note/context, source page, same reading page, web reload persistence; no JS errors.`);
  } finally {
    await browser.close();
  }
})().catch(e => {console.error(e); process.exitCode = 1;});
