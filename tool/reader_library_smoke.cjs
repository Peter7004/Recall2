// External Playwright installation, real manual fixtures, no app dependency.
const {chromium}=require(process.env.RECALL_PLAYWRIGHT_MODULE||'playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'..');
const output=path.join(root,'build','reader-library-smoke');fs.mkdirSync(output,{recursive:true});
const fixtures=process.env.RECALL_PDF_FIXTURE_DIR||path.join(root,'output','pdf');
const filename='Recall_User_Manual_v1.0.3_ko.pdf';
(async()=>{
 const browser=await chromium.launch({headless:true,channel:process.env.RECALL_BROWSER_CHANNEL||'msedge'});
 const page=await browser.newPage({viewport:{width:1100,height:850}});
 page.setDefaultTimeout(20000);
 const errors=[];page.on('pageerror',e=>errors.push(String(e)));
 const button=n=>page.getByRole('button',{name:n,exact:true});
 const settle=ms=>page.waitForTimeout(ms);
 const at=n=>button(`${n} / 5`).waitFor();
 async function start(){
  await page.goto(process.env.RECALL_READER_TEST_URL||'http://127.0.0.1:5203/Recall2/',{waitUntil:'networkidle'});
  const sem=page.locator('flt-semantics-placeholder');if(await sem.count())await sem.dispatchEvent('click');
  await button('Recall Reader').click();await settle(700);
 }
 async function importPdf(version='1.0.3'){
  await page.mouse.move(700,700);await settle(700);
  const [chooser]=await Promise.all([page.waitForEvent('filechooser'),button('PDF 열기').last().click()]);
  await chooser.setFiles(path.join(fixtures,`Recall_User_Manual_v${version}_ko.pdf`));
  await button('문서 목록').waitFor();await settle(1200);
 }
 async function library(){await page.mouse.move(700,700);await settle(700);await button('문서 목록').click();await settle(700);}
 async function menu(title){await page.mouse.move(700,700);await settle(500);await button(`문서 관리: ${title}`).click();await settle(450);}
 // Fixed viewport and Material sheet width: pointer targets are the two menu rows.
 async function chooseManagement(action){await page.mouse.click(780,action==='rename'?325:375);await settle(450);}
 async function counts(){return page.evaluate(async()=>{
  const db=await new Promise((resolve,reject)=>{const r=indexedDB.open('recall.reader.library.v1');r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error);});
  try{return await Promise.all(['documents','bytes'].map(store=>new Promise((resolve,reject)=>{
   const r=db.transaction(store).objectStore(store).count();r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error);
  })));}finally{db.close();}
 });}
 try{
  await start();await importPdf();await at(1);
  const dictionaryBefore=await page.evaluate(()=>localStorage.getItem('flutter.recall.data.v3'));
  assert(dictionaryBefore,'dictionary must exist');
  await button('다음 페이지').click();await at(2);await settle(800);
  let point={x:174,y:345};
  const sentence=page.getByText('예시: Skin effect를 검색한 뒤 용어를 눌러 영어 정의와 한국어 설명을 확인합니다.',{exact:true});
  if(await sentence.count()){
   const rect=await sentence.last().boundingBox();
   if(rect&&rect.height<60&&rect.width>200)point={x:rect.x+80,y:rect.y+rect.height/2};
  }
  fs.writeFileSync(path.join(output,'hover-point.json'),JSON.stringify(point));
  await page.mouse.move(30,300);await settle(250);
  await page.screenshot({path:path.join(output,'hover-before.png')});
  await page.mouse.move(point.x,point.y);await settle(1200);
  await page.screenshot({path:path.join(output,'hover-known.png')});
  await page.mouse.move(30,300);await settle(250);
  await page.screenshot({path:path.join(output,'hover-cleared.png')});
  await page.mouse.move(700,700);await settle(700);
  await button('사전 단어 항상 강조로 전환').click();await settle(1800);
  await page.mouse.move(30,300);await settle(250);
  await page.screenshot({path:path.join(output,'highlight-always.png')});
  await page.mouse.move(point.x-40,point.y);await page.mouse.down();
  await page.mouse.move(point.x+80,point.y,{steps:20});await page.mouse.up();
  await page.getByText('표피 효과',{exact:true}).first().waitFor();
  await button('닫기').click();
  console.log('PASS: text selection and dictionary popup also work while always-on highlights are enabled.');
  await page.mouse.move(700,700);await settle(700);
  await button('커서를 올릴 때만 강조로 전환').click();await settle(700);
  await page.mouse.move(30,300);await settle(250);
  await page.screenshot({path:path.join(output,'highlight-hover-only.png')});
  await page.mouse.move(point.x-40,point.y);await page.mouse.down();
  await page.mouse.move(point.x+80,point.y,{steps:20});await page.mouse.up();
  await page.getByText('표피 효과',{exact:true}).first().waitFor();
  await page.screenshot({path:path.join(output,'selection.png')});
  await button('닫기').click();
  console.log('PASS: PDF open/page navigation and native text selection with lookup. Hover screenshots saved for pixel verification.');
  await importPdf();await at(2);
  assert.deepEqual(await counts(),[1,1],'duplicate must not create another record');
  await start();
  await button(`문서 열기: ${filename}`).click();await at(2);await settle(800);
  console.log('PASS: IndexedDB duplicate detection, restart library and reopen without picker, reading position restored.');

  // Fail metadata put after the bytes request was queued. Transaction must roll back both.
  await page.evaluate(()=>{
   window.__recallOriginalPut=IDBObjectStore.prototype.put;
   IDBObjectStore.prototype.put=function(...args){
    if(this.name==='documents')throw new DOMException('injected quota','QuotaExceededError');
    return window.__recallOriginalPut.apply(this,args);
   };
  });
  await importPdf('1.0.2');await at(2);
  await page.evaluate(()=>{IDBObjectStore.prototype.put=window.__recallOriginalPut;delete window.__recallOriginalPut;});
  assert.deepEqual(await counts(),[1,1],'failed import must leave neither bytes nor metadata');
  console.log('PASS: injected write failure rolled back queued PDF bytes and retained current document.');

  await library();await menu(filename);await chooseManagement('rename');await settle(500);
  const title=page.getByRole('textbox',{name:'문서 제목'});await title.focus();await title.press('Control+A');await title.pressSequentially('Saved textbook');
  await button('저장').click();await button('문서 열기: Saved textbook').waitFor();await settle(500);
  await menu('Saved textbook');await chooseManagement('delete');
  await page.getByText('PDF를 삭제할까요?',{exact:true}).waitFor();
  await button('취소').click();assert.deepEqual(await counts(),[1,1]);
  await settle(500);await menu('Saved textbook');await chooseManagement('delete');
  await button('삭제').click();await settle(1000);
  assert.deepEqual(await counts(),[0,0]);
  const records=await page.evaluate(()=>Object.keys(localStorage).filter(k=>k.includes('recall.reader.progress.v1.')));
  assert.equal(records.length,0,'deleted PDF progress must be removed');
  assert.equal(await page.evaluate(()=>localStorage.getItem('flutter.recall.data.v3')),dictionaryBefore,'vocabulary storage must remain unchanged');
  await page.screenshot({path:path.join(output,'deleted.png')});
  assert.deepEqual(errors,[]);
  console.log('PASS: title rename, cancel/confirm deletion, PDF bytes and progress removed, dictionary unchanged, no JS runtime errors.');
 }catch(error){console.error(errors);await page.screenshot({path:path.join(output,'failure.png')});throw error;}
 finally{await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1});
