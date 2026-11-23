import { BattleModel } from './battle-core.mjs';
import { preloadCombatFX, createCombatFX, playCombatFX } from './combat-sprite-fx.mjs';
const W = 1080, H = 1920;
const SLOTS = [[.365,.535],[.365,.650],[.17,.48],[.17,.595],[.17,.71]];
const DEFAULT = ['asta','yami','yuno','noelle','magna'];
const color = hex => parseInt((hex || '#e6c77a').replace('#',''),16);
class BattleScene extends Phaser.Scene {
  constructor(){super('BattleScene');}
  preload(){
    preloadCombatFX(this);
    this.actors=new Map();this.vfxObjects=new Set();this.loadErrors=[];
    this.load.on('loaderror',file=>this.loadErrors.push(file.key));
    this.load.image('bg','/assets/backgrounds/clover_courtyard.png');
    this.load.json('roster','/phaser/roster.json');
  }
  create(){
    createCombatFX(this);
    if(this.loadErrors.length)return this._showLoadError(this.loadErrors.join(', '));
    this.roster=this.cache.json.get('roster');
    if(!Array.isArray(this.roster?.heroes))return this._showLoadError('Cadastro de heróis inválido.');
    this.heroMap=new Map(this.roster.heroes.map(h=>[h.id,h]));
    for(const h of this.roster.heroes)this.load.image(h.id,h.image);
    this.load.on('progress',p=>{
      const el=document.getElementById('load-progress');if(el)el.textContent=Math.round(p*100)+'%';
    });
    this.load.once('complete',()=>{
      if(this.loadErrors.length)return this._showLoadError('Falha nas imagens: '+this.loadErrors.join(', '));
      this.add.image(W/2,H/2,'bg').setDisplaySize(W,H).setDepth(0);
      const prefs=this._loadPrefs();
      this.playerIds=this._validateFormation(prefs.formation?.player,DEFAULT);
      this.enemyIds=this._validateFormation(prefs.formation?.enemy,this._shuffle(this.roster.heroes.map(h=>h.id)),this.playerIds);
      this._initBattle();
      this._setupHUD();
      document.getElementById('load-overlay').classList.add('hidden');
      window.dispatchEvent(new CustomEvent('battle-ready',{detail:this.roster}));
    });
    this.load.start();
  }
  _validateFormation(ids,fallback,excluded=[]){
    const source=Array.isArray(ids)?ids:[];
    const picks=[...new Set(source.filter(id=>typeof id==='string'&&this.heroMap.has(id)&&!excluded.includes(id)))].slice(0,5);
    for(const id of [...fallback,...this.heroMap.keys()]){
      if(picks.length>=5)break;
      if(this.heroMap.has(id)&&!excluded.includes(id)&&!picks.includes(id))picks.push(id);
    }
    return picks;
  }
  _initBattle(){
    this.tweens.killAll();
    for(const actor of this.actors.values()){actor.container.destroy();actor.health.destroy();}
    this.actors.clear();
    for(const fx of this.vfxObjects)fx.destroy();this.vfxObjects.clear();
    this.cameras.main.setZoom(1);this.cameraTween=null;this.finished=false;
    this.playerIds=this._validateFormation(this.playerIds,DEFAULT);
    this.enemyIds=this._validateFormation(this.enemyIds,[],this.playerIds);
    this.model=new BattleModel(this.roster.heroes,this.playerIds,this.enemyIds);
    const prefs=this._loadPrefs();
    this.model.setAutoSkill(prefs.autoSkill!==false);
    this.model.setSpeed(prefs.speed===2?2:1);
    for(const [team,units] of [['player',this.model.playerUnits],['enemy',this.model.enemyUnits]]){
      units.forEach((unit,i)=>{
        const slot=SLOTS[i],x=(team==='player'?slot[0]:1-slot[0])*W,y=slot[1]*H;
        const container=this.add.container(x,y).setDepth(Math.round(y));
        const height=unit.id==='charmy'?158:(unit.id==='yami'||unit.id==='mereoleona'?200:190);
        const shadow=this.add.ellipse(0,-2,78,17,0x142035,.24);
        const sprite=this.add.image(0,0,unit.id).setOrigin(.5,1);
        const texture=this.textures.get(unit.id);
        sprite.setScale(height/texture.source[0].height).setFlipX(team==='enemy');
        container.add([shadow,sprite]);container.setData('sprite',sprite);
        const health=this.add.graphics().setDepth(1800);
        const actor={container,health,homePos:{x,y},team,unit,height,state:'idle',sprite};
        actor.breathTween=this.tweens.add({targets:container,y:y-2.5,duration:1800+i*95,yoyo:true,repeat:-1,ease:'Sine.easeInOut'});
        this.actors.set(unit.id,actor);
      });
    }
    this.syncPlayback();this._updateQA();
  }
  syncPlayback(){
    if(!this.model)return;
    this.tweens.timeScale=this.model.paused?0:this.model.speedMultiplier;
    this.time.timeScale=this.model.paused?0:this.model.speedMultiplier;
    this._updateQA();
  }
  update(_time,delta){
    if(!this.model)return;
    this.tweens.timeScale=this.model.paused?0:this.model.speedMultiplier;
    this.time.timeScale=this.model.paused?0:this.model.speedMultiplier;
    if(!this.model.result){
      for(const ev of this.model.tick(Math.min(delta,100)/1000))this._handleEvent(ev);
      if(this.model.result&&!this.finished)this._onResult(this.model.result);
    }
    for(const actor of this.actors.values())this._drawHealth(actor);
    this.hudClock=(this.hudClock||0)+delta;
    if(this.hudClock>80){this.hudClock=0;this._updateQA();}
  }
  _drawHealth(actor){
    const g=actor.health;g.clear();
    if(actor.unit.isDead)return;
    const x=actor.homePos.x-62,y=actor.homePos.y-actor.height-20;
    g.fillStyle(0x101728,.95);g.fillRoundedRect(x-3,y-3,130,20,5);
    g.lineStyle(2,0xd7b86d,1);g.strokeRoundedRect(x-3,y-3,130,20,5);
    g.fillStyle(actor.team==='player'?0x84da9e:0xeb7872,1);g.fillRect(x,y,124*actor.unit.hp/actor.unit.maxHp,14);
    g.fillStyle(color(actor.unit.color),1);g.fillCircle(x-14,y+7,7);
  }
  _handleEvent(ev){
    const source=this.actors.get(ev.source?.id),target=this.actors.get(ev.target?.id);
    if(ev.type==='attack-start'){if(source&&target)this._animateAttack(source,target,ev.isSkill);return;}
    if(ev.type==='damage'){
      if(target){
        this._animateHit(target);
        this._number(target,ev.damage,ev.isSkill?'#ffe390':'#fff6dc');
        this._elementalVFX(target,source?.unit.color||'#e6c77a',source?.unit.element||'antimagia',ev.isSkill,source);
        if(ev.targetDead)this._animateDeath(target);
      }
    }else if(ev.type==='heal'&&target){
      this._number(target,'+'+ev.amount,'#8cf7ac');
      this._elementalVFX(target,'#8cf7ac','planta',true);
    }else if(ev.type==='guard'&&target){
      this._elementalVFX(target,source?.unit.color||'#a9bcff','espacial',true);
    }
  }
  _animateAttack(actor,target,isSkill){
    if(actor.unit.isDead||actor.state==='dead')return;
    actor.breathTween.pause();this.tweens.killTweensOf(actor.sprite);
    if(actor.actionTween)actor.actionTween.stop();
    actor.state=isSkill?'skill':'attack';
    const dx=target.homePos.x-actor.homePos.x,dy=target.homePos.y-actor.homePos.y;
    const len=Math.hypot(dx,dy)||1;
    const distance=isSkill?18:48;
    actor.container.setPosition(actor.homePos.x,actor.homePos.y);
    actor.actionTween=this.tweens.add({
      targets:actor.container,x:actor.homePos.x+dx/len*distance,y:actor.homePos.y+dy/len*distance,
      duration:isSkill?200:120,hold:35,yoyo:true,ease:'Quad.easeOut',
      onComplete:()=>{
        if(actor.unit.isDead)return;
        actor.container.setPosition(actor.homePos.x,actor.homePos.y);
        actor.state='idle';actor.breathTween.restart();
      }
    });
    if(isSkill)this._cinematicZoom();
  }
  _animateHit(actor){
    if(actor.unit.isDead)return;
    actor.sprite.setTint(0xffe4dc);
    this.tweens.addCounter({from:0,to:1,duration:120,onComplete:()=>{if(actor.sprite.active)actor.sprite.clearTint();}});
  }
  _animateDeath(actor){
    if(actor.state==='dead')return;
    actor.state='dead';actor.breathTween.stop();actor.actionTween?.stop();
    this.tweens.killTweensOf(actor.container);
    this.tweens.add({targets:actor.container,alpha:0,angle:actor.team==='player'?12:-12,y:actor.homePos.y+12,duration:650,
      onComplete:()=>actor.container.setVisible(false)});
  }
  _number(actor,value,tint){
    const label=this.add.text(actor.homePos.x,actor.homePos.y-actor.height-32,String(value),
      {fontFamily:'Georgia,serif',fontSize:'28px',color:tint,stroke:'#11162a',strokeThickness:5}).setOrigin(.5).setDepth(2500);
    this.vfxObjects.add(label);
    this.tweens.add({targets:label,y:label.y-42,alpha:0,duration:650,onComplete:()=>{this.vfxObjects.delete(label);label.destroy();}});
  }
  _elementalVFX(actor,tint,element,skill,source=null){
    const to={x:actor.homePos.x,y:actor.homePos.y-actor.height*.5};
    const from=source?{x:source.homePos.x,y:source.homePos.y-source.height*.5}:to;
    const fx=playCombatFX(this,{element,from,to,special:skill,onComplete:sprite=>this.vfxObjects.delete(sprite)});
    this.vfxObjects.add(fx);
    return;
  }
  _cinematicZoom(){
    if(this.cameraTween?.isPlaying())return;
    this.cameraTween=this.tweens.add({targets:this.cameras.main,zoom:1.025,duration:180,yoyo:true,hold:50,ease:'Sine.easeInOut',
      onComplete:()=>this.cameras.main.setZoom(1)});
  }
  _onResult(winner){
    this.finished=true;this.cameraTween?.stop();this.cameras.main.setZoom(1);
    for(const actor of this.actors.values()){
      if(actor.unit.isDead)continue;
      actor.breathTween.stop();actor.actionTween?.stop();
      actor.container.setPosition(actor.homePos.x,actor.homePos.y);
      if(actor.team===winner)this.tweens.add({targets:actor.container,y:actor.homePos.y-5,duration:380,yoyo:true,repeat:2});
    }
    window.dispatchEvent(new CustomEvent('battle-result',{detail:{winner}}));
  }
  _setupHUD(){
    window.__idleGame={
      game:this.game,scene:this,model:this.model,roster:this.roster,actors:this.actors,ready:true,
      getCount:()=>this.actors.size,getState:()=>this.model.getState(),
      restart:()=>{this._initBattle();this._savePrefs();},
      setFormation:(p,e)=>{
        this.playerIds=this._validateFormation(p,this.playerIds);
        this.enemyIds=this._validateFormation(e,[],this.playerIds);this._initBattle();this._savePrefs();
      },
      manualSkill:id=>this.model.manualSkill(id),
      setPaused:value=>{this.model.setPaused(value);this.syncPlayback();},
      setSpeed:value=>{this.model.setSpeed(value);this.syncPlayback();this._savePrefs();},
      setAuto:value=>{this.model.setAutoSkill(value);this._updateQA();this._savePrefs();}
    };
    this._updateQA();
  }
  _updateQA(){
    if(window.__idleGame){
      window.__idleGame.model=this.model;window.__idleGame.actors=this.actors;
      window.dispatchEvent(new CustomEvent('battle-state',{detail:this.model?.getState()}));
    }
  }
  _savePrefs(){
    try{localStorage.setItem('afk-phaser-prefs',JSON.stringify({formation:{player:this.playerIds,enemy:this.enemyIds},autoSkill:this.model.autoSkill,speed:this.model.speedMultiplier}));}catch{}
  }
  _loadPrefs(){try{const p=JSON.parse(localStorage.getItem('afk-phaser-prefs')||'{}');return p&&typeof p==='object'?p:{};}catch{return {};}}
  _shuffle(arr){const a=[...arr];for(let i=a.length-1;i>0;i--){const j=Math.floor(Math.random()*(i+1));[a[i],a[j]]=[a[j],a[i]];}return a;}
  _showLoadError(message){
    window.__idleGame={game:this.game,ready:false,error:message};
    const el=document.getElementById('load-overlay');el.classList.remove('hidden');el.replaceChildren();
    const text=document.createElement('p');text.textContent=message;el.append(text);
    const retry=document.createElement('button');retry.className='ctrl-btn';retry.textContent='Tentar novamente';retry.onclick=()=>location.reload();el.append(retry);
  }
}
const game=new Phaser.Game({
  type:Phaser.AUTO,width:W,height:H,parent:'phaser-canvas',backgroundColor:'#0b1222',banner:false,
  scale:{mode:Phaser.Scale.FIT,autoCenter:Phaser.Scale.CENTER_BOTH},
  render:{antialias:true,roundPixels:false},scene:[BattleScene]
});
window.__idleGame={game,ready:false};
