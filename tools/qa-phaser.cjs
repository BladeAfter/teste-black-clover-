const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const {spawn} = require('node:child_process');
const assert = require('node:assert/strict');
const OUT = path.resolve(__dirname, '../artifacts/phaser-expansion');
const wait = ms => new Promise(r => setTimeout(r, ms));
class CDP {
  constructor(socket) {
    this.socket = socket; this.next = 0; this.pending = new Map(); this.events = [];
    socket.addEventListener('message', ev => {
      const message = JSON.parse(ev.data);
      if (message.id) {
        const p = this.pending.get(message.id);
        if (p) {this.pending.delete(message.id); message.error ? p.reject(Error(JSON.stringify(message.error))) : p.resolve(message.result);}
      } else this.events.push(message);
    });
  }
  send(method, params = {}) {
    return new Promise((resolve, reject) => {
      const id = ++this.next;
      this.pending.set(id, {resolve,reject});
      this.socket.send(JSON.stringify({id,method,params}));
    });
  }
  async eval(expression) {
    const r = await this.send('Runtime.evaluate', {expression, awaitPromise:true, returnByValue:true});
    if (r.exceptionDetails) throw Error(r.exceptionDetails.exception?.description || r.exceptionDetails.text);
    return r.result?.value;
  }
}
(async () => {
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'afk-phaser-qa-'));
  const chrome = spawn('C:/Program Files/Google/Chrome/Application/chrome.exe', [
    '--headless=new', '--disable-background-networking', '--no-first-run',
    '--remote-debugging-port=9231', '--user-data-dir='+profile, 'about:blank'
  ], {windowsHide:true, stdio:'ignore'});
  let cdp;
  const report = {checks:[],screenshots:[],errors:[]};
  function check(ok,name,data) {assert.ok(ok, name + (data ? ': '+JSON.stringify(data) : ''));report.checks.push({name,pass:true});}
  try {
    let target;
    for(let i=0;i<100;i++) {
      try { const list=await (await fetch('http://127.0.0.1:9231/json')).json();target=list.find(x=>x.type==='page');if(target)break; } catch{}
      await wait(100);
    }
    if(!target) throw Error('Headless Chrome not ready');
    const ws = new WebSocket(target.webSocketDebuggerUrl);
    await new Promise((resolve,reject)=>{ws.addEventListener('open',resolve,{once:true});ws.addEventListener('error',reject,{once:true});});
    cdp = new CDP(ws);
    await cdp.send('Runtime.enable');
    await cdp.send('Page.enable');
    await cdp.send('Log.enable');
    await cdp.send('Emulation.setDeviceMetricsOverride',{width:540,height:960,deviceScaleFactor:1,mobile:true});
    await cdp.send('Page.navigate',{url:'http://127.0.0.1:4173/phaser/index.html'});
    let ready=false;
    for(let i=0;i<150;i++){
      ready=await cdp.eval('!!window.__idleGame?.ready');
      if(ready)break;
      const exceptions=cdp.events.filter(e=>e.method==='Runtime.exceptionThrown');
      if(exceptions.length)throw Error(JSON.stringify(exceptions.map(e=>e.params.exceptionDetails.exception?.description||e.params.exceptionDetails.text)));
      await wait(200);
    }
    check(ready,'engine ready',await cdp.eval('document.body.innerText.slice(0,600)'));
    const state=await cdp.eval('({version:Phaser.VERSION,count:__idleGame.getCount(),roster:__idleGame.roster.heroes.length,newCount:__idleGame.roster.heroes.filter(h=>h.isNew).length,api:typeof __idleGame.setFormation})');
    check(state.version==='4.2.1','installed Phaser version',state);
    check(state.count===10 && state.roster===26 && state.newCount===20,'26 heroes and 5v5',state);
    check(state.api==='function','formation API');
    await cdp.eval('window.__idleGame.model.setPaused(true)');
    await wait(200);
    const timeA=await cdp.eval('__idleGame.model.elapsed');
    const posA=await cdp.eval('[...__idleGame.actors.values()].map(a=>({x:a.container?.x,y:a.container?.y}))');
    await wait(400);
    check(await cdp.eval('__idleGame.model.elapsed')===timeA,'pause stops combat time');
    check(JSON.stringify(await cdp.eval('[...__idleGame.actors.values()].map(a=>({x:a.container?.x,y:a.container?.y}))'))===JSON.stringify(posA),'pause stops Phaser movement');
    for(const [width,height] of [[540,960],[390,844],[480,960],[1280,800]]) {
      await cdp.send('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:width<800});
      await wait(300);
      const bounds=await cdp.eval('({w:innerWidth,h:innerHeight,body:document.body.scrollWidth,canvas:document.querySelector("canvas")?.getBoundingClientRect().toJSON(),controls:[...document.querySelectorAll(".control-bar button")].map(b=>b.getBoundingClientRect().toJSON())})');
      check(bounds.body<=bounds.w+1,'no horizontal overflow '+width,bounds);
      check(bounds.controls.every(b=>b.x>=-1&&b.y>=-1&&b.right<=width+1&&b.bottom<=height+1),'controls in viewport '+width,bounds);
      const shot=await cdp.send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false});
      const filename='phaser-'+width+'x'+height+'.png';
      fs.writeFileSync(path.join(OUT,filename),Buffer.from(shot.data,'base64'));report.screenshots.push(filename);
    }
    await cdp.send('Emulation.setDeviceMetricsOverride',{width:540,height:960,deviceScaleFactor:1,mobile:true});
    const newIds=await cdp.eval('__idleGame.roster.heroes.filter(h=>h.isNew).map(h=>h.id)');
    for(let group=0;group<4;group++){
      const allies=newIds.slice(group*5,group*5+5);
      const enemies=newIds.filter(id=>!allies.includes(id)).slice(0,5);
      await cdp.eval('__idleGame.setFormation('+JSON.stringify(allies)+','+JSON.stringify(enemies)+'); __idleGame.model.setPaused(true)');
      await wait(150);
      const inspection=await cdp.eval('({ids:__idleGame.scene.playerIds,actors:[...__idleGame.actors.values()].map(a=>({id:a.unit.id,hasImage:!!a.container?.getData("sprite"),height:a.container?.getData("sprite")?.displayHeight,flip:a.container?.getData("sprite")?.flipX,team:a.team})),state:__idleGame.getState()})');
      check(JSON.stringify(inspection.ids)===JSON.stringify(allies),'all five new heroes selectable group '+group);
      check(inspection.actors.length===10 && inspection.actors.every(a=>a.hasImage && a.height>100 && a.height<240),'all new hero sprites sized correctly group '+group,inspection.actors);
      check(inspection.actors.filter(a=>a.team==='enemy').every(a=>a.flip),'enemy facing group '+group);
    }
    await cdp.eval('document.getElementById("btn-collection").click()');
    await wait(100);
    const rosterUI=await cdp.eval('({open:document.getElementById("roster-overlay").classList.contains("open"),count:document.querySelectorAll(".roster-item").length})');
    check(rosterUI.open && rosterUI.count===26,'collection opens with26',rosterUI);
    await cdp.eval('(()=>{const q=document.getElementById("roster-search");q.value="Mimosa";q.dispatchEvent(new Event("input",{bubbles:true}));})()');
    check(await cdp.eval('document.querySelectorAll(".roster-item").length')===1,'collection search');
    const rosterShot=await cdp.send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false});
    fs.writeFileSync(path.join(OUT,'collection.png'),Buffer.from(rosterShot.data,'base64'));
    await cdp.eval('document.getElementById("roster-cancel").click()');
    await cdp.eval('__idleGame.setFormation(["mimosa","mereoleona","nozel","nacht","charlotte"],["fuegoleon","william","secre","zora","rill"]);__idleGame.model.setAutoSkill(true);__idleGame.model.setSpeed(2);__idleGame.model.setPaused(false)');
    await wait(1500);
    check(await cdp.eval('__idleGame.model.elapsed')>0.5,'battle advances after resume');
    await cdp.eval('__idleGame.model.setPaused(true)');
    await wait(50);
    const shot=await cdp.send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false});
    fs.writeFileSync(path.join(OUT,'new-heroes-battle.png'),Buffer.from(shot.data,'base64'));
    const errors=cdp.events.filter(e=>e.method==='Runtime.exceptionThrown').map(e=>e.params.exceptionDetails.exception?.description||e.params.exceptionDetails.text);
    check(errors.length===0,'no browser runtime errors',errors);
    report.pass=true;
    console.log('PHASER_BROWSER_QA PASS', report.checks.length, 'checks');
  } catch(error) {
    report.pass=false;report.errors.push(error.stack);console.error(error.stack);process.exitCode=1;
    if(cdp) {
      try {const shot=await cdp.send('Page.captureScreenshot',{format:'png'});fs.writeFileSync(path.join(OUT,'failure.png'),Buffer.from(shot.data,'base64'));} catch{}
    }
  } finally {
    fs.writeFileSync(path.join(OUT,'browser-qa.json'),JSON.stringify(report,null,2));
    if(cdp) {try {await cdp.send('Browser.close');} catch{}}
    chrome.kill();
  }
})();
