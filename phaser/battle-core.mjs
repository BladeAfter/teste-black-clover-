// Pure combat model - no DOM, no Phaser, independently testable
// Mirrors scripts/battle/battle_unit.gd formulas exactly
// Original 6 heroes: ALL skills target lowest enemy (Godot runtime behavior)
// New 20 heroes: may use heal/buff/aoe as designed

const ORIGINAL_IDS = new Set(['asta', 'yuno', 'noelle', 'yami', 'magna', 'luck']);

export class BattleUnit {
  constructor(heroData, team, positionIndex, rng) {
    this.id = heroData.id;
    this.name = heroData.name;
    this.team = team; // 'player' | 'enemy'
    this.positionIndex = positionIndex;
    this.hp = heroData.hp;
    this.maxHp = heroData.hp;
    this.atk = heroData.atk;
    this.def = heroData.def;
    this.spd = heroData.spd;
    this.energyMax = heroData.energy_max || 100;
    this.energy = 0;
    this.skills = heroData.skills || [];
    this.role = heroData.role;
    this.element = heroData.element;
    this.color = heroData.color;
    this.image = heroData.image;
    this.isNew = heroData.isNew === true;
    this.isDead = false;
    this.attackTimer = 0;
    const rawInterval = 2.0 - (this.spd / 200.0);
    this.attackInterval = Math.min(3.0, Math.max(0.6, rawInterval));
    this.rng = rng;
    this.pendingAttackId = null;
    this.guard = 0;
  }

  tick(deltaSeconds, speedMultiplier, enemies, allies, autoSkillEnabled, gameTime, scheduleImpact) {
    if (this.isDead || this.pendingAttackId) return;
    this.attackTimer += deltaSeconds * speedMultiplier;
    if (this.attackTimer >= this.attackInterval) {
      this.attackTimer -= this.attackInterval;
      this._resolveAttack(enemies, allies, autoSkillEnabled, gameTime, scheduleImpact);
    }
  }

  _resolveAttack(enemies, allies, autoSkillEnabled, gameTime, scheduleImpact) {
    const skill = this.skills[0];
    // Enemies always auto-skill; players only when autoSkillEnabled
    const wantsSkill = this.team === 'enemy' ? true : autoSkillEnabled;
    const canSkill = wantsSkill && skill && this.energy >= skill.cost;
    const isSkill = canSkill;

    // Target selection
    let target;
    if (!ORIGINAL_IDS.has(this.id) && isSkill && this.isNew) {
      // New heroes: respect skill target metadata
      target = this._pickTargetNew(enemies, allies, skill);
    } else {
      // Original 6 OR new heroes without special targeting: always lowest enemy
      target = this._pickLowestEnemy(enemies);
    }
    if (!target && !(isSkill && this.isNew && skill?.type === 'heal')) return;

    // For heal skills on new heroes, target may be ally
    if (isSkill && this.isNew && skill?.type === 'heal') {
      target = this._pickTargetNew(enemies, allies, skill);
      if (!target) return;
    }

    const attackId = `${this.id}_${gameTime}_${Math.random()}`;
    this.pendingAttackId = attackId;

    if (isSkill) {
      this.energy -= skill.cost;
      const impactDelay = 0.2;
      scheduleImpact({
        attackId,
        source: this,
        target,
        isSkill: true,
        skillId: skill.id,
        skillType: skill.type,
        skillTarget: skill.target,
        dmgMult: skill.dmg_mult,
        dueAt: gameTime + impactDelay,
        enemies,
        allies
      });
    } else {
      const impactDelay = 0.12;
      scheduleImpact({
        attackId,
        source: this,
        target,
        isSkill: false,
        dueAt: gameTime + impactDelay,
        enemies,
        allies
      });
    }
  }

  _pickLowestEnemy(enemies) {
    const valid = enemies.filter(e => !e.isDead);
    if (valid.length === 0) return null;
    return valid.reduce((a, b) => a.hp < b.hp ? a : b);
  }

  _pickTargetNew(enemies, allies, skill) {
    if (skill.type === 'heal') {
      if (skill.target === 'all_allies') return this; // caster ref
      const living = allies.filter(a => !a.isDead);
      if (living.length === 0) return null;
      return living.reduce((a, b) => a.hp < b.hp ? a : b);
    }
    if (skill.type === 'buff' && skill.target === 'self_buff') return this;
    if (skill.type === 'buff' && skill.target === 'all_allies') return this;
    // aoe or single: lowest enemy
    return this._pickLowestEnemy(enemies);
  }

