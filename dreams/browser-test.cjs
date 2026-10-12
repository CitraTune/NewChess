const {chromium}=require('playwright');
const {spawn}=require('node:child_process');
const fs=require('node:fs');
const assert=require('node:assert/strict');
(async()=>{
 fs.mkdirSync('test-output',{recursive:true});
 const server=spawn('java',['Chess2','--server','--seed','42'],{stdio:['ignore','pipe','pipe']});
 let output='',errors='',browser;
 server.stdout.on('data',b=>output+=b);server.stderr.on('data',b=>errors+=b);
 const wait=async(fn,message)=>{for(let i=0;i<100;i++){if(await fn())return;await new Promise(r=>setTimeout(r,100));}throw Error(message)};
 try{
  await wait(()=>output.includes('Onyx invite:'),'Server failed: '+errors);
  const urls=output.match(/http:\/\/127\.0\.0\.1:8080\/#[A-Za-z0-9_-]+/g);
  assert.equal(urls.length,2);
  browser=await chromium.launch({headless:true});
  const white=await browser.newPage({viewport:{width:1440,height:1100}});
  const black=await browser.newPage({viewport:{width:1200,height:950}});
  const pageErrors=[];for(const p of [white,black])p.on('pageerror',e=>pageErrors.push(e.message));
  await Promise.all([white.goto(urls[0]),black.goto(urls[1])]);
  await wait(async()=>await white.locator('.square').count()===64&&await black.locator('.square').count()===64,'Board missing');
  assert.equal(await white.locator('#pass').isEnabled(),true);assert.equal(await black.locator('#pass').isEnabled(),false);
  await white.screenshot({path:'test-output/browser-opening.png',fullPage:true});
  await white.locator('[data-x="1"][data-y="6"]').click();await white.locator('[data-x="1"][data-y="5"]').click();
  await wait(()=>black.locator('#pass').isEnabled(),'White move did not synchronize');
  assert.match(await white.locator('#shopHint').innerText(),/turn|Market/);
  await black.locator('[data-x="1"][data-y="1"]').click();await black.locator('[data-x="1"][data-y="2"]').click();
  await wait(()=>white.locator('#pass').isEnabled(),'Black move did not synchronize');
  await wait(async()=>await white.locator('#hand .card').count()===3,'Cards not unlocked');
  assert.equal(await black.locator('#hand .card').count(),2);
  await white.locator('#shopBtn').click();await white.locator('#shop[open]').waitFor();
  await white.screenshot({path:'test-output/browser-bazaar.png',fullPage:true});
  await white.locator('#shopContent .offer button:not([disabled])').first().click();
  await wait(()=>black.locator('#pass').isEnabled(),'Purchase did not end turn');
  await wait(async()=>await white.locator('#items .relic').count()===1,'Purchased relic missing');
  assert.equal(await black.locator('#items .relic').count(),0);
  await black.locator('#pass').click();await wait(()=>white.locator('#pass').isEnabled(),'Pass failed');
  const item=await white.evaluate(()=>state.items[0]);
  await white.locator('#items .relic').first().click();
  if(item.target!=='none'){
   const targets={ally:[0,6],queen:[3,7],enemy:[0,1],tile:[4,4],empty:[4,4]};
   const [x,y]=targets[item.target];
   await white.locator('[data-x="'+x+'"][data-y="'+y+'"]').click();
  }
  await wait(async()=>await white.locator('#items .relic').count()===0,'Relic activation failed');
  await white.reload();await wait(async()=>await white.locator('.square').count()===64,'Reconnect failed');
  assert.match(await white.locator('#you').innerText(),/Ivory/);
  // Drive legal passes through the public authenticated API; inspect the expanded UI afterward.
  for(let i=0;i<40;i++){
   const r=await white.request.get('http://127.0.0.1:8080/state',{headers:{'X-Chess-Token':urls[0].split('#')[1]}});
   const s=await r.json();if(s.round>=20)break;
   const token=urls[s.turn].split('#')[1];
   const result=await white.request.post('http://127.0.0.1:8080/action',{headers:{'X-Chess-Token':token},form:{op:'pass',revision:String(s.revision)}});
   assert.equal(result.status(),200);
  }
  await wait(async()=>await white.locator('.square').count()===400,'Expansion not rendered');
  await white.screenshot({path:'test-output/browser-expanded.png',fullPage:true});
  const mobile=await browser.newPage({viewport:{width:390,height:844}});
  mobile.on('pageerror',e=>pageErrors.push(e.message));await mobile.goto(urls[0]);
  await wait(async()=>await mobile.locator('.square').count()===400,'Mobile board missing');
  await mobile.screenshot({path:'test-output/browser-mobile.png',fullPage:true});
  assert.equal(await mobile.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2),true,'Mobile page overflow');
  assert.deepEqual(pageErrors,[]);
  console.log('PASS browser: two player sessions, moves, cards, shop, relic, reconnect, expansion and mobile layout');
 }finally{if(browser)await browser.close();server.kill();}
})().catch(e=>{console.error(e);process.exitCode=1});
