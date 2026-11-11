// Actual bundled corpus, isolated browser storage; no injected statistics.
const {chromium} = require(process.env.RECALL_PLAYWRIGHT_MODULE || 'playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs'), path = require('node:path');
(async () => {
  const browser = await chromium.launch({channel: 'msedge', headless: true});
  const out = path.resolve(__dirname, '../build/corpus-real-smoke');
  fs.mkdirSync(out, {recursive: true});
  try {
    const page = await browser.newPage({viewport: {width: 1100, height: 1000}});
    page.setDefaultTimeout(20000);
    const errors = [];
    page.on('pageerror', e => errors.push(String(e)));
    page.on('console', m => {if (/overflowed by|Another exception was thrown/.test(m.text())) errors.push(m.text());});
    const url = process.env.RECALL_READER_TEST_URL || 'http://127.0.0.1:5230/';
    const button = name => page.getByRole('button', {name, exact: true});
    const snapshot = () => page.evaluate(() => localStorage.getItem('flutter.recall.data.v3'));
    function learningHash(raw) {
      let data = JSON.parse(raw);
      if (typeof data === 'string') data = JSON.parse(data);
      delete data.recentViews; // Opening a detail intentionally records recent views.
      return require('node:crypto').createHash('sha256').update(JSON.stringify(data)).digest('hex');
    }
    const pause = () => page.waitForTimeout(400);
    async function start() {
      await page.goto(url);
      await page.waitForFunction(() => document.querySelector('flt-semantics-placeholder') || document.querySelector('flt-semantics'));
      if (await page.locator('flt-semantics-placeholder').count()) await page.locator('flt-semantics-placeholder').dispatchEvent('click');
      await button('사전').click();
      await page.getByRole('textbox', {name: '영어·한국어 검색'}).waitFor();
    }
    async function search(term) {
      await pause();
      await page.mouse.move(550, 300);
      await page.mouse.wheel(0, -3000);
      await pause();
      if (process.env.RECALL_DEBUG_UI) {
        console.log('SEARCH', term, (await page.locator('body').ariaSnapshot()).slice(-9000));
        await page.screenshot({path: path.join(out, 'before-' + term + '.png')});
      }
      if (await button('검색어 지우기').count()) {await button('검색어 지우기').click(); await pause();}
      await page.getByRole('textbox', {name: '영어·한국어 검색'}).click();
      await pause(); // Flutter creates its editable DOM element after focus.
      await page.keyboard.type(term, {delay: 50});
      await pause();
      if (process.env.RECALL_DEBUG_UI) console.log('TYPED', term, (await page.locator('body').ariaSnapshot()).slice(-6500));
      await page.getByRole('button', {name: new RegExp('^' + term + ' ')}).first().click();
      await pause();
      await page.getByRole('group', {name: /^코퍼스 관측 정보/}).scrollIntoViewIfNeeded();
    }
    async function checkText(text) {
      await pause();
      let target = page.getByText(text, {exact: true});
      if (await target.count() === 0) {
        target = page.getByText(new RegExp('코퍼스 관측 정보.*' + text));
        if (await target.count() === 0) {
          target = page.getByRole('group', {name: /^코퍼스 관측 정보/});
          assert((await target.getAttribute('aria-label')).includes(text), text);
        }
      }
      await target.scrollIntoViewIfNeeded();
      await target.waitFor();
    }
    await start();
    const before = await snapshot();
    await checkText('PDF 22개 · 초록 639개 · 잠정값');
    await search('Voltage');
    await checkText('교재·강의자료: TF 7294 · DF 21');
    await checkText('논문 초록: TF 261 · DF 107');
    await page.screenshot({path: path.join(out, 'voltage.png')});
    await button('집계 기준').click();
    await page.getByText('빈도 집계 기준', {exact: true}).waitFor();
    assert.match(await page.locator('body').ariaSnapshot(), /논문 전체 본문 빈도가 아닙니다/);
    await button('닫기').click();
    await button('Back').click();
    await search('Frequency');
    await checkText('교재·강의자료: TF 1904 · DF 16');
    await checkText('논문 초록: TF 180 · DF 103');
    await checkText('의미 보류 — PDF: 1452회 · 19개 파일');
    await checkText('의미 보류 — 초록: 106회 · 57개 초록');
    await page.screenshot({path: path.join(out, 'frequency-pending.png')});
    await button('Back').click();
    await pause();
    await page.mouse.move(550, 300);
    await page.mouse.wheel(0, -3000);
    await pause();
    await button('검색어 지우기').click();
    await pause();
    await page.getByRole('button', {name: /코퍼스 관측 범위/}).click();
    await pause();
    await page.getByRole('menuitem').nth(1).click();
    await pause();
    if (process.env.RECALL_DEBUG_UI) console.log('FILTER', (await page.locator('body').ariaSnapshot()).slice(-8000));
    assert.match(await page.locator('body').ariaSnapshot(), /전공 영어 사전 225개/);
    await page.getByRole('button', {name: /코퍼스 추천 정렬/}).click();
    await pause();
    await page.getByRole('menuitem').nth(2).click();
    await checkText('논문 초록의 DF 내림차순 · 같은 DF는 TF순');
    assert.equal(learningHash(await snapshot()), learningHash(before), 'statistics must preserve vocabulary/bookmarks/reviews');
    for (const width of [390, 320]) {
      await page.setViewportSize({width, height: 850});
      await pause();
      await page.screenshot({path: path.join(out, `filters-${width}.png`)});
    }
    await page.setViewportSize({width: 1100, height: 1000});
    await pause();
    await button('Reader').click();
    const [chooser] = await Promise.all([page.waitForEvent('filechooser'), button('PDF 열기').first().click()]);
    await chooser.setFiles(path.resolve(__dirname, '../build/reader-learning-fixtures/source-a.pdf'));
    await button('1 / 5').waitFor();
    const term = page.getByText('Skin effect', {exact: true}).nth(1);
    await term.waitFor();
    await pause();
    const r = await term.boundingBox();
    await page.mouse.move(r.x - 3, r.y + r.height / 2);
    await page.mouse.down();
    await page.mouse.move(r.x + r.width + 3, r.y + r.height / 2, {steps: 20});
    await page.mouse.up();
    if (process.env.RECALL_DEBUG_UI) {await pause(); console.log((await page.locator('body').ariaSnapshot()).slice(-11000));}
    await page.getByText(/코퍼스 관측 정보.*교재·강의자료: TF 12 · DF 5.*논문 초록: TF 0 · DF 0/).waitFor();
    await button('단어 저장: Skin effect').click();
    await pause();
    const learning = await page.evaluate(() => localStorage.getItem('flutter.recall.reader.learning.v1'));
    const vocabulary = await snapshot();
    await start();
    assert.equal(await snapshot(), vocabulary);
    assert.equal(await page.evaluate(() => localStorage.getItem('flutter.recall.reader.learning.v1')), learning);
    const raw = JSON.parse(learning), decoded = typeof raw === 'string' ? JSON.parse(raw) : raw;
    assert.equal(decoded.terms.length, 1);
    assert.equal(decoded.occurrences.length, 1);
    assert(decoded.occurrences[0].rects.length > 0);
    assert.deepEqual(errors, []);
    console.log('PASS: real 22-PDF/639-abstract counts, provisional/pending labels, 225 common filter, corpus-specific sorting, 320/390 widths, PDF lookup/save/source and reload persistence.');
  } finally {await browser.close();}
})().catch(error => {console.error(error); process.exitCode = 1;});
