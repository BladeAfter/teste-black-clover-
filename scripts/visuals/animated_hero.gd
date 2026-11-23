extends Node2D
## Visual adapter only. BattleUnit retains all stats, targeting and skill rules.
const VFX = preload("res://scripts/visuals/element_vfx.gd")
const FLASH = preload("res://shaders/hero_flash.gdshader")
const Layout = preload("res://scripts/visuals/idle_layout.gd")
const COLORS := {"asta": Color("f15b71"), "yuno": Color("81e8b1"), "noelle": Color("78d9f5"), "yami": Color("b48aed"), "magna": Color("ffa14d"), "luck": Color("ffe47a")}
enum AnimState { IDLE, RUN, ATTACK, SKILL, HIT, DEATH, VICTORY, ULTIMATE }
var current_state: int = AnimState.IDLE
var hero_id := ""
var is_enemy := false
var element_color := Color.WHITE
var rig: Node2D
var anim_player: AnimationPlayer
var material_fx: ShaderMaterial
var parts: Dictionary = {}
var unit: Node
var phase := 0.0
var aura_power := 0.0
var terminal := false
var painted := false
var slot := 0
var presentation_scale := 0.7
var sprite_height := 270.0
var health_frame: StyleBoxFlat
var skill_label: Label
var viewport_size := Vector2.ZERO

func setup(id: String, enemy: bool, color: Color) -> void:
	hero_id = id.trim_prefix("bc_")
	is_enemy = enemy
	element_color = COLORS.get(hero_id, color)
	unit = get_parent()
	sprite_height = {"yami": 300.0, "luck": 260.0, "magna": 270.0}.get(hero_id, 270.0)
	material_fx = ShaderMaterial.new()
	material_fx.shader = FLASH
	material_fx.set_shader_parameter("flash", 0.0)
	rig = Node2D.new()
	rig.name = "Rig"
	rig.scale.x = -1.0 if enemy else 1.0
	add_child(rig)
	var image := Sprite2D.new()
	image.name = "Body"
	var path := "res://assets/heroes/painted/%s.png" % hero_id
	painted = ResourceLoader.exists(path)
	image.texture = load(path if painted else "res://assets/heroes/%s.svg" % hero_id)
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	image.scale = Vector2.ONE * sprite_height / image.texture.get_height()
	image.position = Vector2(0, -sprite_height * 0.5)
	image.material = material_fx
	rig.add_child(image)
	parts["body"] = image
	health_frame = StyleBoxFlat.new()
	health_frame.bg_color = Color("131925")
	health_frame.border_color = Color("c8a46c")
	health_frame.set_border_width_all(2)
	health_frame.set_corner_radius_all(5)
	anim_player = AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	add_child(anim_player)
	_build_animations()
	anim_player.animation_finished.connect(_animation_finished)
	if unit.has_signal("attacked"): unit.connect("attacked", _on_impact)
	call_deferred("_bind_presentation")
	play("idle")

func _bind_presentation() -> void:
	var battle := _battle_host()
	if battle.has_node("CharacterLayer") and not battle.has_node("ArenaPresentation"):
		battle.add_child(load("res://scenes/visuals/arena_presentation.tscn").instantiate())
	var manager := unit.get_parent()
	var team: Array = manager.get("enemy_team" if is_enemy else "player_team")
	slot = maxi(team.find(unit), 0)
	if manager.has_signal("battle_ended"): manager.connect("battle_ended", _battle_ended)
	for key in ["name_label", "hp_bar_bg", "hp_bar_fill", "energy_bar_bg", "energy_bar_fill", "damage_label"]:
		var old: CanvasItem = unit.get(key)
		if old: old.hide()
	skill_label = Label.new()
	skill_label.position = Vector2(-150, -sprite_height - 60)
	skill_label.size = Vector2(300, 28)
	skill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_label.add_theme_font_size_override("font_size", 19)
	skill_label.add_theme_color_override("font_color", element_color.lightened(0.5))
	skill_label.add_theme_color_override("font_outline_color", Color("101825"))
	skill_label.add_theme_constant_override("outline_size", 6)
	skill_label.visible = false
	add_child(skill_label)
	var skills: Array = unit.get("data").get("skills", [])
	skill_label.text = skills[0].get("name", "Especial") if not skills.is_empty() else "Especial"
	_update_formation()

func _update_formation() -> void:
	viewport_size = get_viewport_rect().size
	var destination := Layout.anchor(viewport_size, slot, is_enemy)
	presentation_scale = Layout.actor_scale(viewport_size, slot)
	# Cancel logical lunge in the adapter; AnimationPlayer owns the short visual step.
	position = (destination - unit.position) / unit.scale
	scale = Vector2.ONE * presentation_scale / unit.scale
	z_as_relative = false
	z_index = int(destination.y)
	if skill_label: skill_label.position.y = -sprite_height - 62

