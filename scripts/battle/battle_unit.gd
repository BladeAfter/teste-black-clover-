extends Node2D

signal died(unit)
signal skill_used(unit)
signal attacked(unit, target, damage)

const HeroVisualScene = preload("res://scenes/hero_visual.tscn")

@export var hero_id: String = ""
@export var is_enemy: bool = false

var data: Dictionary = {}
var current_hp: int = 0
var current_energy: int = 0
var max_hp: int = 0
var max_energy: int = 100

var attack_timer: float = 0.0
var attack_interval: float = 1.5
var is_dead: bool = false
var battle_speed: float = 1.0

# Visual layer (separated from logic)
var visual: Node2D = null

# UI nodes
var hp_bar_bg: ColorRect
var hp_bar_fill: ColorRect
var energy_bar_bg: ColorRect
var energy_bar_fill: ColorRect
var name_label: Label
var damage_label: Label

# Movement state
var home_position: Vector2 = Vector2.ZERO
var is_moving: bool = false
var move_target: Vector2 = Vector2.ZERO
var move_speed: float = 400.0
var returning: bool = false

func setup(p_hero_id: String, p_is_enemy: bool = false) -> void:
	hero_id = p_hero_id
	is_enemy = p_is_enemy

	# Universal hero lookup via CollectionRegistry autoload
	var registry = get_node_or_null("/root/CollectionRegistry")
	if registry:
		data = registry.get_hero(hero_id)
	else:
		push_error("BattleUnit: CollectionRegistry autoload not found")
		return

	if data.is_empty():
		push_error("BattleUnit: hero not found in any collection: " + hero_id)
		return

	max_hp = data.get("hp", 1000)
	current_hp = max_hp
	max_energy = data.get("energy_max", 100)
	current_energy = 0
	attack_interval = 2.0 - (data.get("spd", 100) / 200.0)
	attack_interval = clampf(attack_interval, 0.6, 3.0)

	_create_visual()
	_create_ui()

func _get_primary_skill() -> Dictionary:
	var skills: Array = data.get("skills", [])
	if skills.size() > 0:
		return skills[0]
	return {"id": "default_attack", "name": "Attack", "cost": 999, "dmg_mult": 1.0, "type": "physical", "target": "single"}

func _create_visual() -> void:
	visual = HeroVisualScene.instantiate()
	add_child(visual)
	visual.setup(hero_id, is_enemy, data.get("color", Color.GRAY))

func _create_ui() -> void:
	name_label = Label.new()
	name_label.text = data.get("name", hero_id)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(-80, -200)
	name_label.custom_minimum_size = Vector2(160, 30)
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color.WHITE if is_enemy else Color(1, 0.9, 0.5))
	add_child(name_label)

	hp_bar_bg = ColorRect.new()
	hp_bar_bg.size = Vector2(100, 10)
	hp_bar_bg.color = Color(0.15, 0.0, 0.0, 0.85)
	hp_bar_bg.position = Vector2(-50, -185)
	add_child(hp_bar_bg)

	hp_bar_fill = ColorRect.new()
	hp_bar_fill.size = Vector2(100, 10)
	hp_bar_fill.color = Color(0.1, 0.85, 0.2) if not is_enemy else Color(0.9, 0.2, 0.15)
	hp_bar_fill.position = Vector2(-50, -185)
	add_child(hp_bar_fill)

	energy_bar_bg = ColorRect.new()
	energy_bar_bg.size = Vector2(100, 6)
	energy_bar_bg.color = Color(0.05, 0.05, 0.2, 0.85)
	energy_bar_bg.position = Vector2(-50, -173)
	add_child(energy_bar_bg)

	energy_bar_fill = ColorRect.new()
	energy_bar_fill.size = Vector2(0, 6)
	energy_bar_fill.color = Color(0.3, 0.55, 1.0)
	energy_bar_fill.position = Vector2(-50, -173)
	add_child(energy_bar_fill)

	damage_label = Label.new()
	damage_label.visible = false
	damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	damage_label.position = Vector2(-60, -230)
	damage_label.custom_minimum_size = Vector2(120, 40)
	damage_label.add_theme_font_size_override("font_size", 28)
	damage_label.add_theme_color_override("font_color", Color.RED)
	add_child(damage_label)

