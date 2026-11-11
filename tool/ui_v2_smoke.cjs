// Real Flutter web UI. Uses an isolated browser profile, never a user's storage.
const { chromium } = require(process.env.RECALL_PLAYWRIGHT_MODULE || 'playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const out = path.resolve(__dirname, '../build/ui-v2-smoke');
  fs.mkdirSync(out, { recursive: true });
  try {
    const page = await browser.newPage({ viewport: { width: 430, height: 900 } });
    page.setDefaultTimeout(30000);
    const errors = [];
    page.on('pageerror', error => errors.push(String(error)));
    page.on('console', message => { if (/overflowed by|Another exception was thrown/.test(message.text())) errors.push(message.text()); });
    const button = name => page.getByRole('button', { name, exact: true });
    const settle = () => page.waitForTimeout(400);
    const raw = () => page.evaluate(() => localStorage.getItem('flutter.recall.data.v3'));
    async function start() {
      await page.goto(process.env.RECALL_READER_TEST_URL || 'http://127.0.0.1:5220/');
      await page.locator('flt-semantics-placeholder').dispatchEvent('click');
      await page.getByText(/오늘의 전공 영어/).waitFor();
      await settle();
    }
    async function shot(name) { await settle(); await page.screenshot({ path: path.join(out, `${name}.png`) }); }
    await start();
    const before = await raw();
    await shot('home');
    
    await button('Search vocabulary').click();
    await page.getByRole('textbox', { name: '영어·한국어 검색' }).click();
    await page.keyboard.type('Absorption', {delay: 30});
    await settle();
    await page.getByRole('button', { name: /^Absorption / }).waitFor();
    await shot('dictionary');
    assert.equal(await raw(), before, 'opening/searching UI must not rewrite stored data');
    await page.getByRole('button', {name: /^Absorption /}).getByRole('button', {name: '북마크 추가', exact: true}).click();
    await settle();
    const saved = await raw();
    assert.notEqual(saved, before);
    await page.getByText('기록', { exact: true }).click();
    await page.getByText(/학습 기록 매일|학습 기록\n/).waitFor();
    await shot('records');
    await button('Settings').click();
    await page.getByText(/학습 환경/).waitFor();
    await shot('settings');
    await start();
    assert.equal(await raw(), saved, 'bookmarks and data survive reload');
    await button('오늘 학습 시작하기').click();
    await button('정답 확인 →').waitFor();
    await shot('study-front');
    await button('정답 확인 →').click();
    await button('기억했어요').waitFor();
    await shot('study-back');
    await button('기억했어요').click();
    await settle();
    const reviewed = await raw();
    assert.notEqual(reviewed, saved);
    await start();
    assert.equal(await raw(), reviewed);
    for (const [width, height] of [[320, 640], [640, 360], [1280, 900]]) {
      await page.setViewportSize({ width, height });
      await shot(`home-${width}`);
      await button('Search vocabulary').click();
      await shot(`dictionary-${width}`);
      if (width === 640) {
        await page.mouse.move(300, 220);
        await page.mouse.wheel(0, 250);
        await settle();
        const rect = await page.getByRole('button', {name: /^Absorption /}).boundingBox();
        assert(rect && rect.y < 290 && rect.y + rect.height > 92, 'landscape dictionary results are reachable');
        await shot('dictionary-landscape-scrolled');
      }
      await button('홈').click();
      await settle();
    }
    assert.deepEqual(errors, []);
    console.log('PASS: home/dictionary/records/settings/study, bookmark and review reload persistence, unchanged data on browsing; 320/430/640/1280 widths.');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
