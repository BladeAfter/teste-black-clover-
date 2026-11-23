extends Node2D

signal battle_ended(player_won: bool)

enum BattleState { IDLE, RUNNING, PAUSED, ENDED }

var state: int = BattleState.IDLE
var speed_multiplier: float = 1.0
var auto_mode: bool = true

var player_team: Array = []
var enemy_team: Array = []

# Formação 5v5 em duas linhas com profundidade
# Linha da frente: 3 unidades (maiores, mais abaixo)
# Linha de trás: 2 unidades (menores, mais acima)
const PLAYER_FRONT: Array[Vector2] = [
	Vector2(180, 1100),
	Vector2(320, 1200),
	Vector2(180, 1300),
]
const PLAYER_BACK: Array[Vector2] = [
	Vector2(380, 950),
	Vector2(420, 1050),
]

const ENEMY_FRONT: Array[Vector2] = [
	Vector2(900, 1100),
	Vector2(760, 1200),
	Vector2(900, 1300),
]
const ENEMY_BACK: Array[Vector2] = [
	Vector2(700, 950),
	Vector2(660, 1050),
]

# Escala por linha para dar profundidade
const FRONT_SCALE: float = 1.0
const BACK_SCALE: float = 0.82

func start_battle(player_hero_ids: Array[String], enemy_hero_ids: Array[String]) -> void:
	if state != BattleState.IDLE:
		push_warning("BattleManager: battle already in progress")
		return

	_clear_units()

	var UnitScene = preload("res://scenes/battle_unit.tscn")

	# Spawn player team — front 3, back 2
	for i in range(mini(player_hero_ids.size(), 5)):
		var unit = UnitScene.instantiate()
		add_child(unit)
		unit.setup(player_hero_ids[i], false)
		if i < 3:
			unit.set_home_position(PLAYER_FRONT[i])
			unit.scale = Vector2(FRONT_SCALE, FRONT_SCALE)
		else:
			unit.set_home_position(PLAYER_BACK[i - 3])
			unit.scale = Vector2(BACK_SCALE, BACK_SCALE)
		unit.add_to_group("battle_units")
		player_team.append(unit)
		unit.died.connect(_on_unit_died)

	# Spawn enemy team — front 3, back 2
	for i in range(mini(enemy_hero_ids.size(), 5)):
		var unit = UnitScene.instantiate()
		add_child(unit)
		unit.setup(enemy_hero_ids[i], true)
		if i < 3:
			unit.set_home_position(ENEMY_FRONT[i])
			unit.scale = Vector2(FRONT_SCALE, FRONT_SCALE)
		else:
			unit.set_home_position(ENEMY_BACK[i - 3])
			unit.scale = Vector2(BACK_SCALE, BACK_SCALE)
		unit.add_to_group("battle_units")
		enemy_team.append(unit)
		unit.died.connect(_on_unit_died)

	state = BattleState.RUNNING

func _clear_units() -> void:
	for unit in player_team:
		if is_instance_valid(unit):
			unit.queue_free()
	for unit in enemy_team:
		if is_instance_valid(unit):
			unit.queue_free()
	player_team.clear()
	enemy_team.clear()

func _on_unit_died(_unit) -> void:
	if state == BattleState.ENDED:
		return

	var player_alive: int = 0
	var enemy_alive: int = 0

	for u in player_team:
		if is_instance_valid(u) and not u.is_dead:
			player_alive += 1
	for u in enemy_team:
		if is_instance_valid(u) and not u.is_dead:
			enemy_alive += 1

	if player_alive == 0:
		_end_battle(false)
	elif enemy_alive == 0:
		_end_battle(true)

func _end_battle(player_won: bool) -> void:
	state = BattleState.ENDED
	battle_ended.emit(player_won)

func set_speed(multiplier: float) -> void:
	speed_multiplier = multiplier
	for unit in player_team:
		if is_instance_valid(unit):
			unit.set_battle_speed(speed_multiplier)
	for unit in enemy_team:
		if is_instance_valid(unit):
			unit.set_battle_speed(speed_multiplier)

func toggle_pause() -> void:
	if state == BattleState.RUNNING:
		state = BattleState.PAUSED
		set_speed(0.0)
	elif state == BattleState.PAUSED:
		state = BattleState.RUNNING
		set_speed(speed_multiplier if speed_multiplier > 0.0 else 1.0)

func reset() -> void:
	state = BattleState.IDLE
	_clear_units()