extends RefCounted
## Two front positions closer to the opponent, three rear positions behind.
const HERO_HEIGHT := 112.0
const ENEMY_HEIGHT := 100.0
const BOSS_HEIGHT := 120.0
const COMBAT_HERO_HEIGHT := 150.0
const COMBAT_ENEMY_HEIGHT := 140.0
const COMBAT_BOSS_HEIGHT := 165.0

static func slots(enemy := false, expanded := false) -> Array[Vector2]:
	var result: Array[Vector2] = [Vector2(430,300),Vector2(430,440),Vector2(155,220),Vector2(155,330),Vector2(155,440)]
	if expanded:
		result = [Vector2(430,420),Vector2(430,620),Vector2(155,350),Vector2(155,485),Vector2(155,620)]
	if enemy:
		for i in range(result.size()): result[i].x = 1244.0-result[i].x
	return result

static func height_for(slot: int, enemy := false, boss := false, expanded := false) -> float:
	if boss: return COMBAT_BOSS_HEIGHT if expanded else BOSS_HEIGHT
	if slot >= 2: return (105.0 if enemy else 112.0) if expanded else (82.0 if enemy else 90.0)
	return (COMBAT_ENEMY_HEIGHT if enemy else COMBAT_HERO_HEIGHT) if expanded else (ENEMY_HEIGHT if enemy else HERO_HEIGHT)
