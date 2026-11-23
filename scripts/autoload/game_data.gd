extends Node

# Dados dos heróis disponíveis
var heroes: Dictionary = {
	"asta": {
		"name": "Asta",
		"element": "antimagia",
		"color": Color(0.2, 0.2, 0.2),
		"hp": 1200,
		"atk": 150,
		"def": 80,
		"spd": 100,
		"energy_max": 100,
		"skill_name": "Anti-Magic Slash",
		"skill_cost": 60,
		"skill_dmg_mult": 2.5,
		"type": "physical"
	},
	"yuno": {
		"name": "Yuno",
		"element": "vento",
		"color": Color(0.4, 0.9, 0.4),
		"hp": 900,
		"atk": 180,
		"def": 50,
		"spd": 130,
		"energy_max": 100,
		"skill_name": "Spirit Storm",
		"skill_cost": 70,
		"skill_dmg_mult": 3.0,
		"type": "magic"
	},
	"noelle": {
		"name": "Noelle",
		"element": "agua",
		"color": Color(0.3, 0.5, 1.0),
		"hp": 950,
		"atk": 170,
		"def": 60,
		"spd": 110,
		"energy_max": 100,
		"skill_name": "Sea Dragon Roar",
		"skill_cost": 65,
		"skill_dmg_mult": 2.8,
		"type": "magic"
	},
	"yami": {
		"name": "Yami",
		"element": "trevas",
		"color": Color(0.3, 0.1, 0.4),
		"hp": 1400,
		"atk": 160,
		"def": 100,
		"spd": 85,
		"energy_max": 100,
		"skill_name": "Dark Cloak",
		"skill_cost": 55,
		"skill_dmg_mult": 2.2,
		"type": "physical"
	},
	"magna": {
		"name": "Magna",
		"element": "fogo",
		"color": Color(1.0, 0.4, 0.1),
		"hp": 1000,
		"atk": 165,
		"def": 65,
		"spd": 105,
		"energy_max": 100,
		"skill_name": "Fire Ball",
		"skill_cost": 50,
		"skill_dmg_mult": 2.0,
		"type": "magic"
	},
	"luck": {
		"name": "Luck",
		"element": "eletricidade",
		"color": Color(1.0, 0.9, 0.2),
		"hp": 850,
		"atk": 190,
		"def": 45,
		"spd": 140,
		"energy_max": 100,
		"skill_name": "Thunder God Boots",
		"skill_cost": 60,
		"skill_dmg_mult": 2.6,
		"type": "magic"
	}
}

func get_hero(id: String) -> Dictionary:
	if heroes.has(id):
		return heroes[id].duplicate(true)
	push_error("Hero not found: " + id)
	return {}