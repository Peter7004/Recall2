// Real shared-context tabs; no app test hooks or extra app dependencies.
const {chromium}=require(process.env.RECALL_PLAYWRIGHT_MODULE||'playwright');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..'),fixture=path.join(root,'build','reader-safety-fixtures','concurrency.pdf');
const output=path.join(root,'build','reader-safety-smoke');fs.mkdirSync(output,{recursive:true});
const url=process.env.RECALL_READER_TEST_URL||'http://127.0.0.1:5206/Recall2/';
const key='flutter.recall.reader.learning.v1',lock='recall.reader.learning.v1.write';
(async()=>{
 const browser=await chromium.launch({headless:true,channel:process.env.RECALL_BROWSER_CHANNEL||'msedge'});
 const context=await browser.newContext({viewport:{width:1100,height:850}});
 const a=await context.newPage(),b=await context.newPage();
 const errors=[];for(const p of[a,b]){p.setDefaultTimeout(20000);p.on('pageerror',e=>errors.push(String(e)))}
 // Keep B deliberately stale after other tabs write: the next mutation still must
 // reload durable state, not depend on storage event delivery for correctness.
 await b.addInitScript(()=>window.addEventListener('storage',e=>{if(e.key==='flutter.recall.reader.learning.v1')e.stopImmediatePropagation()},true));
 const btn=(p,n)=>p.getByRole('button',{name:n,exact:true});
 const settle=(p,ms=700)=>p.waitForTimeout(ms);
 async function away(p){await p.bringToFront();await p.mouse.move(800,800);await settle(p)}
 async function start(p){await p.goto(url,{waitUntil:'networkidle'});const sem=p.locator('flt-semantics-placeholder');if(await sem.count())await sem.dispatchEvent('click');await btn(p,'Recall Reader').click();await settle(p);}
 async function importPdf(p){await away(p);const[c]=await Promise.all([p.waitForEvent('filechooser'),btn(p,'PDF 열기').first().click()]);await c.setFiles(fixture);await btn(p,'1 / 1').waitFor();await settle(p,1200)}
 async function select(p,term){await away(p);const r=await p.getByText(term,{exact:true}).first().boundingBox();assert(r&&r.height<60);await p.mouse.move(r.x-3,r.y+r.height/2);await p.mouse.down();await p.mouse.move(r.x+r.width+3,r.y+r.height/2,{steps:20});await p.mouse.up();await btn(p,`단어 저장: ${term}`).waitFor();}
 async function data(p,k=key){return p.evaluate(k=>{const raw=localStorage.getItem(k);if(!raw)return null;const value=JSON.parse(raw);return typeof value==='string'?JSON.parse(value):value},k)}
 async function waitCount(p,count){await p.waitForFunction(({key,count})=>{const raw=localStorage.getItem(key);if(!raw)return false;const value=JSON.parse(raw);return (typeof value==='string'?JSON.parse(value):value).terms.length===count},{key,count});}
 async function closePopup(p){await btn(p,'닫기').click();await settle(p)}
 try{
  await start(a);await importPdf(a);await start(b);await btn(b,'문서 열기: concurrency.pdf').click();await btn(b,'1 / 1').waitFor();await settle(b,1200);
  assert.equal(await data(a),null);
  const dictionaryBefore=await data(a,'flutter.recall.data.v3');
  await select(a,'Skin effect');await select(b,'Power factor');
  await a.evaluate(lock=>{window.__held=false;window.__holding=navigator.locks.request(lock,()=>new Promise(resolve=>{window.__held=true;window.__release=resolve}));},lock);
  await a.waitForFunction(()=>window.__held===true);
  await a.bringToFront();await btn(a,'단어 저장: Skin effect').click();await b.bringToFront();await btn(b,'단어 저장: Power factor').click();await settle(a,300);
  assert.equal(await data(a),null,'lock must prevent any early mutation');
  await a.evaluate(()=>window.__release());await waitCount(a,2);await settle(a,800);
  let snapshot=await data(a);assert.deepEqual(snapshot.terms.map(t=>t.term).sort(),['Power factor','Skin effect']);assert.equal(snapshot.occurrences.length,2);
  const strip=d=>({...d,entries:d.entries.map(({isBookmarked,...entry})=>entry)});
  assert.deepEqual(strip(await data(a,'flutter.recall.data.v3')),strip(dictionaryBefore),'Reader must preserve all dictionary fields');
  console.log('PASS: two tabs queue behind held Web Lock, then preserve both learned terms/occurrences and dictionary fields.');
  await closePopup(a);await closePopup(b);
  await away(a);await btn(a,'저장한 단어·출처').click();await settle(a);
  await away(b);await btn(b,'저장한 단어·출처').click();await settle(b);
  await b.getByRole('button',{name:/Power factor/}).last().click();await settle(b);
  await btn(b,'학습 목록에서 삭제').click();await settle(b);await btn(b,'삭제').click();await waitCount(b,1);
  await a.bringToFront();await a.getByRole('button',{name:/Power factor/}).waitFor({state:'detached'});
  await b.bringToFront();await btn(b,'저장한 단어 닫기').click();await settle(b);await select(b,'Power factor');await btn(b,'단어 저장: Power factor').click();await waitCount(b,2);await settle(b,800);
  await a.bringToFront();await a.getByRole('button',{name:/Power factor/}).waitFor();
  console.log('PASS: an already open learning list receives cross-tab removal and addition without reopening or manual refresh.');
  await b.bringToFront();await closePopup(b);await a.bringToFront();await btn(a,'저장한 단어 닫기').click();await settle(a);
  await away(a);await btn(a,'저장한 단어·출처').click();await settle(a);
  await a.getByRole('button',{name:/Skin effect/}).last().click();await settle(a);
  await btn(a,'학습 목록에서 삭제').click();await settle(a);await btn(a,'삭제').click();await waitCount(a,1);await settle(a);
  await select(b,'Power factor');await btn(b,'단어 저장: Power factor').click();await settle(b,1000);
  snapshot=await data(b);assert.equal(snapshot.terms.length,1);assert.equal(snapshot.terms[0].term,'Power factor');assert.equal(snapshot.occurrences.length,1);
  console.log('PASS: a stale tab with suppressed storage events cannot resurrect a deleted term while saving another.');
  await a.screenshot({path:path.join(output,'after-cross-tab-delete.png')});
  // Reload the stale dictionary too; retry bookmark link without resetting data.
  await start(b);await btn(b,'문서 열기: concurrency.pdf').click();await btn(b,'1 / 1').waitFor();await settle(b,1000);await select(b,'Power factor');await btn(b,'단어 저장: Power factor').click();await settle(b,1000);
  assert.equal((await data(b)).terms.length,1);
  const power=(await data(b,'flutter.recall.data.v3')).entries.find(e=>e.front==='Power factor'||e.termEnglish==='Power factor'||e.term_en==='Power factor');
  assert(power&&power.isBookmarked,'fresh dictionary retry must link existing bookmark safely');
  console.log('PASS: reload/retry safely links dictionary bookmark without restoring deleted Reader records.');
  assert.deepEqual(errors,[]);
  const unsupported=await browser.newContext({viewport:{width:1100,height:850}}),p=await unsupported.newPage();p.setDefaultTimeout(20000);p.on('pageerror',e=>errors.push(String(e)));
  await p.addInitScript(()=>Object.defineProperty(navigator,'locks',{value:undefined,configurable:true}));
  await start(p);await importPdf(p);const before=await data(p,'flutter.recall.data.v3');await select(p,'Skin effect');await btn(p,'단어 저장: Skin effect').click();await settle(p,1000);
  await p.waitForFunction(()=>document.body.textContent.includes('안전한 동시 저장을 지원하지 않습니다')||Array.from(document.querySelectorAll('[aria-label]')).some(e=>e.getAttribute('aria-label').includes('안전한 동시 저장을 지원하지 않습니다')));
  assert.equal(await data(p),null);assert.deepEqual(await data(p,'flutter.recall.data.v3'),before);assert.deepEqual(errors,[]);
  await p.screenshot({path:path.join(output,'unsupported-lock-refusal.png')});await unsupported.close();
  console.log('PASS: unsupported lock capability refuses mutation with a clear message, leaving Reader and dictionary data unchanged.');
 }catch(e){console.error(e);console.error(errors);await a.screenshot({path:path.join(output,'failure-a.png')});await b.screenshot({path:path.join(output,'failure-b.png')});throw e;}
 finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
