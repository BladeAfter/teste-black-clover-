extends RefCounted
## Two separated rows, with three rear units and two front units.
const HERO_HEIGHT := 150.0
const ENEMY_HEIGHT := 135.0
const BOSS_HEIGHT := 165.0

static func slots(enemy := false) -> Array[Vector2]:
	var result: Array[Vector2] = [Vector2(220,445),Vector2(420,445),Vector2(115,260),Vector2(275,260),Vector2(435,260)]
	if enemy:
		for i in range(result.size()): result[i].x = 1244.0-result[i].x
	return result
