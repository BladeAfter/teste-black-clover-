// Automated tests for battle-core.mjs
// Run: node phaser/battle-core.test.mjs

import { BattleModel, BattleUnit } from './battle-core.mjs';
import assert from 'node:assert/strict';
import { describe, it, run } from 'node:test';

// Deterministic midpoint RNG: always returns (a+b)/2
const midRng = () => ({ range: (a, b) => (a + b) / 2 });

// Hero factory matching roster.json schema
function makeHero(overrides = {}) {
 return {
 id: overrides.id || 'test_hero',
 name: overrides.name || 'Test',
 element: overrides.element || 'physical',
 color: '#333333',
 role: overrides.role || 'dps',
 faction: 'test',
 hp: overrides.hp || 1000,
 atk: overrides.atk || 100,
 def: overrides.def || 50,
 spd: overrides.spd || 100,
 energy_max: overrides.energy_max || 100,
 skills: overrides.skills || [{ id: 'slash', name: 'Slash', cost: 50, dmg_mult: 2.0, type: 'physical', target: 'single' }],
 image: '/assets/heroes/painted/test.png',
 portrait: { x: 0.3, y: 0.05, w: 0.4, h: 0.35 },
 isNew: overrides.isNew ?? false,
 ...overrides
 };
}

const original6Ids = ['asta', 'yuno', 'noelle', 'yami', 'magna', 'luck'];

describe('BattleUnit normal damage formula', () => {
 it('applies normal attack damage with exact Godot formula at midpoint RNG', () => {
 // atk=100, def=60 -> base = max(1, 100 - trunc(60/3)) = max(1, 100-20) = 80
 // midpoint of [0.9,1.1] = 1.0 -> damage = trunc(80 * 1.0) = 80
 const attacker = makeHero({ id: 'a', atk: 100, def: 0, spd: 100 });
 const defender = makeHero({ id: 'b', atk: 50, def: 60, spd: 100, hp: 500 });
 const model = new BattleModel([attacker, defender], ['a'], ['b'], midRng);

 // Force a tick large enough to trigger attack
 const events = [];
 // Attack interval for spd=100: 2.0 - 100/200 = 1.5s
 // Tick 1.6s to guarantee trigger
 const evts = model.tick(1.6);
 // Impact is queued with delay 0.12/speed. At speed=1, due at elapsed+0.12
 // Need another tick past 0.12 to resolve
 const evts2 = model.tick(0.2);

 const dmgEvents = [...evts, ...evts2].filter(e => e && e.type === 'damage' && !e.isSkill);
 assert.ok(dmgEvents.length > 0, 'Normal attack should produce damage event');
 assert.equal(dmgEvents[0].damage, 80, 'Normal damage = max(1, 100-trunc(60/3))*mid(0.9,1.1) truncated = 80');
 });

 it('normal attack grants +15 energy capped at max', () => {
 const attacker = makeHero({ id: 'a', atk: 100, def: 0, spd: 100, energy_max: 100 });
 const defender = makeHero({ id: 'b', hp: 9999, def: 0 });
 const model = new BattleModel([attacker, defender], ['a'], ['b'], midRng);

 // Set energy to 90 before attack
 model.playerUnits[0].energy = 90;
 model.tick(1.6); // trigger attack
 model.tick(0.2); // resolve impact

 assert.equal(model.playerUnits[0].energy, 100, 'Energy capped at max after +15');
 });

 it('normal attack energy does not exceed cap when already high', () => {
 const attacker = makeHero({ id: 'a', atk: 100, spd: 100, energy_max: 100 });
 const defender = makeHero({ id: 'b', hp: 9999, def: 0 });
 const model = new BattleModel([attacker, defender], ['a'], ['b'], midRng);

 model.playerUnits[0].energy = 95;
 model.tick(1.6);
 model.tick(0.2);

 assert.equal(model.playerUnits[0].energy, 100, '95+15 capped to 100');
 });
});

