// Phaser 4 special-attack library. Effects are rendered in-engine, without image backgrounds.
export const DRAGON_BALL_SPECIALS = Object.freeze([
  {id:'goku',name:'Goku',skill:'Kamehameha',file:'01-goku.png',type:'beam',color:0x36cfff,accent:0xffffff,charge:650,attack:850,power:1100,width:31},
  {id:'vegeta',name:'Vegeta',skill:'Final Flash',file:'02-vegeta.png',type:'beam',color:0xffcf24,accent:0xffffe8,charge:800,attack:900,power:1350,width:48},
  {id:'gohan',name:'Gohan',skill:'Masenko',file:'03-gohan.png',type:'beam',color:0xffa62c,accent:0xffffa5,charge:480,attack:680,power:1050,width:29},
  {id:'piccolo',name:'Piccolo',skill:'Makankosappo',file:'04-piccolo.png',type:'spiral',color:0xfbc848,accent:0xd067ff,charge:850,attack:850,power:1250,width:15},
  {id:'trunks',name:'Trunks do Futuro',skill:'Corte Relâmpago',file:'05-trunks.png',type:'sword',color:0x6bcfff,accent:0xffffff,charge:260,attack:750,power:1150,hits:4},
  {id:'goten',name:'Goten',skill:'Kamehameha Juvenil',file:'06-goten.png',type:'beam',color:0x61aaff,accent:0xe7ffff,charge:420,attack:580,power:850,width:22},
  {id:'kuririn',name:'Kuririn',skill:'Kienzan',file:'07-kuririn.png',type:'disc',color:0xffbf27,accent:0xffffcf,charge:430,attack:680,power:1050},
  {id:'tenshinhan',name:'Tenshinhan',skill:'Kikoho',file:'08-tenshinhan.png',type:'triangle',color:0xffbd51,accent:0xffffce,charge:600,attack:700,power:1250,hits:3},
  {id:'yamcha',name:'Yamcha',skill:'Rogafufuken',file:'09-yamcha.png',type:'combo',color:0x50baff,accent:0xd5ffff,charge:240,attack:760,power:950,hits:5},
  {id:'mestre-kame',name:'Mestre Kame',skill:'Kamehameha Potência Máxima',file:'10-mestre-kame.png',type:'beam',color:0x4498ff,accent:0xffffff,charge:850,attack:950,power:1400,width:57},
  {id:'android-18',name:'Android 18',skill:'Power Blitz',file:'11-android-18.png',type:'barrage',color:0xff57b7,accent:0xffffec,charge:350,attack:1000,power:1200,hits:6},
  {id:'android-17',name:'Android 17',skill:'Barreira Explosiva',file:'12-android-17.png',type:'shield',color:0x4eff9c,accent:0xddffef,charge:550,attack:720,power:1100},
  {id:'videl',name:'Videl',skill:'Combo da Águia',file:'13-videl.png',type:'combo',color:0xffe09a,accent:0xffffff,charge:180,attack:620,power:800,hits:3},
  {id:'pan',name:'Pan',skill:'Explosão da Donzela',file:'14-pan.png',type:'orb',color:0x4edcff,accent:0xffdf4e,charge:430,attack:650,power:950},
  {id:'majin-boo',name:'Majin Boo',skill:'Chuva de Ki',file:'15-majin-boo.png',type:'rain',color:0xff68d2,accent:0xffe4f5,charge:480,attack:1000,power:1350,hits:8},
  {id:'uub',name:'Uub',skill:'Onda da Reencarnação',file:'16-uub.png',type:'orb',color:0xffd065,accent:0xffffff,charge:620,attack:740,power:1150},
  {id:'chaos',name:'Chaos',skill:'Telecinese',file:'17-chaos.png',type:'bind',color:0xcd72ff,accent:0x85edff,charge:550,attack:850,power:750},
  {id:'bardock',name:'Bardock',skill:'Canhão Espiritual',file:'18-bardock.png',type:'orb',color:0x62ef82,accent:0xffe777,charge:500,attack:650,power:1150},
  {id:'gogeta',name:'Gogeta',skill:'Stardust Breaker',file:'19-gogeta.png',type:'rainbow',color:0xff89ed,accent:0xffffff,charge:600,attack:850,power:1500,hits:5},
  {id:'vegetto',name:'Vegetto',skill:'Final Kamehameha',file:'20-vegetto.png',type:'spiral',color:0x27bbff,accent:0xffd459,charge:850,attack:1000,power:1600,width:49},
].map(skill=>Object.freeze(skill)));

const lerp=(a,b,t)=>a+(b-a)*t;
const clamp=n=>Math.max(0,Math.min(1,n));

