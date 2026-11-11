// Real bundled frequencies and an isolated browser profile; no user storage touched.
const {chromium} = require(process.env.RECALL_PLAYWRIGHT_MODULE || 'playwright');
const assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
(async () => {
  const browser = await chromium.launch({channel: 'msedge', headless: true});
  const out = path.resolve(__dirname, '../build/daily-corpus-smoke');
  fs.mkdirSync(out, {recursive: true});
  try {
    const page = await browser.newPage({viewport: {width: 390, height: 900}});
    page.setDefaultTimeout(30000);
    const errors = [];
    page.on('pageerror', e => errors.push(String(e)));
    page.on('console', m => {if (/overflowed by|Another exception was thrown/.test(m.text())) errors.push(m.text());});
    const button = name => page.getByRole('button', {name, exact: true});
    const pause = () => page.waitForTimeout(500);
    const snapshot = () => page.evaluate(() => localStorage.getItem('flutter.recall.data.v3'));
    async function start() {
      await page.goto(process.env.RECALL_READER_TEST_URL || 'http://127.0.0.1:5231/');
      await page.waitForFunction(() => document.querySelector('flt-semantics-placeholder') || document.querySelector('flt-semantics'));
      if (await page.locator('flt-semantics-placeholder').count()) await page.locator('flt-semantics-placeholder').dispatchEvent('click');
      await pause();
      if (process.env.RECALL_DEBUG_UI) console.log((await page.locator('body').ariaSnapshot()).slice(0, 6500));
      await page.getByRole('checkbox', {name: '교재 중심', exact: true}).waitFor();
    }
    async function choose(name) {
      const chip = page.getByRole('checkbox', {name, exact: true});
      await chip.click();
      await pause();
      assert.equal(await chip.getAttribute('aria-checked'), 'true');
    }
    async function suggestion(term, df, tf) {
      await page.mouse.move(180, 600);
      await page.mouse.wheel(0, 650);
      await pause();
      const group = page.getByRole('group', {name: /^오늘의 추천 단어/});
      await group.scrollIntoViewIfNeeded();
      const label = await group.getAttribute('aria-label');
      assert(label.includes(term), label);
      assert(label.includes(`등장 문서 ${df}개 · 출현 ${tf}회`), label);
      await page.screenshot({path: path.join(out, `${term.toLowerCase()}-recommendation.png`)});
      await page.mouse.wheel(0, -2000);
      await pause();
    }
    await start();
    const original = await snapshot();
    await choose('논문 초록 중심');
    assert.equal(await snapshot(), original, 'changing focus must not rewrite vocabulary/history');
    await suggestion('Voltage', 107, 261);
    await button('오늘 학습 시작하기').click();
    await pause();
    if (process.env.RECALL_DEBUG_UI) console.log('STUDY', (await page.locator('body').ariaSnapshot()).slice(-8000));
    await page.getByRole('group', {name: 'Voltage', exact: true}).waitFor();
    await button('정답 확인 →').click();
    await button('기억했어요').click();
    await page.getByRole('group', {name: 'Frequency', exact: true}).waitFor();
    await button('홈').click();
    await pause();
    const learned = await snapshot();
    await suggestion('Frequency', 103, 180);
    await choose('교재 중심');
    assert.equal(await snapshot(), learned);
    await suggestion('Current', 21, 5952);
    await page.getByRole('button', {name: /학습$/}).last().click();
    await page.getByRole('group', {name: 'Current', exact: true}).waitFor(); // Reset default session on focus change.
    await button('홈').click();
    await choose('논문 초록 중심');
    await page.setViewportSize({width: 320, height: 850});
    await start();
    assert.equal(await snapshot(), learned, 'reload preserves learned counts and card identities');
    assert.equal(await page.getByRole('checkbox', {name: '논문 초록 중심', exact: true}).getAttribute('aria-checked'), 'true');
    await page.screenshot({path: path.join(out, 'focus-320.png')});
    await button('오늘 학습 시작하기').click();
    await page.getByRole('group', {name: 'Frequency', exact: true}).waitFor();
    assert.deepEqual(errors, []);
    console.log('PASS real textbook/abstract recommendations and daily queue, DF/TF evidence, learned-word skipping, default session reset, 320/390 mobile, focus/review persistence and unchanged storage on switching.');
  } finally {await browser.close();}
})().catch(e => {console.error(e); process.exitCode = 1;});