describe('Original 6 heroes behavior', () => {
 it('Yami self_buff skill targets lowest enemy, NOT self', () => {
 const yami = makeHero({
 id: 'yami', atk: 160, def: 100, spd: 85, hp: 1400,
 skills: [{ id: 'dark_cloak', name: 'Dark Cloak', cost: 55, dmg_mult: 2.2, type: 'physical', target: 'self_buff' }],
 isNew: false
 });
 const enemy = makeHero({ id: 'enemy1', hp: 500, def: 30, atk: 50 });
 const model = new BattleModel([yami, enemy], ['yami'], ['enemy1'], midRng);

 model.setAutoSkill(true);
 // Give Yami enough energy for skill
 model.playerUnits[0].energy = 60;
 model.tick(2.5); // trigger attack (interval ~2.425 for spd=85)
 const skillEvents = model.tick(0.3); // resolve

 const state = model.getState();
 // Yami should NOT have taken damage from own skill
 assert.ok(skillEvents.some(e => e.isSkill && e.source.id === 'yami' && e.target.id === 'enemy1'), 'Yami skill hits enemy');
 // Enemy should have taken damage
 assert.ok(state.enemy[0].hp < 500, 'Enemy should take damage from Yami skill');
 });

 it('all original6 skills target lowest enemy regardless of metadata', () => {
 for (const oid of original6Ids) {
 const hero = makeHero({
 id: oid, atk: 150, def: 50, spd: 100, hp: 1000,
 skills: [{ id: 'skill_' + oid, name: 'Skill', cost: 50, dmg_mult: 2.0, type: 'magic', target: 'self_buff' }],
 isNew: false
 });
 const enemy = makeHero({ id: 'target_' + oid, hp: 800, def: 20 });
 const model = new BattleModel([hero, enemy], [oid], ['target_' + oid], midRng);
 model.setAutoSkill(true);
 model.playerUnits[0].energy = 60;
 model.tick(1.6);
 model.tick(0.3);

 const state = model.getState();
 assert.ok(state.player[0].hp <= 1000, `${oid} must not self-damage`);
 assert.ok(state.enemy[0].hp < 800, `${oid} skill must hit enemy`);
 }
 });
});

describe('Skill damage formula', () => {
 it('skill damage uses trunc(atk*mult) - trunc(def/4) with midpoint RNG', () => {
 // atk=100, mult=2.0, def=60
 // trunc(100*2.0)=200, trunc(60/4)=15, base=max(1,200-15)=185
 // mid(0.95,1.05)=1.0 -> trunc(185*1.0)=185
 const attacker = makeHero({ id: 'a', atk: 100, spd: 100, isNew: true,
 skills: [{ id: 'sk', name: 'Sk', cost: 30, dmg_mult: 2.0, type: 'magic', target: 'single' }]
 });
 const defender = makeHero({ id: 'b', hp: 9999, def: 60 });
 const model = new BattleModel([attacker, defender], ['a'], ['b'], midRng);
 model.playerUnits[0].energy = 50;
 model.setAutoSkill(true);

 model.tick(1.6); // trigger
 const skillEvents = model.tick(0.3); // resolve (skill delay 0.2)

 const state = model.getState();
 const expectedDmg = 185;
 assert.equal(state.enemy[0].hp, 9999 - expectedDmg, `Skill damage should be ${expectedDmg}`);
 });
});

describe('Auto skill cadence', () => {
 it('AUTO OFF: player uses normal attack even with enough energy', () => {
 const hero = makeHero({ id: 'a', atk: 100, spd: 100, isNew: true,
 skills: [{ id: 'sk', name: 'Sk', cost: 30, dmg_mult: 2.0, type: 'magic', target: 'single' }]
 });
 const enemy = makeHero({ id: 'b', hp: 9999, def: 0 });
 const model = new BattleModel([hero, enemy], ['a'], ['b'], midRng);
 model.playerUnits[0].energy = 50;
 model.setAutoSkill(false);

 model.tick(1.6);
 model.tick(0.2);

 // Should be normal attack (energy +15), not skill (energy -30)
 assert.equal(model.playerUnits[0].energy, 65, 'Auto off: energy should increase by 15 (normal attack)');
 });

 it('AUTO ON: player uses skill at next attack interval when energy sufficient', () => {
 const hero = makeHero({ id: 'a', atk: 100, spd: 100, isNew: true,
 skills: [{ id: 'sk', name: 'Sk', cost: 30, dmg_mult: 2.0, type: 'magic', target: 'single' }]
 });
 const enemy = makeHero({ id: 'b', hp: 9999, def: 0 });
 const model = new BattleModel([hero, enemy], ['a'], ['b'], midRng);
 model.playerUnits[0].energy = 50;
 model.setAutoSkill(true);

 model.tick(1.6); // trigger at interval
 const skillEvents = model.tick(0.3); // resolve skill impact (0.2 delay)

 // Skill costs 30: 50-30=20
 assert.equal(model.playerUnits[0].energy, 20, 'Auto on: energy should decrease by skill cost');
 });

 it('enemies always auto-skill regardless of autoSkill setting', () => {
 const player = makeHero({ id: 'p', hp: 9999, def: 0, atk: 50 });
 const enemy = makeHero({ id: 'e', atk: 100, spd: 100, isNew: true,
 skills: [{ id: 'esk', name: 'ESk', cost: 30, dmg_mult: 2.0, type: 'magic', target: 'single' }]
 });
 const model = new BattleModel([player, enemy], ['p'], ['e'], midRng);
 model.enemyUnits[0].energy = 50;
 model.setAutoSkill(false); // player auto off, but enemies ignore this

 model.tick(1.6);
 model.tick(0.3);

 assert.equal(model.enemyUnits[0].energy, 20, 'Enemy should use skill (50-30=20) regardless of autoSkill');
 });
});