func _process(delta: float) -> void:
	if is_dead:
		return

	if is_moving:
		var dir := (move_target - position).normalized()
		var dist := position.distance_to(move_target)
		var step := move_speed * delta * battle_speed
		if dist <= step:
			position = move_target
			is_moving = false
			if returning:
				returning = false
				if visual:
					visual.return_to_idle()
		else:
			position += dir * step
		return

	attack_timer += delta * battle_speed
	if attack_timer >= attack_interval:
		attack_timer = 0.0
		_do_attack()

func _do_attack() -> void:
	var targets: Array[Node] = get_tree().get_nodes_in_group("battle_units")
	var valid_targets: Array = []
	for node in targets:
		if node != self and node.is_enemy != is_enemy and not node.is_dead:
			valid_targets.append(node)

	if valid_targets.is_empty():
		return

	var target = valid_targets[0]
	for t in valid_targets:
		if t.current_hp < target.current_hp:
			target = t

	var skill := _get_primary_skill()
	if current_energy >= skill.get("cost", 999):
		_use_skill(target, skill)
	else:
		_normal_attack(target)

func _normal_attack(target) -> void:
	if visual:
		visual.play("attack")

	var lunge_dir := 60.0 if not is_enemy else -60.0
	move_target = home_position + Vector2(lunge_dir, 0)
	is_moving = true
	returning = false

	var tween := create_tween()
	tween.tween_interval(0.15 / battle_speed)
	tween.tween_callback(func():
		move_target = home_position
		is_moving = true
		returning = true
	)

	var dmg_tween := create_tween()
	dmg_tween.tween_interval(0.12 / battle_speed)
	dmg_tween.tween_callback(func():
		var base_dmg: int = data.get("atk", 50)
		var defense: int = target.data.get("def", 0)
		var damage: int = maxi(1, base_dmg - defense / 3)
		damage = int(damage * randf_range(0.9, 1.1))
		target.take_damage(damage)
		current_energy = mini(current_energy + 15, max_energy)
		_update_bars()
		attacked.emit(self, target, damage)
		_show_floating_text(str(damage), Color.WHITE)
	)

func _use_skill(target, skill: Dictionary) -> void:
	current_energy -= skill.get("cost", 50)
	if visual:
		visual.play("skill")

	var dmg_tween := create_tween()
	dmg_tween.tween_interval(0.2 / battle_speed)
	dmg_tween.tween_callback(func():
		var base_dmg: int = data.get("atk", 50)
		var mult: float = skill.get("dmg_mult", 2.0)
		var defense: int = target.data.get("def", 0)
		var damage: int = maxi(1, int(base_dmg * mult) - defense / 4)
		damage = int(damage * randf_range(0.95, 1.05))
		target.take_damage(damage)
		_update_bars()
		skill_used.emit(self)
		attacked.emit(self, target, damage)
		_show_floating_text(str(damage) + "!", Color.YELLOW)
	)

func take_damage(amount: int) -> void:
	if is_dead:
		return
	current_hp = maxi(0, current_hp - amount)
	_update_bars()
	_show_floating_text("-" + str(amount), Color.RED)

	if visual:
		visual.play("hit")
		var tween := create_tween()
		tween.tween_interval(0.3 / battle_speed)
		tween.tween_callback(func():
			if visual and not is_dead:
				visual.return_to_idle()
		)

	if current_hp <= 0:
		_die()

func _die() -> void:
	is_dead = true
	died.emit(self)
	remove_from_group("battle_units")

	if visual:
		visual.play("death")

	var tween := create_tween()
	tween.tween_interval(0.8)
	tween.tween_callback(queue_free)

func _update_bars() -> void:
	if hp_bar_fill:
		var hp_ratio: float = float(current_hp) / float(max_hp) if max_hp > 0 else 0.0
		hp_bar_fill.size.x = 100.0 * hp_ratio
	if energy_bar_fill:
		var en_ratio: float = float(current_energy) / float(max_energy) if max_energy > 0 else 0.0
		energy_bar_fill.size.x = 100.0 * en_ratio

func _show_floating_text(text: String, color: Color) -> void:
	if not damage_label:
		return
	damage_label.text = text
	damage_label.add_theme_color_override("font_color", color)
	damage_label.visible = true
	damage_label.modulate.a = 1.0
	damage_label.position.y = -230

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(damage_label, "position:y", -270.0, 0.6)
	tween.tween_property(damage_label, "modulate:a", 0.0, 0.6)
	tween.set_parallel(false)
	tween.tween_callback(func(): damage_label.visible = false)

func set_battle_speed(speed: float) -> void:
	battle_speed = speed

func set_home_position(pos: Vector2) -> void:
	home_position = pos
	position = pos