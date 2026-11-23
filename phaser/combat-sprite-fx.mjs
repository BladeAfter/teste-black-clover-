// Phaser 4 adapter for the same generated atlas used by Godot.
const KEY = 'clover-generated-combat';
export const ELEMENT_ROWS = Object.freeze({ antimagia:0,vento:1,agua:2,escuridao:3,fogo:4,eletricidade:5,relampago:5,raio:5,lightning:5,planta:1,espacial:3,tempo:3,runa:3,comida:2,algodao:2 });
export function preloadCombatFX(scene) {
  scene.load.spritesheet(KEY,'/assets/combat/elements-atlas.png',{frameWidth:256,frameHeight:256});
}
export function createCombatFX(scene) {
  for(let row=0;row<6;row++) for(const special of [false,true]) {
    const key=`${KEY}-${row}-${special?'special':'basic'}`;
    if(!scene.anims.exists(key)) scene.anims.create({key,frames:(special?[0,1,2,3]:[1,2,3]).map(column=>({key:KEY,frame:row*4+column})),frameRate:special?6:11,repeat:0});
  }
}
export function playCombatFX(scene,{element,from,to,special=false,onComplete}) {
  const normalized=String(element||'antimagia').normalize('NFD').replace(/[\u0300-\u036f]/g,'');
  const row=ELEMENT_ROWS[normalized]??0;
  const sprite=scene.add.sprite(special?from.x:to.x,special?from.y:to.y,KEY,row*4+(special?0:1)).setDepth(2100).setDisplaySize(special?230:100,special?230:100).setFlipX(to.x<from.x);
  sprite.play(`${KEY}-${row}-${special?'special':'basic'}`);
  if(special) scene.tweens.add({targets:sprite,x:to.x,y:to.y,duration:270,ease:'Quad.easeOut'});
  sprite.once('animationcomplete',()=>{onComplete?.(sprite);sprite.destroy();});
  return sprite;
}