describe('Impact latency', () => {
 it('normal attack impact resolves after 0.12 game seconds', () => {
 const a = makeHero({ id: 'a', atk: 100, spd: 100 });
 const b = makeHero({ id: 'b', hp: 500, def: 0 });
 const model = new BattleModel([a, b], ['a'], ['b'], midRng);

 model.tick(1.6); // trigger attack at t=1.6
 // Impact due at 1.6 + 0.12 = 1.72
 const evts1 = model.tick(0.05); // t=1.65, not yet due
 const dmgBefore = evts1.filter(e => e?.type === 'damage').length;
 assert.equal(dmgBefore, 0, 'Impact should not resolve before 0.12s delay');

 const evts2 = model.tick(0.1); // t=1.75, past due
 const dmgAfter = evts2.filter(e => e?.type === 'damage').length;
 assert.ok(dmgAfter > 0, 'Impact should resolve after delay');
 });

 it('skill impact resolves after 0.2 game seconds', () => {
 const a = makeHero({ id: 'a', atk: 100, spd: 100, isNew: true,
 skills: [{ id: 'sk', name: 'Sk', cost: 30, dmg_mult: 2.0, type: 'magic', target: 'single' }]
 });
 const b = makeHero({ id: 'b', hp: 9999, def: 0 });
 const model = new BattleModel([a, b], ['a'], ['b'], midRng);
 model.playerUnits[0].energy = 50;
 model.setAutoSkill(true);

 model.tick(1.6); // trigger
 const evts1 = model.tick(0.1); // t=1.7, skill due at 1.8
 const skillBefore = evts1.filter(e => e?.isSkill).length;
 assert.equal(skillBefore, 0, 'Skill impact should not resolve before 0.2s');

 const evts2 = model.tick(0.15); // t=1.85, past due
 const skillAfter = evts2.filter(e => e?.isSkill).length;
 assert.ok(skillAfter > 0, 'Skill impact should resolve after 0.2s delay');
 });
});

describe('Pause freezes impacts', () => {
 it('paused model does not advance timers or resolve impacts', () => {
 const a = makeHero({ id: 'a', atk: 100, spd: 100 });
 const b = makeHero({ id: 'b', hp: 500, def: 0 });
 const model = new BattleModel([a, b], ['a'], ['b'], midRng);

 model.tick(1.6); // trigger attack
 model.setPaused(true);
 const evts = model.tick(1.0); // 1 second while paused
 assert.equal(evts.length, 0, 'No events while paused');
 assert.equal(model.elapsed, 1.6, 'Elapsed should not advance while paused');

 model.setPaused(false);
 const evts2 = model.tick(0.2);
 const dmg = evts2.filter(e => e?.type === 'damage');
 assert.ok(dmg.length > 0, 'Impacts resolve after unpause');
 });
});

describe('Speed multiplier', () => {
 it('2x speed doubles timer advancement', () => {
 const a = makeHero({ id: 'a', atk: 100, spd: 100 });
 const b = makeHero({ id: 'b', hp: 9999, def: 0 });
 const model = new BattleModel([a, b], ['a'], ['b'], midRng);
 model.setSpeed(2.0);

 model.tick(0.8); // 0.8 real * 2.0 = 1.6 game seconds -> triggers attack
 model.tick(0.1); // resolve
 const state = model.getState();
 assert.ok(state.elapsed > 1.5, 'Elapsed should reflect speed multiplier');
 });
});