export class DragonBallSpecials {
  constructor(scene,{reducedMotion=false}={}) {
    this.scene=scene; this.reducedMotion=reducedMotion; this.active=new Set();
    this._update=(_time,delta)=>{
      for(const ctx of this.active) {
        ctx.elapsed+=delta*this.scene.time.timeScale;
        for(const draw of ctx.drawers) draw();
      }
    };
    scene.events.on('update',this._update);
    scene.events.once('shutdown',()=>this.destroy());
  }

  get objectCount(){let n=0;for(const ctx of this.active)n+=ctx.root.length;return n;}

  cast(id,{caster,target,onHit=()=>{},onComplete=()=>{}}={}) {
    const skill=DRAGON_BALL_SPECIALS.find(s=>s.id===id);
    if(!skill)throw new RangeError(`Unknown Dragon Ball hero: ${id}`);
    if(!caster?.active||!target?.active)throw new TypeError('Active Phaser caster and target are required');
    if([...this.active].some(c=>c.caster===caster))return {accepted:false,reason:'busy',finished:Promise.resolve({cancelled:true,hits:0}),cancel(){}};
    const scene=this.scene, dir=target.x>=caster.x?1:-1;
    const source={x:caster.x+dir*caster.displayWidth*.18,y:caster.y-caster.displayHeight*.62};
    const destination={x:target.x,y:target.y-target.displayHeight*.50};
    let resolve;
    const finished=new Promise(r=>resolve=r);
    const original={x:caster.x,y:caster.y,scaleX:caster.scaleX,scaleY:caster.scaleY,alpha:caster.alpha,rotation:caster.rotation};
    const ctx={skill,caster,target,source,destination,dir,elapsed:0,drawers:[],timers:new Set(),tweens:new Set(),hits:0,done:false,
      root:scene.add.container(0,0).setDepth(1000)};
    ctx.at=(delay,fn)=>{
      const timer=scene.time.delayedCall(delay,()=>{ctx.timers.delete(timer);if(!ctx.done)fn();});
      ctx.timers.add(timer);return timer;
    };
    ctx.tween=(object,props)=>{
      const {onComplete:complete,...options}=props;
      const tween=scene.tweens.add({targets:object,...options,onComplete:()=>{ctx.tweens.delete(tween);if(!ctx.done)complete?.();}});
      ctx.tweens.add(tween);return tween;
    };
    ctx.finish=(cancelled=false)=>{
      if(ctx.done)return;
      ctx.done=true;
      for(const timer of ctx.timers)timer.remove(false);
      for(const tween of ctx.tweens)tween.remove();
      ctx.timers.clear();ctx.tweens.clear();ctx.drawers.length=0;
      ctx.root.destroy(true);
      if(caster.active)Object.assign(caster,original);
      if(target.active)target.clearTint?.();
      this.active.delete(ctx);
      const result={id,cancelled,hits:ctx.hits,damage:ctx.hits?skill.power:0};
      resolve(result);onComplete(result);
    };
    ctx.hit=(fraction=1)=>{
      if(ctx.done||!target.active)return;
      ctx.hits++;
      this._burst(ctx,destination.x,destination.y,skill.color,skill.type==='beam'?85:65);
      if(!this.reducedMotion)scene.cameras.main.shake(85,.002);
      target.setTintFill?.(skill.accent);
      ctx.at(65,()=>{if(target.active)target.clearTint?.();});
      onHit({id,damage:skill.power*fraction,target,hit:ctx.hits});
    };
    this.active.add(ctx);
    scene.events.emit('dragon-ball-special-start',{id,skill:skill.skill,duration:skill.charge+skill.attack+650});
    this._charge(ctx);
    ctx.at(skill.charge,()=>this._attack(ctx));
    ctx.at(skill.charge+skill.attack+650,()=>ctx.finish(false));
    return {accepted:true,finished,cancel:()=>ctx.finish(true),duration:skill.charge+skill.attack+650};
  }

  cancelAll(){for(const ctx of [...this.active])ctx.finish(true);}
  destroy(){this.cancelAll();this.scene.events.off('update',this._update);}

  _graphic(ctx,draw) {
    const g=this.scene.add.graphics();ctx.root.add(g);
    g.setBlendMode(1);
    ctx.drawers.push(()=>{g.clear();draw(g);});return g;
  }

