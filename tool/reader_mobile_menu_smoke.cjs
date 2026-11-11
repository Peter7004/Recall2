const {chromium}=require(process.env.RECALL_PLAYWRIGHT_MODULE||'playwright');
const assert=require('node:assert/strict'),path=require('node:path'),fs=require('node:fs');
(async()=>{const b=await chromium.launch({channel:'msedge',headless:true});try{
const p=await b.newPage({viewport:{width:390,height:844}});p.setDefaultTimeout(30000);
await p.goto(process.env.RECALL_READER_TEST_URL||'http://127.0.0.1:5220/');await p.locator('flt-semantics-placeholder').dispatchEvent('click');
const btn=n=>p.getByRole('button',{name:n,exact:true});
await btn('Recall Reader').click();await btn('Reader 메뉴').click();await p.waitForTimeout(300);
const [chooser]=await Promise.all([p.waitForEvent('filechooser'),btn('PDF 열기').last().click()]);await chooser.setFiles(path.resolve(__dirname,'../build/reader-learning-fixtures/source-a.pdf'));await btn('1 / 5').waitFor();
await btn('Reader 메뉴').click();await p.waitForTimeout(300);
const out=path.resolve(__dirname,'../build/ui-v2-smoke');fs.mkdirSync(out,{recursive:true});await p.screenshot({path:path.join(out,'reader-mobile-menu.png')});
await btn('페이지 번호로 이동').click();await p.getByRole('textbox').click();await p.keyboard.press('Control+A');await p.keyboard.type('3');await btn('이동').click();await btn('3 / 5').waitFor();
await btn('Reader 메뉴').click();await btn('본문 검색').click();await p.getByRole('textbox').waitFor();
await p.setViewportSize({width:1100,height:850});await btn('미리보기·북마크').waitFor();await btn('Reader 메뉴').waitFor({state:'detached'});
console.log('PASS mobile Reader menu import/page jump/search and desktop toolbar restoration');
}finally{await b.close();}})().catch(e=>{console.error(e);process.exitCode=1});


