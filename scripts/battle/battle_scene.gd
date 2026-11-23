extends Node2D

const BattleManagerScene = preload("res://scenes/battle_manager.tscn")
const BattleUIScene = preload("res://scenes/battle_ui.tscn")

var battle_manager: Node2D
var battle_ui: CanvasLayer

# Layer nodes
var background_layer: Node2D
var midground_layer: Node2D
var ground_layer: Node2D
var character_layer: Node2D
var effects_layer: Node2D

func _ready() -> void:
	_create_layers()
	_create_background()
	_create_midground()
	_create_ground()

	battle_manager = BattleManagerScene.instantiate()
	character_layer.add_child(battle_manager)

	battle_ui = BattleUIScene.instantiate()
	add_child(battle_ui)
	battle_ui.setup(battle_manager)

	var player_ids: Array[String] = ["bc_asta", "bc_yuno", "bc_noelle", "bc_yami", "bc_magna"]
	var enemy_ids: Array[String] = ["bc_luck", "bc_magna", "bc_yami", "bc_noelle", "bc_yuno"]
	battle_manager.start_battle(player_ids, enemy_ids)

func _create_layers() -> void:
	background_layer = Node2D.new()
	background_layer.name = "BackgroundLayer"
	background_layer.z_index = -10
	add_child(background_layer)

	midground_layer = Node2D.new()
	midground_layer.name = "MidgroundLayer"
	midground_layer.z_index = -5
	add_child(midground_layer)

	ground_layer = Node2D.new()
	ground_layer.name = "GroundLayer"
	ground_layer.z_index = -2
	add_child(ground_layer)

	character_layer = Node2D.new()
	character_layer.name = "CharacterLayer"
	character_layer.z_index = 0
	add_child(character_layer)

	effects_layer = Node2D.new()
	effects_layer.name = "EffectsLayer"
	effects_layer.z_index = 5
	add_child(effects_layer)

func _create_background() -> void:
	# Sky gradient — dark fantasy purple-blue
	var sky := ColorRect.new()
	sky.size = Vector2(1080, 1920)
	sky.color = Color(0.04, 0.02, 0.08)
	background_layer.add_child(sky)

	# Upper atmosphere glow
	var glow := ColorRect.new()
	glow.size = Vector2(1080, 600)
	glow.position = Vector2(0, 100)
	glow.color = Color(0.08, 0.04, 0.15, 0.6)
	background_layer.add_child(glow)

	# Distant mountains silhouette (left)
	var mountain_l := ColorRect.new()
	mountain_l.size = Vector2(400, 300)
	mountain_l.position = Vector2(-50, 500)
	mountain_l.rotation = deg_to_rad(-15)
	mountain_l.color = Color(0.06, 0.03, 0.1, 0.7)
	background_layer.add_child(mountain_l)

	# Distant mountains silhouette (right)
	var mountain_r := ColorRect.new()
	mountain_r.size = Vector2(450, 350)
	mountain_r.position = Vector2(750, 480)
	mountain_r.rotation = deg_to_rad(12)
	mountain_r.color = Color(0.07, 0.04, 0.12, 0.7)
	background_layer.add_child(mountain_r)

	# Moon / magical orb
	var moon := ColorRect.new()
	moon.size = Vector2(80, 80)
	moon.position = Vector2(820, 180)
	moon.color = Color(0.6, 0.5, 0.8, 0.3)
	background_layer.add_child(moon)

	# Stars / ambient particles
	for i in range(30):
		var star := ColorRect.new()
		star.size = Vector2(randf_range(2, 5), randf_range(2, 5))
		star.position = Vector2(randf_range(0, 1080), randf_range(50, 600))
		star.color = Color(0.6, 0.5, 0.9, randf_range(0.1, 0.4))
		background_layer.add_child(star)
		_twinkle(star)

func _create_midground() -> void:
	# Ruined pillars — left
	for i in range(3):
		var pillar := ColorRect.new()
		pillar.size = Vector2(30, randf_range(200, 400))
		pillar.position = Vector2(60 + i * 50, 600 + i * 30)
		pillar.color = Color(0.1, 0.07, 0.14, 0.5 + i * 0.1)
		midground_layer.add_child(pillar)

	# Ruined pillars — right
	for i in range(3):
		var pillar := ColorRect.new()
		pillar.size = Vector2(30, randf_range(200, 400))
		pillar.position = Vector2(920 + i * 50, 600 + i * 30)
		pillar.color = Color(0.1, 0.07, 0.14, 0.5 + i * 0.1)
		midground_layer.add_child(pillar)

	# Floating magical runes (ambient)
	for i in range(8):
		var rune := ColorRect.new()
		rune.size = Vector2(6, 6)
		rune.position = Vector2(randf_range(100, 980), randf_range(400, 900))
		rune.color = Color(0.4, 0.3, 0.7, randf_range(0.15, 0.35))
		midground_layer.add_child(rune)
		_float_rune(rune)

	# Fog layers
	for i in range(3):
		var fog := ColorRect.new()
		fog.size = Vector2(1200, 60)
		fog.position = Vector2(-60, 800 + i * 100)
		fog.color = Color(0.08, 0.05, 0.12, 0.15 - i * 0.03)
		midground_layer.add_child(fog)
		_drift_fog(fog, i)

func _create_ground() -> void:
	# Main ground plane with perspective gradient
	var ground_base := ColorRect.new()
	ground_base.size = Vector2(1080, 700)
	ground_base.position = Vector2(0, 1220)
	ground_base.color = Color(0.08, 0.06, 0.12)
	ground_layer.add_child(ground_base)

	# Ground highlight strip (arena floor)
	var arena_floor := ColorRect.new()
	arena_floor.size = Vector2(900, 500)
	arena_floor.position = Vector2(90, 1300)
	arena_floor.color = Color(0.1, 0.08, 0.15, 0.6)
	ground_layer.add_child(arena_floor)

	# Grid lines for depth perception
	for i in range(6):
		var line := ColorRect.new()
		line.size = Vector2(900, 2)
		line.position = Vector2(90, 1320 + i * 80)
		line.color = Color(0.15, 0.12, 0.22, 0.3 - i * 0.04)
		ground_layer.add_child(line)

	# Side borders
	for x in [80, 990]:
		var border := ColorRect.new()
		border.size = Vector2(10, 500)
		border.position = Vector2(x, 1300)
		border.color = Color(0.2, 0.15, 0.3, 0.4)
		ground_layer.add_child(border)

func _twinkle(star: ColorRect) -> void:
	var tween := create_tween().set_loops()
	var base_alpha: float = star.color.a
	tween.tween_property(star, "modulate:a", base_alpha * 2.0, randf_range(1.5, 4.0))
	tween.tween_property(star, "modulate:a", base_alpha * 0.3, randf_range(1.5, 4.0))

func _float_rune(rune: ColorRect) -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(rune, "position:y", rune.position.y - randf_range(20, 50), randf_range(3, 6))
	tween.tween_property(rune, "modulate:a", 0.0, randf_range(1, 2))
	tween.tween_property(rune, "position:y", rune.position.y + randf_range(20, 50), randf_range(3, 6))
	tween.tween_property(rune, "modulate:a", rune.color.a, randf_range(1, 2))

func _drift_fog(fog: ColorRect, index: int) -> void:
	var tween := create_tween().set_loops()
	var drift: float = 40.0 + index * 20.0
	var duration: float = 8.0 + index * 3.0
	tween.tween_property(fog, "position:x", fog.position.x + drift, duration)
	tween.tween_property(fog, "position:x", fog.position.x - drift, duration)