func _build_animations() -> void:
	var library := AnimationLibrary.new()
	for state in ["idle", "run", "attack", "skill", "ultimate", "hit", "death", "victory"]:
		var a := Animation.new()
		a.length = {"idle": 2.1, "run": 0.32, "attack": 0.46, "skill": 0.72, "ultimate": 1.0, "hit": 0.24, "death": 0.75, "victory": 1.4}[state]
		a.loop_mode = Animation.LOOP_LINEAR if state in ["idle", "run", "victory"] else Animation.LOOP_NONE
		var h := a.length * 0.5
		var facing := -1.0 if is_enemy else 1.0
		var poses: Dictionary = {
			"idle": [Vector2.ZERO, Vector2(0, -1.7), Vector2.ZERO],
			"run": [Vector2.ZERO, Vector2(8 * facing, -3), Vector2.ZERO],
			"attack": [Vector2.ZERO, Vector2(30 * facing, -3), Vector2.ZERO],
			"skill": [Vector2.ZERO, Vector2(0, -6), Vector2.ZERO],
			"ultimate": [Vector2.ZERO, Vector2(0, -10), Vector2.ZERO],
			"hit": [Vector2.ZERO, Vector2(-6 * facing, 1), Vector2.ZERO],
			"death": [Vector2.ZERO, Vector2(0, 5), Vector2(0, 16)],
			"victory": [Vector2.ZERO, Vector2(0, -3), Vector2.ZERO]}
		if state == "attack":
			# Anticipation, quick approach, impact, settle back to the same slot.
			_track(a, "Rig:position", [0.0, 0.06, 0.12, 0.23, a.length],
				[Vector2.ZERO, Vector2(-4 * facing, 1), Vector2(26 * facing, -3), Vector2(30 * facing, 0), Vector2.ZERO])
		else:
			_track(a, "Rig:position", [0.0, h, a.length], poses[state])
		_track(a, "Rig:rotation", [0.0, h, a.length], [0.0, (-0.035 if state == "attack" else -0.009) * facing, 1.1 * facing if state == "death" else 0.0])
		var sway := -0.008
		if state in ["skill", "ultimate"]: sway = -0.025
		if state == "hit": sway = 0.025
		_track(a, "Rig/Body:rotation", [0.0, h, a.length], [0.0, sway, 0.0])
		_track(a, "Rig:modulate:a", [0.0, h, a.length], [1.0, 0.7 if state == "death" else 1.0, 0.0 if state == "death" else 1.0])
		library.add_animation(state, a)
	anim_player.add_animation_library("", library)

func _track(animation: Animation, path: String, times: Array, values: Array) -> void:
	var index := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(index, NodePath(path))
	animation.track_set_interpolation_type(index, Animation.INTERPOLATION_CUBIC)
	for i in range(times.size()): animation.track_insert_key(index, times[i], values[i])

func play(animation: String) -> void:
	if not anim_player or not anim_player.has_animation(animation) or terminal: return
	if animation == "hit" and current_state in [AnimState.ATTACK, AnimState.SKILL, AnimState.ULTIMATE]:
		material_fx.set_shader_parameter("flash", 0.6)
		return
	current_state = {"idle": AnimState.IDLE, "run": AnimState.RUN, "attack": AnimState.ATTACK, "skill": AnimState.SKILL, "ultimate": AnimState.ULTIMATE, "hit": AnimState.HIT, "death": AnimState.DEATH, "victory": AnimState.VICTORY}[animation]
	terminal = animation in ["death", "victory"]
	if skill_label: skill_label.visible = animation in ["skill", "ultimate"]
	anim_player.play(animation, 0.06)
	if animation in ["skill", "attack", "ultimate"]:
		aura_power = 1.0
		var effect := "slash" if animation == "attack" else "cast"
		var height := sprite_height * 0.5 if animation == "attack" else 5.0
		var fx := VFX.spawn(_battle_host(), global_position + Vector2(0, -height * presentation_scale), hero_id, element_color, effect, -1.0 if is_enemy else 1.0, unit)
		fx.scale = Vector2.ONE * presentation_scale * 0.8
		if animation in ["skill", "ultimate"]:
			call_deferred("_request_cinematic", animation == "ultimate")
	if animation == "hit":
		material_fx.set_shader_parameter("flash_color", Color("ffe0d5"))
		material_fx.set_shader_parameter("flash", 0.7)