  applyDamage(amount) {
    if (this.isDead) return 0;
    const blocked = Math.min(this.guard, amount);
    this.guard -= blocked;
    amount -= blocked;
    const actual = Math.min(this.hp, amount);
    this.hp -= actual;
    if (this.hp <= 0) {
      this.hp = 0;
      this.isDead = true;
    }
    return actual;
  }

  forceSkill(enemies, allies, gameTime, scheduleImpact) {
    if (this.isDead || this.pendingAttackId) return false;
    const skill = this.skills[0];
    if (!skill || this.energy < skill.cost) return false;

    let target;
    if (!ORIGINAL_IDS.has(this.id) && this.isNew) {
      target = this._pickTargetNew(enemies, allies, skill);
    } else {
      target = this._pickLowestEnemy(enemies);
    }
    if (!target && skill.type !== 'heal') return false;
    if (skill.type === 'heal') {
      target = this._pickTargetNew(enemies, allies, skill);
      if (!target) return false;
    }

    this.energy -= skill.cost;
    const attackId = `manual_${this.id}_${gameTime}`;
    this.pendingAttackId = attackId;
    scheduleImpact({
      attackId,
      source: this,
      target,
      isSkill: true,
      skillId: skill.id,
      skillType: skill.type,
      skillTarget: skill.target,
      dmgMult: skill.dmg_mult,
      dueAt: gameTime + 0.2,
      enemies,
      allies,
      manual: true
    });
    return true;
  }

  cancelPending() {
    this.pendingAttackId = null;
  }
}

export class BattleModel {
  constructor(rosterHeroes, playerIds, enemyIds, rngFactory) {
    this.rngFactory = rngFactory || (() => ({ range: (a, b) => a + Math.random() * (b - a) }));
    this.rng = this.rngFactory();
    this.heroMap = new Map(rosterHeroes.map(h => [h.id, h]));
    this.playerUnits = playerIds.map((id, i) => new BattleUnit(this.heroMap.get(id), 'player', i, this.rng));
    this.enemyUnits = enemyIds.map((id, i) => new BattleUnit(this.heroMap.get(id), 'enemy', i, this.rng));
    this.speedMultiplier = 1.0;
    this.paused = false;
    this.autoSkill = false;
    this.elapsed = 0;
    this.result = null;
    this.pendingImpacts = [];
    this.eventLog = [];
  }

  setSpeed(multiplier) {
    this.speedMultiplier = multiplier === 2 ? 2 : 1;
  }

  setPaused(v) {
    this.paused = v;
  }

  setAutoSkill(v) {
    this.autoSkill = v;
  }

  manualSkill(unitId) {
    if (this.result || this.paused) return false;
    const unit = this.playerUnits.find(u => u.id === unitId && !u.isDead);
    if (!unit) return false;
    return unit.forceSkill(this.enemyUnits, this.playerUnits, this.elapsed, (imp) => this._scheduleImpact(imp));
  }

  _scheduleImpact(impact) {
    this.pendingImpacts.push(impact);
    this.eventLog.push({ type: 'attack-start', source: impact.source, target: impact.target, isSkill: impact.isSkill, attackId: impact.attackId });
  }

  tick(deltaSeconds) {
    if (this.paused || this.result) return [];

    const dt = deltaSeconds * this.speedMultiplier;
    this.elapsed += dt;

    // Schedule new attacks
    const allPlayer = this.playerUnits;
    const allEnemy = this.enemyUnits;
    for (const unit of [...allPlayer, ...allEnemy]) {
      unit.tick(deltaSeconds, this.speedMultiplier,
        unit.team === 'player' ? allEnemy : allPlayer,
        unit.team === 'player' ? allPlayer : allEnemy,
        this.autoSkill,
        this.elapsed,
        (imp) => this._scheduleImpact(imp)
      );
    }

    // Resolve due impacts
    const resolved = this.eventLog.splice(0);
    const stillPending = [];
    for (const imp of this.pendingImpacts) {
      if (imp.dueAt <= this.elapsed) {
        const r = this._resolveImpact(imp);
        if (r) {
          if (Array.isArray(r)) resolved.push(...r);
          else resolved.push(r);
        }
        this._checkWinCondition();
        if (this.result) break;
      } else {
        stillPending.push(imp);
      }
    }
    this.pendingImpacts = this.result ? [] : stillPending;

    this._checkWinCondition();
    return resolved;
  }