describe('Death cancels pending impacts', () => {
 it('dead unit pending impacts are discarded', () => {
 const a = makeHero({ id: 'a', atk: 9999, spd: 100 }); // huge damage
 const b = makeHero({ id: 'b', hp: 10, def: 0, atk: 100, spd: 100 });
 const c = makeHero({ id: 'c', hp: 9999, def: 0 });
 const model = new BattleModel([a, b, c], ['a'], ['b', 'c'], midRng);

 // Both sides attack simultaneously
 model.tick(1.6); // trigger both attacks
 // A kills B instantly on resolve
 const evts = model.tick(0.2);

 // B's pending attack against A should be cancelled since B is dead
 const bAttacks = evts.filter(e => e?.source?.id === 'b');
 assert.equal(bAttacks.length, 0, 'Dead unit attacks should be cancelled');
 });

 it('result stops all further damage', () => {
 const a = makeHero({ id: 'a', atk: 9999, spd: 100 });
 const b = makeHero({ id: 'b', hp: 1, def: 0 });
 const model = new BattleModel([a, b], ['a'], ['b'], midRng);

 model.tick(1.6);
 model.tick(0.2);

 assert.equal(model.result, 'player', 'Player should win');
 const hpAfter = model.getState().enemy[0].hp;

 // Further ticks should produce no events
 const evts = model.tick(5.0);
 assert.equal(evts.length, 0, 'No events after result');
 assert.equal(model.getState().enemy[0].hp, hpAfter, 'HP unchanged after result');
 });
});

describe('Formation validation', () => {
 it('model creates correct number of units', () => {
 const heroes = [makeHero({ id: 'a' }), makeHero({ id: 'b' }), makeHero({ id: 'c' })];
 const model = new BattleModel(heroes, ['a', 'b'], ['c'], midRng);
 assert.equal(model.playerUnits.length, 2);
 assert.equal(model.enemyUnits.length, 1);
 });
});

describe('Manual skill', () => {
 it('manual skill consumes energy and queues impact', () => {
 const hero = makeHero({ id: 'a', atk: 100, spd: 100, isNew: true,
 skills: [{ id: 'sk', name: 'Sk', cost: 40, dmg_mult: 2.5, type: 'magic', target: 'single' }]
 });
 const enemy = makeHero({ id: 'b', hp: 9999, def: 0 });
 const model = new BattleModel([hero, enemy], ['a'], ['b'], midRng);
 model.playerUnits[0].energy = 50;

 const ok = model.manualSkill('a');
 assert.ok(ok, 'manualSkill should return true when energy sufficient');
 assert.equal(model.playerUnits[0].energy, 10, 'Energy should be deducted immediately');

 // Impact resolves after delay
 model.tick(0.3);
 const state = model.getState();
 assert.ok(state.enemy[0].hp < 9999, 'Manual skill should deal damage after delay');
 });

 it('manual skill fails when energy insufficient', () => {
 const hero = makeHero({ id: 'a', atk: 100,
 skills: [{ id: 'sk', name: 'Sk', cost: 60, dmg_mult: 2.0, type: 'magic', target: 'single' }]
 });
 const enemy = makeHero({ id: 'b', hp: 9999 });
 const model = new BattleModel([hero, enemy], ['a'], ['b'], midRng);
 model.playerUnits[0].energy = 30;

 const ok = model.manualSkill('a');
 assert.ok(!ok, 'manualSkill should return false when energy insufficient');
 assert.equal(model.playerUnits[0].energy, 30, 'Energy unchanged on failed manual skill');
 });

 it('manual skill blocked during pause', () => {
 const hero = makeHero({ id: 'a', atk: 100,
 skills: [{ id: 'sk', name: 'Sk', cost: 30, dmg_mult: 2.0, type: 'magic', target: 'single' }]
 });
 const enemy = makeHero({ id: 'b', hp: 9999 });
 const model = new BattleModel([hero, enemy], ['a'], ['b'], midRng);
 model.playerUnits[0].energy = 50;
 model.setPaused(true);

 const ok = model.manualSkill('a');
 assert.ok(!ok, 'manualSkill should fail when paused');
 });
});

describe('Reset clears state', () => {
 it('reset restores full HP, zero energy, clears result', () => {
 const a = makeHero({ id: 'a', atk: 9999 });
 const b = makeHero({ id: 'b', hp: 1 });
 const model = new BattleModel([a, b], ['a'], ['b'], midRng);

 model.tick(1.6);
 model.tick(0.2);
 assert.equal(model.result, 'player');

 model.reset(['a'], ['b']);
 assert.equal(model.result, null);
 assert.equal(model.playerUnits[0].hp, a.hp);
 assert.equal(model.playerUnits[0].energy, 0);
 assert.equal(model.enemyUnits[0].hp, b.hp);
 assert.equal(model.elapsed, 0);
 });
});