func _request_cinematic(ultimate: bool) -> void:
	var presentation := _battle_host().get_node_or_null("ArenaPresentation")
	if presentation: presentation.highlight_skill(self, ultimate)

func _process(delta: float) -> void:
	if not anim_player or not is_instance_valid(unit): return
	var legacy_damage: Label = unit.get("damage_label")
	if legacy_damage: legacy_damage.hide()
	_update_formation()
	var speed := float(unit.get("battle_speed"))
	anim_player.speed_scale = speed
	phase += delta * speed
	aura_power = move_toward(aura_power, 0.0, delta * speed * 2.2)
	var flash: float = material_fx.get_shader_parameter("flash")
	material_fx.set_shader_parameter("flash", move_toward(flash, 0.0, delta * speed * 6.0))
	if not terminal and bool(unit.get("is_moving")) and current_state == AnimState.IDLE: play("run")
	elif current_state == AnimState.RUN and not bool(unit.get("is_moving")): play("idle")
	queue_redraw()

func _draw() -> void:
	if not rig or not health_frame: return
	for i in range(4):
		draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.23))
		draw_circle(Vector2.ZERO, 42.0 - i * 7.0, Color(0.015, 0.025, 0.04, 0.08))
	draw_set_transform(Vector2.ZERO)
	if not terminal: _draw_aura()
	# Health is drawn above the rig, independent of its breathing/lunge animation.
	var y := -sprite_height - 15.0
	draw_style_box(health_frame, Rect2(-67, y - 3, 134, 18))
	var ratio := clampf(float(unit.get("current_hp")) / maxf(float(unit.get("max_hp")), 1), 0, 1)
	draw_rect(Rect2(-64, y, 128 * ratio, 12), Color("e96d67") if is_enemy else Color("86df96"))
	draw_circle(Vector2(-78, y + 6), 13, Color("18192c"))
	draw_circle(Vector2(-78, y + 6), 13, Color("dfbb73"), false, 2, true)
	draw_circle(Vector2(-78, y + 6), 6, element_color)

func _draw_aura() -> void:
	var strength := 0.08 + aura_power * 0.35
	if hero_id in ["yuno", "noelle", "asta", "yami"]:
		draw_set_transform(Vector2(0, -sprite_height * 0.45), -0.2, Vector2(1, 0.4))
		var start := phase * 1.4
		draw_arc(Vector2.ZERO, 78, start, start + PI * 1.4, 36, Color(element_color, strength), 4.5, true)
		draw_arc(Vector2.ZERO, 81, start, start + PI, 36, Color(element_color.lightened(0.5), strength * 0.8), 1.5, true)
		draw_set_transform(Vector2.ZERO)
	for i in range(3):
		var t := fposmod(phase * 0.4 + i / 3.0, 1.0)
		var p := Vector2(sin(i * 2.4 + phase) * 36, -t * sprite_height * 0.7)
		draw_circle(p, 1.5, Color(element_color, sin(t * PI) * strength))

func _on_impact(_attacker: Node, target: Node, damage: int) -> void:
	if not is_instance_valid(target): return
	var target_visual: Node2D = target.get("visual")
	var fx := VFX.spawn(_battle_host(), target_visual.global_position + Vector2(0, -target_visual.sprite_height * target_visual.presentation_scale * 0.5), hero_id, element_color, "impact", -1.0 if is_enemy else 1.0, unit)
	fx.scale = Vector2.ONE * target_visual.presentation_scale * 0.8
	var number := VFX.spawn(_battle_host(), target_visual.global_position + Vector2(0, -(target_visual.sprite_height + 40) * target_visual.presentation_scale), hero_id, element_color, "number", 1, unit)
	number.damage_value = str(damage)
	number.scale = Vector2.ONE * Layout.ui_scale(viewport_size) * 0.85

func _battle_host() -> Node:
	var ancestor: Node = get_parent()
	while ancestor:
		if ancestor.has_node("CharacterLayer"): return ancestor
		ancestor = ancestor.get_parent()
	return get_parent()

func _animation_finished(animation: StringName) -> void:
	if animation != &"death": return_to_idle()

func return_to_idle() -> void:
	if terminal: return
	if current_state in [AnimState.ATTACK, AnimState.SKILL, AnimState.ULTIMATE] and anim_player.is_playing(): return
	play("run" if bool(unit.get("is_moving")) else "idle")

func _battle_ended(player_won: bool) -> void:
	if not bool(unit.get("is_dead")) and player_won != is_enemy: play("victory")

func get_rest_bounds() -> Rect2:
	var body: Sprite2D = parts.body
	var rect := body.get_rect()
	return Rect2(global_position + (body.position + rect.position * body.scale) * presentation_scale, rect.size * body.scale * presentation_scale)
