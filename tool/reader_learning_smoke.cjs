const {chromium}=require(process.env.RECALL_PLAYWRIGHT_MODULE||'playwright');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..'), fixtures=path.join(root,'build','reader-learning-fixtures');
const output=path.join(root,'build','reader-learning-smoke');fs.mkdirSync(output,{recursive:true});
const hash=name=>crypto.createHash('sha256').update(fs.readFileSync(path.join(fixtures,name))).digest('hex');
(async()=>{
 const browser=await chromium.launch({headless:true,channel:process.env.RECALL_BROWSER_CHANNEL||'msedge'});
 const page=await browser.newPage({viewport:{width:1100,height:850}});page.setDefaultTimeout(20000);
 const errors=[];page.on('pageerror',e=>errors.push(String(e)));
 const button=n=>page.getByRole('button',{name:n,exact:true}), settle=ms=>page.waitForTimeout(ms);
 const at=n=>button(`${n} / 5`).waitFor();
 async function away(){await page.mouse.move(800,800);await settle(700);}
 async function start(){
  await page.goto(process.env.RECALL_READER_TEST_URL||'http://127.0.0.1:5205/Recall2/',{waitUntil:'networkidle'});
  const sem=page.locator('flt-semantics-placeholder');if(await sem.count())await sem.dispatchEvent('click');
  await button('Recall Reader').click();await settle(700);
 }
 async function importPdf(name){await away();const[c]=await Promise.all([page.waitForEvent('filechooser'),button('PDF 열기').first().click()]);await c.setFiles(path.join(fixtures,name));await settle(1800);}
 async function data(key){return page.evaluate(key=>{const raw=localStorage.getItem(`flutter.${key}`);if(!raw)return null;let v=JSON.parse(raw);return typeof v==='string'?JSON.parse(v):v;},key);}
 async function learning(){return data('recall.reader.learning.v1');}
 async function select(index){
  const text=page.getByText('Skin effect',{exact:true}).nth(index);await text.waitFor();const r=await text.boundingBox();assert(r&&r.height<60);
  await page.mouse.move(r.x-3,r.y+r.height/2);await page.mouse.down();await page.mouse.move(r.x+r.width+3,r.y+r.height/2,{steps:20});await page.mouse.up();
  await button('단어 저장: Skin effect').waitFor();await settle(300);
 }
 async function save(){await button('단어 저장: Skin effect').click();await settle(1000);}
 async function closePopup(){await button('닫기').click();await settle(400);}
 async function openLearning(){await away();await button('저장한 단어·출처').click();await settle(600);await page.getByRole('button',{name:/Skin effect/}).last().click();await settle(600);}
 async function source(id){const records=(await learning()).occurrences;const i=records.findIndex(s=>s.id===id);const s=records[i];await button(`원문으로 이동: ${s.documentTitle} · ${s.page}쪽 · 위치 ${i+1}`).click();await settle(1000);}
 try{
  await start();await importPdf('source-a.pdf');await at(1);
  const dictionaryBefore=await data('recall.data.v3');
  await select(1);await save();const second=(await learning()).occurrences[0];
  assert(second.rects[0][1]>.45,'must store the SECOND physical occurrence, not first string match');
  await save();assert.equal((await learning()).terms.length,1);assert.equal((await learning()).occurrences.length,1);
  await closePopup();await select(0);await save();await closePopup();
  assert.equal((await learning()).occurrences.length,2,'same text on same page, different offsets must stay distinct');
  await button('다음 페이지').click();await at(2);await settle(600);
  await openLearning();await source(second.id);await at(1);
  const returned=await data(`recall.reader.progress.v1.${hash('source-a.pdf')}`);
  assert(returned.y>.4,'source jump must target second occurrence geometry');
  await page.screenshot({path:path.join(output,'exact-source-return.png')});
  await away();await button('이전 읽던 위치로 돌아가기').click();await at(2);
  console.log('PASS: native selection save, duplicate prevention, two same-page occurrences, exact source geometry and return to prior page.');
  await importPdf('source-b.pdf');await at(1);await button('다음 페이지').click();await at(2);await away();await button('다음 페이지').click();await at(3);await settle(700);
  await select(0);await save();await closePopup();
  assert.equal((await learning()).terms.length,1);assert.equal((await learning()).occurrences.length,3);
  await openLearning();await source(second.id);await at(1);
  await away();await button('이전 읽던 위치로 돌아가기').click();await at(3);
  await away();await button('사전 단어 항상 강조로 전환').click();await settle(1200);
  await start();await button('문서 열기: source-b.pdf').click();await at(3);await settle(1000);
  await button('커서를 올릴 때만 강조로 전환').waitFor();
  assert.equal((await learning()).occurrences.length,3);
  const after=await data('recall.data.v3');
  const clean=d=>({...d,entries:d.entries.map(({isBookmarked,...entry})=>entry)});
  assert.deepEqual(clean(after),clean(dictionaryBefore),'only intentional bookmark flag may change');
  console.log('PASS: one term across two documents, cross-document source jump/back, restart persistence, highlight preference and vocabulary fields preserved.');
  await away();await button('Back').click();await settle(700);
  await button('Search vocabulary').click();await settle(600);
  const query=page.getByRole('textbox',{name:'영어·한국어 검색'});await query.focus();await query.pressSequentially('Skin effect');await settle(700);
  await page.getByRole('button',{name:/Skin effect/}).first().click();await settle(600);
  await button('PDF 학습 출처').click();await settle(700);
  await button('PDF 원문 열기: 위치 1').click();await at(1);await settle(900);
  assert((await data(`recall.reader.progress.v1.${hash('source-a.pdf')}`)).y>.4);
  console.log('PASS: existing dictionary card opens saved PDF occurrence directly through source list.');
  // Corrupt one metadata entry. Other library entries must remain usable, no overwrite.
  const bad=hash('source-a.pdf');
  await page.evaluate(async id=>{
   const db=await new Promise((resolve,reject)=>{const r=indexedDB.open('recall.reader.library.v1');r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error)});
   await new Promise((resolve,reject)=>{const tx=db.transaction('documents','readwrite');tx.objectStore('documents').put('{broken',id);tx.oncomplete=resolve;tx.onabort=()=>reject(tx.error)});db.close();
  },bad);
  await start();await button('문서 열기: source-b.pdf').waitFor();await button('문서 열기: source-b.pdf').click();await at(3);
  console.log('PASS: corrupted IndexedDB metadata is isolated; healthy PDF reopens.');
  await importPdf('image-only.pdf');await button('1 / 1').waitFor();await settle(1200);
  await page.waitForFunction(()=>document.body.textContent.includes('이 페이지에서 텍스트를 읽을 수 없습니다.')||Array.from(document.querySelectorAll('[aria-label]')).some(e=>e.getAttribute('aria-label').includes('이 페이지에서 텍스트를 읽을 수 없습니다.')));
  await page.screenshot({path:path.join(output,'image-only-state.png')});
  await away();await button('문서 목록').click();await settle(700);
  await button('문서 관리: source-b.pdf').click();await settle(500);
  await page.getByRole('menuitem',{name:'삭제',exact:true}).click();await settle(500);
  await button('삭제').click();await settle(900);
  assert.equal((await learning()).occurrences.length,3,'PDF deletion must retain learning sources');
  // Close the library sheet through Escape, then open the global saved-term list.
  await page.keyboard.press('Escape');await settle(600);
  await openLearning();
  const buttons=page.getByRole('button',{name:/원문으로 이동:/});
  assert.equal(await buttons.count(),3);for(const b of await buttons.all())assert(await b.isDisabled());
  await page.screenshot({path:path.join(output,'deleted-source-links.png')});
  console.log('PASS: app PDF deletion retains all learned terms/source quotes and disables missing/corrupt document links.');
  assert.deepEqual(errors,[]);
  console.log('PASS: synthetic image-only PDF reports unavailable text, not missing dictionary entries; no JS runtime errors.');
 }catch(e){console.error(errors);console.error(e);if(await page.locator('flt-semantics-host').count())console.error(await page.locator('flt-semantics-host').ariaSnapshot());await page.screenshot({path:path.join(output,'failure.png')});throw e;}
 finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1});
