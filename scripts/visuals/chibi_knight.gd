extends Node2D
## Pre-rendered 3D chibi character. Atlas cells retain the generated alpha.
var body: Sprite2D
var health: ProgressBar
var mana: ProgressBar
var hero_id := 0
var skill_pattern := 0
var max_hp := 100.0
var hp := 100.0
var energy := 0.0
var enemy := false
var home := Vector2.ZERO
var height := 195.0
var age := 0.0
var alive := true
var attacking := false
var attack_modifier := 1.0
var custom_skill := ""
var combat_element := -1
var defense_rank := -1.0

func setup(id: int, atlas: Texture2D, tint: Color, size: float, rival: bool, show_bars := true) -> void:
	hero_id = id
	enemy = rival
	height = size
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	texture.region = Rect2((id % 3) * 512, (id / 3) * 512, 512, 512)
	body = Sprite2D.new()
	body.texture = texture
	body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	body.scale = Vector2.ONE * size / 512.0
	body.offset.y = -246.0
	body.flip_h = rival
	add_child(body)
	if show_bars:
		health = _bar(Vector2(-42, -size - 7), Color("d3eb63") if not rival else Color("f39b6d"), 8)
		mana = _bar(Vector2(-42, -size + 3), tint, 3)
		mana.value = 0
	queue_redraw()

func _bar(pos: Vector2, color: Color, thickness: float) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.value = 100
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("1c2227")
	bg.border_color = Color("bba172")
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(2)
	b.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(2)
	b.add_theme_stylebox_override("fill", fill)
	b.position = pos
	b.size = Vector2(84, thickness)
	add_child(b)
	return b

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.20))
	draw_circle(Vector2.ZERO, height * 0.23, Color(0.04, 0.05, 0.07, 0.42))
	draw_set_transform(Vector2.ZERO)

func _process(delta: float) -> void:
	age += delta
	if body and alive and not attacking:
		body.position = Vector2.ZERO
		body.rotation = 0.0
	if health:
		health.value = hp / max_hp * 100
		mana.value = energy

func strike(target: Vector2, ultimate := false) -> void:
	if not alive: return
	attacking = true
	var tw := create_tween()
	tw.tween_property(self, "position", home.lerp(target, 0.36 if ultimate else 0.17), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(body, "rotation", -0.16 if enemy else 0.16, 0.16)
	tw.tween_property(self, "position", home, 0.24)
	tw.parallel().tween_property(body, "rotation", 0.0, 0.24)
	tw.tween_callback(func(): attacking = false)

func receive(amount: float) -> void:
	if not alive: return
	hp = maxf(0, hp - amount)
	var tw := create_tween()
	tw.tween_property(body, "modulate", Color(2, 0.65, 0.65), 0.06)
	tw.tween_property(body, "modulate", Color.WHITE, 0.18)
	if hp <= 0:
		alive = false
		tw.tween_property(self, "modulate:a", 0.2, 0.4)
		tw.parallel().tween_property(body, "rotation", -0.4 if enemy else 0.4, 0.4)

