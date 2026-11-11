// Synthetic data is injected only into this isolated browser; never into app assets.
const {chromium} = require(process.env.RECALL_PLAYWRIGHT_MODULE || 'playwright');
const assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
(async () => {
  const browser = await chromium.launch({channel: 'msedge', headless: true});
  try {
    const page = await browser.newPage({viewport: {width: 1100, height: 950}});
    page.setDefaultTimeout(30000);
    const errors = [];
    page.on('pageerror', e => errors.push(String(e)));
    const url = process.env.RECALL_READER_TEST_URL || 'http://127.0.0.1:5220/';
    const button = name => page.getByRole('button', {name, exact: true});
    const output = path.resolve(__dirname, '../build/corpus-smoke');
    fs.mkdirSync(output, {recursive: true});
    async function start() {
      await page.goto(url);
      await page.waitForFunction(() => document.querySelector('flt-semantics-placeholder') || document.querySelector('flt-semantics')); if (await page.locator('flt-semantics-placeholder').count()) await page.locator('flt-semantics-placeholder').dispatchEvent('click');
      await button('사전').click();
      await page.getByRole('textbox', {name: '영어·한국어 검색'}).waitFor();
    }
    const snapshot = () => page.evaluate(() => localStorage.getItem('flutter.recall.data.v3'));
    // Explicitly exercise absent data even when the app ships real statistics.
    const header = 'term_en,textbook_tf,textbook_df,abstract_tf,abstract_df\n';
    await page.route('**/assets/assets/corpus/corpus_stats.csv', route => route.fulfill({body: header, contentType: 'text/csv'}));
    await start();
    assert.equal(await page.getByRole('button', {name: /코퍼스 관측 범위/}).count(), 0);
    const before = await snapshot();
    console.log('PASS: injected header-only data hides corpus UI; dictionary starts normally.');
    const fixture = fs.readFileSync(path.resolve(__dirname, '../test/fixtures/corpus_small.csv'), 'utf8');
    await page.route('**/assets/assets/corpus/corpus_metadata.json', route => route.fulfill({body: JSON.stringify({
      schema_version: 1, basis: 'provisional_accepted', date: '2026-11-11', textbook_documents: 22, abstract_documents: 639,
      csv_sha256: require('node:crypto').createHash('sha256').update(fixture).digest('hex'), pending: {},
    }), contentType: 'application/json'}));
    await page.route('**/assets/assets/corpus/corpus_stats.csv', route => route.fulfill({body: fixture, contentType: 'text/csv; charset=utf-8'}));
    await start();
    assert.equal(await snapshot(), before, 'attaching corpus must not rewrite user data');
    if (process.env.RECALL_DEBUG_UI) console.log((await page.locator('body').ariaSnapshot()).slice(0, 7000));
    await page.getByRole('button', {name: /코퍼스 관측 범위/}).waitFor();
    // Flutter dropdowns expose their current item as a button.
    await page.getByRole('button', {name: /코퍼스 관측 범위/}).click();
    await page.waitForTimeout(400);
    if (process.env.RECALL_DEBUG_UI) console.log((await page.locator('body').ariaSnapshot()).slice(-4500));
    await page.getByRole('menuitem').nth(1).click(); // CorpusScope.both
    await page.waitForTimeout(400);
    assert.equal(await page.getByRole('button', {name: /^Absorption /}).count(), 0);
    await page.screenshot({path: path.join(output, 'filter.png')});
    await page.getByRole('button', {name: /Skin effect/}).first().click();
    await page.waitForTimeout(400);
    if (process.env.RECALL_DEBUG_UI) console.log((await page.locator('body').ariaSnapshot()).slice(0, 8000));
    await page.getByRole('group', {name: /코퍼스 관측 정보.*교재·강의자료: TF 20 · DF 4/}).scrollIntoViewIfNeeded();
    await button('Back').click();
    await button('Reader').click();
    const [chooser] = await Promise.all([page.waitForEvent('filechooser'), button('PDF 열기').first().click()]);
    await chooser.setFiles(path.resolve(__dirname, '../build/reader-learning-fixtures/source-a.pdf'));
    await button('1 / 5').waitFor();
    const text = page.getByText('Skin effect', {exact: true}).nth(1);
    await text.waitFor();
    const r = await text.boundingBox();
    await page.mouse.move(r.x - 3, r.y + r.height / 2);
    await page.mouse.down();
    await page.mouse.move(r.x + r.width + 3, r.y + r.height / 2, {steps: 20});
    await page.mouse.up();
    await page.waitForTimeout(500);
    if (process.env.RECALL_DEBUG_UI) console.log((await page.locator('body').ariaSnapshot()).slice(-11000));
    await page.getByText(/코퍼스 관측 정보.*교재·강의자료: TF 20 · DF 4/).waitFor();
    await button('단어 저장: Skin effect').click();
    await page.waitForTimeout(700);
    const learning = await page.evaluate(() => {
      const raw = JSON.parse(localStorage.getItem('flutter.recall.reader.learning.v1'));
      return typeof raw === 'string' ? JSON.parse(raw) : raw;
    });
    assert.equal(learning.terms.length, 1);
    assert.equal(learning.occurrences.length, 1);
    assert(learning.occurrences[0].rects.length > 0);
    await page.waitForTimeout(4200); // Let the save notification dismiss before visual QA.
    await page.getByText(/코퍼스 관측 정보.*교재·강의자료: TF 20 · DF 4/).scrollIntoViewIfNeeded();
    await page.screenshot({path: path.join(output, 'pdf-corpus.png')});
    assert.deepEqual(errors, []);
    console.log('PASS: mocked corpus filter/detail/PDF statistics, unchanged vocabulary storage and original source saving.');
  } finally { await browser.close(); }
})().catch(error => {console.error(error); process.exitCode = 1;});