  _charge(ctx) {
    const {source,skill,caster}=ctx;
    this._graphic(ctx,g=>{
      const p=clamp(ctx.elapsed/skill.charge), fade=1-clamp((ctx.elapsed-skill.charge)/180);
      if(!fade)return;
      const radius=8+36*p;
      g.fillStyle(skill.color,.14*fade);g.fillCircle(source.x,source.y,radius*2.3);
      g.fillStyle(skill.color,.75*fade);g.fillCircle(source.x,source.y,radius);
      g.fillStyle(skill.accent,fade);g.fillCircle(source.x,source.y,radius*.52);
      g.lineStyle(2,skill.color,.7*fade);
      const count=this.reducedMotion?5:14;
      for(let i=0;i<count;i++){
        const angle=i/count*Math.PI*2+ctx.elapsed*.002;
        const outer=radius+25+(1-p)*65;
        g.lineBetween(source.x+Math.cos(angle)*outer,source.y+Math.sin(angle)*outer,source.x+Math.cos(angle)*(radius+8),source.y+Math.sin(angle)*(radius+8));
      }
      g.lineStyle(2,skill.accent,.5*fade);g.strokeCircle(source.x,source.y,radius+12+Math.sin(ctx.elapsed*.015)*5);
    });
    ctx.tween(caster,{scaleX:caster.scaleX*1.035,scaleY:caster.scaleY*.98,duration:skill.charge*.5,yoyo:true,ease:'Sine.easeInOut'});
  }

  _attack(ctx) {
    const type=ctx.skill.type;
    if(type==='beam'||type==='spiral')this._beam(ctx);
    else if(type==='combo'||type==='sword')this._combo(ctx);
    else if(type==='disc')this._projectile(ctx,{disc:true});
    else if(type==='triangle')this._triangle(ctx);
    else if(type==='shield')this._shield(ctx);
    else if(type==='bind')this._bind(ctx);
    else if(type==='barrage'||type==='rain'||type==='rainbow')this._barrage(ctx);
    else this._projectile(ctx);
  }

  _beam(ctx) {
    const {skill,source:s,destination:d}=ctx, dx=d.x-s.x, dy=d.y-s.y, length=Math.hypot(dx,dy), angle=Math.atan2(dy,dx);
    this._graphic(ctx,g=>{
      const t=ctx.elapsed-skill.charge;
      if(t<0||t>skill.attack)return;
      const reach=clamp(t/180), fade=1-clamp((t-skill.attack+200)/200);
      const end={x:s.x+dx*reach,y:s.y+dy*reach},width=skill.width*(.9+Math.sin(t*.055)*.1)*fade;
      for(const [scale,alpha,color] of [[2.8,.10,skill.color],[1.8,.24,skill.color],[1,.92,skill.color],[.36,1,skill.accent]]){
        g.lineStyle(Math.max(1,width*scale),color,alpha*fade);g.lineBetween(s.x,s.y,end.x,end.y);
      }
      g.fillStyle(skill.accent,fade);g.fillCircle(end.x,end.y,width*.6);
      if(skill.type==='spiral'){
        g.lineStyle(3,skill.accent,.9*fade);
        for(let band=0;band<2;band++){
          g.beginPath();
          for(let i=0;i<=60;i++){
            const along=length*reach*i/60;
            const offset=Math.sin(along*.055-t*.035+band*Math.PI)*(width*.7+10);
            const x=s.x+Math.cos(angle)*along-Math.sin(angle)*offset,y=s.y+Math.sin(angle)*along+Math.cos(angle)*offset;
            if(i===0)g.moveTo(x,y);else g.lineTo(x,y);
          }g.strokePath();
        }
      }
    });
    ctx.at(180,()=>ctx.hit());
  }

  _projectile(ctx,{disc=false,color=ctx.skill.color,delay=0,fraction=1,from=ctx.source}={}) {
    const {skill,destination:d}=ctx, state={p:0,alpha:1};
    this._graphic(ctx,g=>{
      if(state.p<=0||state.alpha<=0)return;
      const x=lerp(from.x,d.x,state.p),y=lerp(from.y,d.y,state.p)-Math.sin(state.p*Math.PI)*(disc?20:55);
      const r=disc?42:28;
      g.fillStyle(color,.17*state.alpha);g.fillEllipse(x,y,r*3,disc?28:r*3);
      g.fillStyle(color,state.alpha);g.fillEllipse(x,y,r*2,disc?12:r*2);
      g.fillStyle(skill.accent,.95*state.alpha);g.fillEllipse(x,y,r*1.2,disc?4:r*1.2);
      g.lineStyle(2,skill.accent,.8*state.alpha);g.strokeEllipse(x,y,r*2.3,disc?19:r*2.3);
      if(!disc){
        g.lineStyle(2,color,.8*state.alpha);g.strokeCircle(x,y,r+7+Math.sin(ctx.elapsed*.025)*4);
      }
    });
    ctx.at(delay,()=>ctx.tween(state,{p:1,duration:Math.min(skill.attack*.65,500),ease:'Quad.easeIn',onComplete:()=>{
      ctx.hit(fraction);ctx.tween(state,{alpha:0,duration:100});
    }}));
  }

