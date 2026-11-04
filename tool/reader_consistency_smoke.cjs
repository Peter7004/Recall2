// Persisted fixtures and missing-file injection in a disposable browser profile.
const {chromium}=require(process.env.RECALL_PLAYWRIGHT_MODULE||'playwright');
const assert=require('node:assert/strict'),path=require('node:path'),fs=require('node:fs');
const root=path.resolve(__dirname,'..'),out=path.join(root,'build','reader-consistency-smoke');fs.mkdirSync(out,{recursive:true});
(async()=>{
 const browser=await chromium.launch({headless:true,channel:process.env.RECALL_BROWSER_CHANNEL||'msedge'});
 const page=await browser.newPage({viewport:{width:1100,height:850}});page.setDefaultTimeout(20000);
 const errors=[];page.on('pageerror',e=>errors.push(String(e)));
 const btn=n=>page.getByRole('button',{name:n,exact:true}),settle=(ms=600)=>page.waitForTimeout(ms);
 const url=process.env.RECALL_READER_TEST_URL||'http://127.0.0.1:5206/Recall2/';
 async function start(open=true){await page.goto(url,{waitUntil:'networkidle'});const sem=page.locator('flt-semantics-placeholder');if(await sem.count())await sem.dispatchEvent('click');await btn('Recall Reader').click();await settle();if(open){await btn('문서 열기: concurrency.pdf').click();await btn('1 / 1').waitFor();await settle(1000)}}
 async function raw(){return page.evaluate(()=>localStorage.getItem('flutter.recall.reader.learning.v1'))}
 async function read(key){return page.evaluate(key=>{const v=JSON.parse(localStorage.getItem(`flutter.${key}`));return typeof v==='string'?JSON.parse(v):v},key)}
 async function edit(mode){await page.evaluate(mode=>{
  function change(key,action){const outer=JSON.parse(localStorage.getItem(key)),data=typeof outer==='string'?JSON.parse(outer):outer;action(data);localStorage.setItem(key,JSON.stringify(typeof outer==='string'?JSON.stringify(data):data))}
  const k='flutter.recall.reader.learning.v1',outer=JSON.parse(localStorage.getItem(k)),saved=typeof outer==='string'?JSON.parse(outer):outer,id=saved.terms[0].cardId;
  if(mode==='fixture')change(k,d=>{Object.assign(d.terms[0],{meaning:'저장 당시 뜻',definition:'Saved definition sentinel',explanation:'저장 당시 설명'})});
  change('flutter.recall.data.v3',d=>{if(mode==='delete'){d.entries=d.entries.filter(e=>e.id!==id);for(const deck of d.decks)deck.entryIds=deck.entryIds.filter(i=>i!==id)}else{const c=d.entries.find(e=>e.id===id);c.meanings[0].meaning_ko='최신 뜻';c.meanings[0].definition_en=mode==='empty'?'':'Current definition sentinel';c.meanings[0].explanation_ko=mode==='empty'?'':'최신 설명'}});
 },mode)}
 async function list(){await page.mouse.move(800,800);await btn('저장한 단어·출처').click();await settle();await page.getByRole('button',{name:/Skin effect/}).last().click();await settle()}
 async function visible(text){await page.waitForFunction(text=>document.body.textContent.includes(text)||Array.from(document.querySelectorAll('[aria-label]')).some(e=>(e.getAttribute('aria-label')||'').includes(text)),text)}
 try{
  await start(false);const[c]=await Promise.all([page.waitForEvent('filechooser'),btn('PDF 열기').first().click()]);await c.setFiles(path.join(root,'build','reader-safety-fixtures','concurrency.pdf'));await btn('1 / 1').waitFor();await settle(1300);
  const r=await page.getByText('Skin effect',{exact:true}).first().boundingBox();assert(r);await page.mouse.move(r.x-3,r.y+r.height/2);await page.mouse.down();await page.mouse.move(r.x+r.width+3,r.y+r.height/2,{steps:20});await page.mouse.up();await btn('단어 저장: Skin effect').click();await settle(1000);
  await edit('fixture');const saved=await raw();const source=(await read('recall.reader.learning.v1')).occurrences[0];
  await start();await list();await visible('최신 뜻');await visible('Current definition sentinel');await visible('최신 설명');await visible('현재 사전 정보');assert.equal(await page.getByText('Saved definition sentinel',{exact:true}).count(),0);assert.equal(await raw(),saved);
  console.log('PASS: all displayed fields use current persisted dictionary; saved snapshot unchanged.');
  await edit('empty');await start();await list();await visible('최신 뜻');assert.equal(await page.getByText('Saved definition sentinel',{exact:true}).count(),0);assert.equal(await page.getByText('저장 당시 설명',{exact:true}).count(),0);
  // Remove bytes AFTER the link was enabled. Keep metadata, quotes and all keys.
  const link=page.getByRole('button',{name:/원문으로 이동:/});assert(await link.isEnabled());
  await page.evaluate(async id=>{const db=await new Promise((resolve,reject)=>{const r=indexedDB.open('recall.reader.library.v1');r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error)});try{await new Promise((resolve,reject)=>{const tx=db.transaction('bytes','readwrite');tx.objectStore('bytes').delete(id);tx.oncomplete=resolve;tx.onabort=()=>reject(tx.error)})}finally{db.close()}},source.documentId);
  await link.click();await visible('문서가 삭제되었거나 접근할 수 없습니다. 원본 PDF를 다시 가져와 주세요.');await settle(5000);await list();assert(await page.getByRole('button',{name:/원문으로 이동:/}).isDisabled());assert.equal(await raw(),saved);await page.screenshot({path:path.join(out,'missing-managed-file.png')});
  await btn('저장한 단어 닫기').click();await btn('Back').click();await btn('Search vocabulary').click();const query=page.getByRole('textbox',{name:'영어·한국어 검색'});await query.focus();await query.pressSequentially('Skin effect');await settle();await page.getByRole('button',{name:/Skin effect/}).first().click();await btn('PDF 학습 출처').click();await settle();assert(await btn('PDF 원문 열기: 위치 1').isDisabled());
  console.log('PASS: emptied current fields stay empty; both source screens disable metadata-only PDFs, and navigation rechecks an already enabled link.');
  await edit('delete');await start(false);await list();await visible('저장 당시 뜻');await visible('Saved definition sentinel');await visible('저장 당시 설명');await visible('현재 사전 항목을 찾을 수 없어 저장 당시 정보를 표시합니다.');assert.equal(await raw(),saved);assert.deepEqual(errors,[]);await page.screenshot({path:path.join(out,'saved-snapshot-fallback.png')});
  console.log('PASS: removed dictionary entry falls back to labeled complete snapshot without modifying learning history; no JS errors.');
 }catch(e){await page.screenshot({path:path.join(out,'failure.png')});throw e}finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
