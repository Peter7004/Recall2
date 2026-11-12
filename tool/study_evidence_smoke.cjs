// Isolated browser profile; uses real bundled corpus and never edits user data.
const {chromium}=require(process.env.RECALL_PLAYWRIGHT_MODULE||'playwright');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
(async()=>{
 const browser=await chromium.launch({channel:'msedge',headless:true});
 const out=path.resolve(__dirname,'../build/study-evidence');fs.mkdirSync(out,{recursive:true});
 const p=await browser.newPage({viewport:{width:1100,height:1000}});p.setDefaultTimeout(30000);
 const errors=[];p.on('pageerror',e=>errors.push(String(e)));p.on('console',m=>{if(/overflowed by|Another exception was thrown/.test(m.text()))errors.push(m.text());});
 const btn=n=>p.getByRole('button',{name:n,exact:true});const pause=()=>p.waitForTimeout(700);
 const snapshot=()=>p.locator('body').ariaSnapshot();
 const storage=()=>p.evaluate(()=>Object.fromEntries(Object.entries(localStorage).filter(([key])=>key.startsWith('flutter.recall.'))));
 const select=async name=>{const c=p.getByRole('checkbox',{name,exact:true});await c.scrollIntoViewIfNeeded();await c.click();await pause();};
 const capture=async name=>{const panel=p.getByRole('group',{name:/^학습 우선순위 판단/});const r=await panel.boundingBox();await p.mouse.move(p.viewportSize().width/2,500);await p.mouse.wheel(0,r.y-70);await pause();await p.screenshot({path:path.join(out,name+'.png')});};
 try{
  await p.goto(process.env.RECALL_READER_TEST_URL||'http://127.0.0.1:5220/');await p.waitForFunction(()=>document.querySelector('flt-semantics-placeholder')||document.querySelector('flt-semantics'));
  if(await p.locator('flt-semantics-placeholder').count())await p.locator('flt-semantics-placeholder').dispatchEvent('click');
  await btn('사전').click();await p.getByRole('textbox',{name:'영어·한국어 검색'}).click();await pause();await p.keyboard.type('Voltage');await pause();await p.getByRole('button',{name:/^Voltage /}).first().click();await pause();
  const before=await storage();
  let tree=await snapshot();assert.match(tree,/AI·등록 우선순위 높음, 교재·강의자료 등장 문서 비율 95.5%/);assert.match(tree,/등장 문서 21 \/ 22개 \(DF\)/);assert.match(tree,/총 출현 7294회/);assert.match(tree,/옴의 법칙과 회로·전력 계산/);
  await capture('desktop-textbook');
  await select('논문 초록 기준');tree=await snapshot();assert.match(tree,/AI·등록 우선순위 높음, 논문 초록 등장 문서 비율 16.7%/);assert.match(tree,/등장 문서 107 \/ 639개 \(DF\)/);assert.match(tree,/총 출현 261회/);await capture('desktop-abstract');
  for(const width of [390,320]){await p.setViewportSize({width,height:1000});await pause();await select('교재 기준');await capture('mobile-'+width+'-textbook');await select('논문 초록 기준');assert.match(await snapshot(),/등장 문서 107 \/ 639개/);await capture('mobile-'+width+'-abstract');}
  await btn('판단 기준').click();await p.getByText('학습 판단 기준',{exact:true}).waitFor();assert.match(await snapshot(),/검증된 중요도 점수는 아닙니다/);await btn('집계 기준').click();await p.getByText('빈도 집계 기준',{exact:true}).waitFor();assert.match(await snapshot(),/논문 전체 본문 빈도가 아닙니다/);await btn('닫기').click();await btn('닫기').click();
  assert.deepEqual(await storage(),before,'evidence viewing/source toggles must not change learning preferences or data');assert.deepEqual(errors,[]);
  fs.writeFileSync(path.join(out,'result.json'),JSON.stringify({dictionary:'PASS',sourceToggle:'PASS',desktopAndMobile:[1100,390,320],priorityReason:'PASS',criteria:'PASS',storedData:'unchanged',androidDevice:'NOT TESTED'}));
  console.log('PASS dictionary priority/coverage map, real 22-PDF/639-abstract values, source toggle, 320/390/1100 layouts, criteria and unchanged stored data');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