  _barrage(ctx) {
    const {skill,source:s,destination:d}=ctx, count=skill.hits;
    const rainbow=[0xff6ebc,0xffd54e,0x64ffaf,0x64d7ff,0xb488ff];
    for(let i=0;i<count;i++){
      const rain=skill.type==='rain';
      const from=rain?{x:d.x-150+i*40,y:80}:{x:s.x,y:s.y+(i-count/2)*12};
      this._projectile(ctx,{from,delay:i*55,fraction:1/count,color:skill.type==='rainbow'?rainbow[i%5]:skill.color});
    }
  }

  _combo(ctx) {
    const {caster,target,skill,dir}=ctx, start={x:caster.x,y:caster.y};
    this._burst(ctx,caster.x,caster.y-caster.displayHeight*.5,skill.color,50);
    ctx.tween(caster,{x:target.x-dir*145,y:target.y,duration:130,ease:'Quad.easeIn',onComplete:()=>{
      for(let i=0;i<skill.hits;i++)ctx.at(i*95,()=>{
        ctx.hit(1/skill.hits);
        const x=target.x+(i%2?18:-18),y=target.y-target.displayHeight*.5;
        const slash=this.scene.add.graphics();ctx.root.add(slash);slash.setBlendMode(1);
        slash.lineStyle(skill.type==='sword'?8:4,skill.accent,1);
        slash.lineBetween(x-75,y+(i%2?-65:65),x+75,y+(i%2?65:-65));
        ctx.tween(slash,{alpha:0,duration:170,onComplete:()=>slash.destroy()});
      });
      ctx.at(skill.hits*95+20,()=>ctx.tween(caster,{...start,duration:180,ease:'Quad.easeOut'}));
    }});
  }

  _triangle(ctx) {
    const {skill,destination:d}=ctx;
    for(let i=0;i<skill.hits;i++)ctx.at(i*150,()=>{
      const state={r:120,alpha:1};
      this._graphic(ctx,g=>{
        if(state.alpha<=0)return;
        g.lineStyle(6,skill.color,state.alpha);g.strokeTriangle(d.x,d.y-state.r,d.x-state.r*.9,d.y+state.r*.6,d.x+state.r*.9,d.y+state.r*.6);
        g.lineStyle(2,skill.accent,state.alpha);g.strokeRect(d.x-state.r*.6,d.y-state.r*.6,state.r*1.2,state.r*1.2);
      });
      ctx.tween(state,{r:35,alpha:0,duration:300});ctx.hit(1/skill.hits);
    });
  }

  _shield(ctx) {
    const {skill,caster}=ctx, state={r:60,alpha:1},x=caster.x,y=caster.y-caster.displayHeight*.5;
    this._graphic(ctx,g=>{
      g.fillStyle(skill.color,.07*state.alpha);g.fillCircle(x,y,state.r);
      g.lineStyle(5,skill.color,state.alpha);g.strokeCircle(x,y,state.r);
      g.lineStyle(2,skill.accent,.7*state.alpha);g.strokeCircle(x,y,state.r-12);
    });
    ctx.tween(state,{r:450,alpha:0,duration:skill.attack,ease:'Cubic.easeIn'});
    ctx.at(340,()=>this._projectile(ctx,{fraction:1}));
  }

  _bind(ctx) {
    const {skill,destination:d}=ctx,state={alpha:1};
    this._graphic(ctx,g=>{
      for(let i=0;i<3;i++){
        g.lineStyle(4,skill.color,state.alpha*.85);
        g.strokeEllipse(d.x,d.y+(i-1)*48,150+Math.sin(ctx.elapsed*.02+i)*15,35);
      }
      g.lineStyle(2,skill.accent,.7*state.alpha);g.strokeCircle(d.x,d.y,100);
    });
    ctx.at(200,()=>ctx.hit());
    ctx.at(skill.attack-200,()=>ctx.tween(state,{alpha:0,duration:200}));
  }

  _burst(ctx,x,y,color,radius) {
    const count=this.reducedMotion?5:16;
    const ring=this.scene.add.circle(x,y,12,undefined,0).setStrokeStyle(5,color,.9);
    ctx.root.add(ring);ring.setBlendMode(1);
    ctx.tween(ring,{scale:radius/12,alpha:0,duration:350,onComplete:()=>ring.destroy()});
    for(let i=0;i<count;i++){
      const a=i/count*Math.PI*2;
      const spark=this.scene.add.circle(x,y,i%3?3:5,color,1).setBlendMode(1);ctx.root.add(spark);
      ctx.tween(spark,{x:x+Math.cos(a)*radius,y:y+Math.sin(a)*radius,alpha:0,scale:0,duration:260+(i%4)*45,onComplete:()=>spark.destroy()});
    }
  }
}
