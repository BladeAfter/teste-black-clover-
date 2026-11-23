extends RefCounted
var data: Dictionary
var atlases: Dictionary = {}
var textures: Dictionary = {}
const RARITY_COLORS := [Color("88c596"),Color("78b5f5"),Color("c38aef"),Color("f5ce73")]

func _init() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/roster/catalog.json"))

func count() -> int: return 6 + data.heroes.size()

func info(id: int) -> Dictionary:
	if id >= 6: return data.heroes[id-6]
	return {"rarity":"Lendário","stars":5,"behavior":id,"vfx":id,"hp":1.0,"attack":1.0,"element_id":[9,2,1,7,0,4][id]}

func rarity_color(id: int) -> Color:
	return RARITY_COLORS[data.rarities.find(info(id).rarity)]

func texture(id: int, original: Texture2D) -> Texture2D:
	if textures.has(id): return textures[id]
	var result := AtlasTexture.new()
	if id < 6:
		result.atlas = original
		result.region = Rect2((id%3)*512,int(id/3)*512,512,512)
	else:
		var entry := info(id)
		if not atlases.has(entry.sheet): atlases[entry.sheet] = load("res://assets/roster/"+entry.sheet)
		result.atlas = atlases[entry.sheet]
		var cell := result.atlas.get_size()/5.0
		result.region = Rect2(Vector2(int(entry.cell)%5,int(int(entry.cell)/5))*cell,cell)
	textures[id] = result
	return result

func roll(rng: RandomNumberGenerator = null) -> int:
	var ticket := rng.randf()*100.0 if rng else randf()*100.0
	var rarity := "Lendário"
	var total := 0.0
	for key in data.rarities:
		total += float(data.summon_weights[key])
		if ticket < total:
			rarity = key
			break
	var pool: Array[int] = []
	for id in range(count()):
		if info(id).rarity == rarity: pool.append(id)
	return pool[rng.randi_range(0,pool.size()-1) if rng else randi_range(0,pool.size()-1)]
