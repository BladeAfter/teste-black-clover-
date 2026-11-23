extends RefCounted
## Deterministic encounters: saved stage/floor alone reproduces the same battle.
var data: Dictionary
var textures: Dictionary = {}
var regions: Dictionary = {}

func _init() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/encounters/catalog.json"))

func interval(mode: String, category: String) -> int:
	return int(data.rules[("tower" if mode == "Torre Infinita" else "campaign") + "_" + category + "_every"])

func is_boss(mode: String, rank: int) -> bool:
	return rank % interval(mode, "boss") == 0

func scene_info(mode: String, rank: int) -> Dictionary:
	var index := int((maxi(1, rank) - 1) / interval(mode, "scene")) % 40
	if mode == "Torre Infinita": index = (index + 16) % 40
	return data.scenes[index]

func texture(info: Dictionary) -> Texture2D:
	var key: String = info.sheet + ":" + str(info.cell)
	if regions.has(key): return regions[key]
	if not textures.has(info.sheet): textures[info.sheet] = load("res://assets/encounters/" + info.sheet)
	var atlas: Texture2D = textures[info.sheet]
	var cell_size := atlas.get_size() / Vector2(info.columns, info.rows)
	var result := AtlasTexture.new()
	result.atlas = atlas
	result.region = Rect2(Vector2(int(info.cell) % int(info.columns), int(int(info.cell) / int(info.columns))) * cell_size, cell_size)
	regions[key] = result
	return result

func lineup(mode: String, rank: int) -> Array:
	var result: Array = []
	var wave := maxi(1, rank) - 1
	# Each biome selects its own species instead of mixing unrelated creatures.
	var pool: Array = scene_info(mode,rank).enemy_pool
	for i in range(4 if is_boss(mode, rank) else 5):
		result.append(data.enemies[int(pool[(wave * 3 + i) % pool.size()])])
	if is_boss(mode, rank):
		var boss_index := (int(rank / interval(mode,"boss")) - 1 + (16 if mode == "Torre Infinita" else 0)) % 30
		result.push_front(data.bosses[boss_index])
	return result

func spawn(game, mode: String, rank: int) -> void:
	var slots := preload("res://scripts/visuals/battle_formation.gd").slots(true,bool(game.field.get_meta("expanded",false)))
	var entries := lineup(mode,rank)
	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		var boss := is_boss(mode,rank) and i == 0
		var display_height := preload("res://scripts/visuals/battle_formation.gd").height_for(i,true,boss,bool(game.field.get_meta("expanded",false)))
		var unit = game._spawn(int(entry.behavior),slots[i],true,display_height,true)
		unit.body.texture = texture(entry)
		var cell_size: Vector2 = unit.body.texture.get_size()
		unit.body.scale = Vector2.ONE * display_height / cell_size.y
		unit.body.offset = Vector2(0, -cell_size.y * 0.44)
		unit.body.flip_h = false
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/encounter_alpha.gdshader")
		unit.body.material = material
		# Sublinear growth keeps late chapters within the existing hero level cap.
		var difficulty := float(rank) if rank <= 20 else 20.0 + sqrt(float(rank - 20)) * 3.0
		unit.defense_rank = difficulty
		unit.max_hp = (800.0 + difficulty * 170.0) * float(entry.hp)
		unit.hp = unit.max_hp
		unit.attack_modifier = float(entry.attack) * (90.0 + difficulty * 17.0) / (90.0 + game.enemy_rank() * 17.0)
		unit.custom_skill = entry.name + " ? " + entry.skill
		unit.combat_element = int(entry.element)
		unit.set_meta("encounter_id", int(entry.id))
		unit.set_meta("boss", boss)
		unit.queue_redraw()
