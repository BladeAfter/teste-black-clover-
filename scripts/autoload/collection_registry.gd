extends Node

# Registro universal de coleções do AFK Arena Anime Multiverse
# Cada coleção é um Dictionary com metadata + heroes
# Novas coleções são adicionadas sem alterar o núcleo do combate

var collections: Dictionary = {}
var hero_index: Dictionary = {} # id -> { collection_id, data }

func _ready() -> void:
	register_collection(_build_black_clover())

func register_collection(collection: Dictionary) -> void:
	var cid: String = collection.get("id", "")
	if cid.is_empty():
		push_error("CollectionRegistry: collection missing 'id'")
		return
	collections[cid] = collection
	for hid in collection.get("heroes", {}).keys():
		var hero_data: Dictionary = collection["heroes"][hid].duplicate(true)
		hero_data["collection_id"] = cid
		hero_data["id"] = hid
		hero_index[hid] = hero_data

func get_hero(id: String) -> Dictionary:
	if hero_index.has(id):
		return hero_index[id].duplicate(true)
	push_warning("CollectionRegistry: hero not found: " + id)
	return {}

func get_collection(id: String) -> Dictionary:
	if collections.has(id):
		return collections[id].duplicate(true)
	return {}

func get_all_hero_ids() -> Array[String]:
	var ids: Array[String] = []
	for k in hero_index.keys():
		ids.append(k)
	return ids

func get_heroes_by_collection(collection_id: String) -> Array[String]:
	var result: Array[String] = []
	for hid in hero_index.keys():
		if hero_index[hid].get("collection_id", "") == collection_id:
			result.append(hid)
	return result

# --- Coleção Black Clover (primeira coleção) ---
func _build_black_clover() -> Dictionary:
	return {
		"id": "black_clover",
		"name": "Black Clover",
		"universe": "Clover Kingdom",
		"description": "Magic knights and grimoires of the Clover Kingdom.",
		"color_theme": Color(0.15, 0.1, 0.25),
		"heroes": {
			"bc_asta": {
				"name": "Asta",
				"faction": "black_bulls",
				"rarity": "legendary",
				"element": "antimagia",
				"class_type": "warrior",
				"role": "dps",
				"color": Color(0.2, 0.2, 0.2),
				"hp": 1200, "atk": 150, "def": 80, "spd": 100,
				"energy_max": 100,
				"skills": [
					{"id": "anti_magic_slash", "name": "Anti-Magic Slash", "cost": 60, "dmg_mult": 2.5, "type": "physical", "target": "single"}
				],
				"sprite_path": "",
				"portrait_path": ""
			},
			"bc_yuno": {
				"name": "Yuno",
				"faction": "golden_dawn",
				"rarity": "legendary",
				"element": "vento",
				"class_type": "mage",
				"role": "dps",
				"color": Color(0.4, 0.9, 0.4),
				"hp": 900, "atk": 180, "def": 50, "spd": 130,
				"energy_max": 100,
				"skills": [
					{"id": "spirit_storm", "name": "Spirit Storm", "cost": 70, "dmg_mult": 3.0, "type": "magic", "target": "aoe"}
				],
				"sprite_path": "",
				"portrait_path": ""
			},
			"bc_noelle": {
				"name": "Noelle",
				"faction": "black_bulls",
				"rarity": "epic",
				"element": "agua",
				"class_type": "mage",
				"role": "support",
				"color": Color(0.3, 0.5, 1.0),
				"hp": 950, "atk": 170, "def": 60, "spd": 110,
				"energy_max": 100,
				"skills": [
					{"id": "sea_dragon_roar", "name": "Sea Dragon Roar", "cost": 65, "dmg_mult": 2.8, "type": "magic", "target": "single"}
				],
				"sprite_path": "",
				"portrait_path": ""
			},
			"bc_yami": {
				"name": "Yami",
				"faction": "black_bulls",
				"rarity": "mythic",
				"element": "trevas",
				"class_type": "warrior",
				"role": "tank",
				"color": Color(0.3, 0.1, 0.4),
				"hp": 1400, "atk": 160, "def": 100, "spd": 85,
				"energy_max": 100,
				"skills": [
					{"id": "dark_cloak", "name": "Dark Cloak", "cost": 55, "dmg_mult": 2.2, "type": "physical", "target": "self_buff"}
				],
				"sprite_path": "",
				"portrait_path": ""
			},
			"bc_magna": {
				"name": "Magna",
				"faction": "black_bulls",
				"rarity": "rare",
				"element": "fogo",
				"class_type": "mage",
				"role": "dps",
				"color": Color(1.0, 0.4, 0.1),
				"hp": 1000, "atk": 165, "def": 65, "spd": 105,
				"energy_max": 100,
				"skills": [
					{"id": "fire_ball", "name": "Fire Ball", "cost": 50, "dmg_mult": 2.0, "type": "magic", "target": "single"}
				],
				"sprite_path": "",
				"portrait_path": ""
			},
			"bc_luck": {
				"name": "Luck",
				"faction": "black_bulls",
				"rarity": "epic",
				"element": "eletricidade",
				"class_type": "assassin",
				"role": "dps",
				"color": Color(1.0, 0.9, 0.2),
				"hp": 850, "atk": 190, "def": 45, "spd": 140,
				"energy_max": 100,
				"skills": [
					{"id": "thunder_god_boots", "name": "Thunder God Boots", "cost": 60, "dmg_mult": 2.6, "type": "magic", "target": "single"}
				],
				"sprite_path": "",
				"portrait_path": ""
			}
		}
	}