  _resolveImpact(imp) {
    imp.source.pendingAttackId = null;
    // Cancel if source dead or result already decided
    if (imp.source.isDead || this.result) return null;

    if (!imp.isSkill) {
      // Normal attack damage
      if (imp.target.isDead) return null;
      const baseDmg = imp.source.atk;
      const defense = imp.target.def;
      let damage = Math.max(1, baseDmg - Math.trunc(defense / 3));
      damage = Math.trunc(damage * this.rng.range(0.9, 1.1));
      const actual = imp.target.applyDamage(damage);
      imp.source.energy = Math.min(imp.source.energy + 15, imp.source.energyMax);
      return { type: 'damage', source: imp.source, target: imp.target, damage: actual, isSkill: false, targetDead: imp.target.isDead, attackId: imp.attackId };
    }

    // Skill
    const skill = imp;
    if (skill.skillType === 'buff' && skill.source.isNew) {
      const targets = skill.skillTarget === 'all_allies' ? skill.allies : [skill.source];
      return targets.filter(unit => !unit.isDead).map(unit => {
        unit.guard = Math.max(unit.guard, Math.trunc(skill.source.atk * 1.5));
        return { type: 'guard', source: skill.source, target: unit, amount: unit.guard, isSkill: true };
      });
    }
    if (skill.skillType === 'heal') {
      const healAmount = Math.trunc(skill.source.atk * (skill.dmgMult || 1.5));
      if (skill.skillTarget === 'all_allies') {
        const results = [];
        for (const ally of skill.allies) {
          if (!ally.isDead) {
            const actual = Math.min(ally.maxHp - ally.hp, healAmount);
            ally.hp += actual;
            results.push({ type: 'heal', source: skill.source, target: ally, amount: actual, isSkill: true, skillId: skill.skillId, attackId: skill.attackId });
          }
        }
        return results;
      }
      if (skill.target.isDead) return null;
      const actual = Math.min(skill.target.maxHp - skill.target.hp, healAmount);
      skill.target.hp += actual;
      return { type: 'heal', source: skill.source, target: skill.target, amount: actual, isSkill: true, skillId: skill.skillId, attackId: skill.attackId };
    }

    if (skill.skillTarget === 'aoe' && skill.source.isNew && !ORIGINAL_IDS.has(skill.source.id)) {
      const results = [];
      const valid = skill.enemies.filter(e => !e.isDead);
      for (const t of valid) {
        let damage = Math.max(1, Math.trunc(skill.source.atk * skill.dmgMult) - Math.trunc(t.def / 4));
        damage = Math.trunc(damage * this.rng.range(0.95, 1.05));
        const actual = t.applyDamage(damage);
        results.push({ type: 'damage', source: skill.source, target: t, damage: actual, isSkill: true, skillId: skill.skillId, targetDead: t.isDead, attackId: skill.attackId });
      }
      return results;
    }

    // Single target skill damage (original6 + new single-target)
    if (skill.target.isDead) return null;
    let damage = Math.max(1, Math.trunc(skill.source.atk * skill.dmgMult) - Math.trunc(skill.target.def / 4));
    damage = Math.trunc(damage * this.rng.range(0.95, 1.05));
    const actual = skill.target.applyDamage(damage);
    return { type: 'damage', source: skill.source, target: skill.target, damage: actual, isSkill: true, skillId: skill.skillId, targetDead: skill.target.isDead, attackId: skill.attackId };
  }

  _checkWinCondition() {
    if (this.result) return;
    const playerAlive = this.playerUnits.some(u => !u.isDead);
    const enemyAlive = this.enemyUnits.some(u => !u.isDead);
    if (!playerAlive) {
      this.result = 'enemy';
      this._cancelAllPending();
    } else if (!enemyAlive) {
      this.result = 'player';
      this._cancelAllPending();
    }
  }

  _cancelAllPending() {
    this.pendingImpacts = [];
    for (const u of [...this.playerUnits, ...this.enemyUnits]) {
      u.cancelPending();
    }
  }

  getState() {
    return {
      elapsed: this.elapsed,
      speed: this.speedMultiplier,
      paused: this.paused,
      autoSkill: this.autoSkill,
      result: this.result,
      player: this.playerUnits.map(u => ({ id: u.id, hp: u.hp, maxHp: u.maxHp, energy: u.energy, energyMax: u.energyMax, isDead: u.isDead })),
      enemy: this.enemyUnits.map(u => ({ id: u.id, hp: u.hp, maxHp: u.maxHp, energy: u.energy, energyMax: u.energyMax, isDead: u.isDead }))
    };
  }

  reset(playerIds, enemyIds) {
    this.rng = this.rngFactory();
    this.playerUnits = playerIds.map((id, i) => new BattleUnit(this.heroMap.get(id), 'player', i, this.rng));
    this.enemyUnits = enemyIds.map((id, i) => new BattleUnit(this.heroMap.get(id), 'enemy', i, this.rng));
    this.elapsed = 0;
    this.result = null;
    this.pendingImpacts = [];
    this.paused = false;
    this.eventLog = [];
  }
}
