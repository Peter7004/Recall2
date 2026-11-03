// Real controlled PDFs from make_reader_outline_fixture.py; external Playwright.
const {chromium}=require(process.env.RECALL_PLAYWRIGHT_MODULE||'playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..');
const fixtures=process.env.RECALL_P3_FIXTURE_DIR||path.join(root,'build','reader-navigator-fixtures');
const output=path.join(root,'build','reader-document-navigator-smoke');fs.mkdirSync(output,{recursive:true});
const outline='p3-outline-fixture.pdf',plain='p3-plain-fixture.pdf';
const hash=name=>crypto.createHash('sha256').update(fs.readFileSync(path.join(fixtures,name))).digest('hex');
(async()=>{
 const browser=await chromium.launch({headless:true,channel:process.env.RECALL_BROWSER_CHANNEL||'msedge'});
 const page=await browser.newPage({viewport:{width:1100,height:850}});page.setDefaultTimeout(20000);
 const errors=[];page.on('pageerror',e=>errors.push(String(e)));
 const button=name=>page.getByRole('button',{name,exact:true});
 const settle=ms=>page.waitForTimeout(ms);
 const at=n=>button(`${n} / 5`).waitFor();
 async function away(){await page.mouse.move(800,800);await settle(700);}
 async function start(){
  await page.goto(process.env.RECALL_READER_TEST_URL||'http://127.0.0.1:5204/Recall2/',{waitUntil:'networkidle'});
  const sem=page.locator('flt-semantics-placeholder');if(await sem.count())await sem.dispatchEvent('click');
  await button('Recall Reader').click();await settle(700);
 }
 async function importPdf(name){
  await away();
  const [chooser]=await Promise.all([page.waitForEvent('filechooser'),button('PDF 열기').last().click()]);
  await chooser.setFiles(path.join(fixtures,name));await button('문서 탐색').waitFor();await settle(1000);
 }
 async function goto(n,current){
  await button(`${current} / 5`).click();
  const input=page.getByRole('textbox',{name:'PDF 페이지 번호'});await input.focus();
  await input.press('Control+A');await input.pressSequentially(`${n}`);await button('이동').click();await at(n);await settle(500);
 }
 async function nav(){await away();await button('문서 탐색').click();await settle(650);}
 async function tab(name){await page.getByRole('tab',{name:new RegExp(name)}).click();await settle(700);}
 async function bookmark(){await away();await button('페이지 북마크 추가').click();await settle(600);}
 async function data(id){return page.evaluate(id=>{
  const value=localStorage.getItem(`flutter.recall.reader.pageBookmarks.v1.${id}`);
  if(value==null)return null;const parsed=JSON.parse(value);return typeof parsed==='string'?JSON.parse(parsed):parsed;
 },id);}
 try{
  await start();await importPdf(outline);await at(1);
  const dictionary=await page.evaluate(()=>localStorage.getItem('flutter.recall.data.v3'));
  await goto(2,1);await bookmark();await goto(4,2);await bookmark();
  assert.deepEqual((await data(hash(outline))).map(b=>b.page),[2,4]);
  await nav();await button('북마크로 이동: 2쪽').click();await at(2);await settle(600);
  const saved=(await data(hash(outline))).find(b=>b.page===2);
  const restored=await page.evaluate(id=>{
   const raw=JSON.parse(localStorage.getItem(`flutter.recall.reader.progress.v1.${id}`));
   return typeof raw==='string'?JSON.parse(raw):raw;
  },hash(outline));
  assert(Math.abs(restored.x-saved.x)<.03&&Math.abs(restored.y-saved.y)<.03,'page-relative bookmark location must be restored');
  await away();await button('페이지별 보기로 전환').click();await settle(1200);await at(2);
  await nav();await button('북마크로 이동: 4쪽').click();await at(4);await settle(600);
  assert((await page.locator('[role="button"]').allTextContents()).includes('연속 스크롤로 전환'),'bookmark navigation must preserve viewing mode');
  await nav();await tab('문서 목차');await button('목차로 이동: Section A.1').click();await at(2);await settle(700);
  await page.screenshot({path:path.join(output,'outline-destination.png')});
  console.log('PASS: per-page bookmarks, position navigation, current mode preservation, nested embedded outline destination.');
  await nav();await tab('미리보기');await settle(1800);
  await page.screenshot({path:path.join(output,'thumbnails.png')});
  assert.equal(await page.getByText('미리보기 재시도',{exact:true}).count(),0,'thumbnail render failed');
  await button('5쪽으로 이동').click();await at(5);await settle(700);
  for(let i=0;i<2;i++){
   await nav();await tab('미리보기');await button('문서 탐색 닫기').click();await settle(650);
  }
  await start();await button(`문서 열기: ${outline}`).click();await at(5);await settle(700);
  await nav();await button('북마크로 이동: 2쪽').waitFor();await button('북마크로 이동: 4쪽').waitFor();
  await button('문서 탐색 닫기').click();await settle(600);
  await importPdf(plain);await at(1);await bookmark();
  assert.deepEqual((await data(hash(outline))).map(b=>b.page),[2,4]);
  assert.deepEqual((await data(hash(plain))).map(b=>b.page),[1]);
  await nav();await tab('문서 목차');
  await page.waitForFunction(()=>Array.from(document.querySelectorAll('[aria-label]')).some(e=>e.getAttribute('aria-label').includes('이 PDF에는 문서 목차가 없습니다.')));
  await button('문서 탐색 닫기').click();await settle(600);
  console.log('PASS: rendered thumbnails/page navigation, repeated close/cancel, restart bookmark persistence, separate documents, absent-outline state.');
  await away();await button('문서 목록').click();await settle(700);
  await button(`문서 관리: ${plain}`).click();await settle(450);await page.mouse.click(780,375);await settle(450);
  await page.getByText(/페이지 북마크를 삭제합니다/).waitFor();await button('취소').click();await settle(500);
  assert.deepEqual((await data(hash(plain))).map(b=>b.page),[1]);
  await away();await button(`문서 관리: ${plain}`).click();await settle(450);await page.mouse.click(780,375);await settle(450);
  await button('삭제').click();await settle(1000);
  assert.equal(await data(hash(plain)),null);
  assert.deepEqual((await data(hash(outline))).map(b=>b.page),[2,4]);
  assert.equal(await page.evaluate(()=>localStorage.getItem('flutter.recall.data.v3')),dictionary);
  assert.deepEqual(errors,[]);
  await page.screenshot({path:path.join(output,'after-delete.png')});
  console.log('PASS: delete warning/cancel, document bookmark cleanup, other document and dictionary preservation; no JS errors.');
 }catch(error){console.error(errors);await page.screenshot({path:path.join(output,'failure.png')});throw error;}
 finally{await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1});


