const {chromium}=require('playwright');
const {spawn}=require('node:child_process');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const wait=async(fn,msg)=>{for(let i=0;i<160;i++){if(await fn())return;await new Promise(r=>setTimeout(r,100));}throw Error(msg)};
async function scenario(argv,run){
 const server=spawn('java',argv,{stdio:['ignore','pipe','pipe']});let output='',errors='',browser;
 server.stdout.on('data',b=>output+=b);server.stderr.on('data',b=>errors+=b);
 try{
  await wait(()=>/http:\/\/127\.0\.0\.1:808[01]\/#/.test(output),'Server did not start '+errors);
  const url=output.match(/http:\/\/127\.0\.0\.1:808[01]\/#[A-Za-z0-9_-]+/)[0];
  browser=await chromium.launch({headless:true});const page=await browser.newPage({viewport:{width:1360,height:1000}});
  const failures=[];page.on('pageerror',e=>failures.push(e.message));
  await page.goto(url);await wait(async()=>await page.locator('.square').count()===64,'Board missing');
  await run(page);assert.deepEqual(failures,[]);
 }finally{if(browser)await browser.close();server.kill();}
}
(async()=>{
 fs.mkdirSync('test-output',{recursive:true});
 await scenario(['Chess2','--server','--bot','normal','--seed','42'],async p=>{
  assert.match(await p.locator('#you').innerText(),/normal/i);
  await p.locator('[data-x="0"][data-y="6"]').click();await p.locator('[data-x="0"][data-y="5"]').click();
  await wait(()=>p.evaluate(()=>state.ply>=2||state.round>=2),'Bot did not reply');
  await wait(()=>p.locator('#pass').isEnabled(),'Human turn not restored');
  await p.screenshot({path:'test-output/solo-bot.png',fullPage:true});
  await p.reload();await wait(()=>p.locator('#pass').isEnabled(),'Solo reconnect');
  console.log('PASS browser solo: move, bot reply, turn ownership and reconnect');
 });
 await scenario(['SoloTest','--serve-fixture'],async p=>{
  await p.locator('[data-x="0"][data-y="7"]').click();await p.locator('[data-x="0"][data-y="5"]').click();
  await wait(()=>p.evaluate(()=>state.run.phase==='reward'),'Reward phase missing');
  assert.equal(await p.locator('#runPanel button').count(),3);
  await p.screenshot({path:'test-output/roguelike-rewards.png',fullPage:true});
  await p.locator('#runPanel button').first().click();
  await wait(()=>p.evaluate(()=>state.run.phase==='route'),'Route missing');
  await p.locator('#runPanel button').first().click();
  await wait(()=>p.evaluate(()=>state.run.floor===2&&state.run.phase==='battle'),'Next encounter missing');
  await p.screenshot({path:'test-output/roguelike-battle.png',fullPage:true});
  await p.setViewportSize({width:390,height:844});
  assert.equal(await p.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2),true);
  console.log('PASS browser roguelike: battle win, three rewards, route, persistent army, next encounter and mobile');
 });
})().catch(e=>{console.error(e);process.exitCode=1});

