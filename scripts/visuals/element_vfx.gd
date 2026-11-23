extends Node2D
## Self-contained elemental cast, slash and impact. No damage or target selection.
var tint := Color.WHITE
var kind := "impact"
var element := "asta"
var age := 0.0
var duration := 0.55
var direction := 1.0
var speed_source: WeakRef
var damage_value := ""

static func spawn(host: Node, point: Vector2, hero: String, color: Color, effect: String, facing: float, source: Node) -> Node2D:
	var fx := load("res://scripts/visuals/element_vfx.gd").new() as Node2D
	fx.tint = color
	fx.kind = effect
	fx.element = hero
	fx.direction = facing
	fx.duration = 0.75 if effect == "cast" else 0.48
	fx.speed_source = weakref(source)
	host.add_child(fx)
	fx.global_position = point
	fx.z_index = 3000
	return fx

func _process(delta: float) -> void:
	var source: Node = speed_source.get_ref() if speed_source else null
	var speed: float = float(source.get("battle_speed")) if is_instance_valid(source) else 1.0
	age += delta * speed
	if age >= duration:
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	var t := clampf(age / duration, 0.0, 1.0)
	if kind == "number":
		var point := Vector2(-20, -t * 45)
		draw_string_outline(ThemeDB.fallback_font, point, damage_value, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, 6, Color(0.05, 0.04, 0.1, 1.0 - t))
		draw_string(ThemeDB.fallback_font, point, damage_value, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(1.0, 0.92, 0.69, 1.0 - t))
		return
	var fade := sin(PI * t)
	var radius := lerpf(15.0, 112.0 if kind in ["cast", "slash"] else 72.0, t)
	var glow := Color(tint, fade * 0.15)
	if kind == "cast":
		draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.38))
		draw_arc(Vector2.ZERO, radius, -PI, PI, 64, Color(tint, fade * 0.7), 2.0, true)
		draw_arc(Vector2.ZERO, radius * 0.78, t * TAU, t * TAU + PI * 1.6, 48, Color(tint, fade), 3.0, true)
		for i in range(8):
			var p := Vector2.from_angle(i * TAU / 8.0 + t) * radius
			draw_line(p * 0.9, p * 1.07, Color(tint, fade), 3, true)
		draw_set_transform(Vector2.ZERO)
	elif kind == "slash":
		draw_set_transform(Vector2.ZERO, -0.55 * direction, Vector2(direction, 0.55))
		for i in range(4):
			var r := radius + i * 3
			draw_arc(Vector2(-15, 0), r, -1.5 + t, 1.0 + t, 32, Color(tint, fade * (1.0 - i * 0.2)), 8.0 - i * 1.7, true)
		draw_set_transform(Vector2.ZERO)
	else:
		draw_circle(Vector2.ZERO, radius * 0.75, glow)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color(tint, (1.0 - t) * 0.7), 3.0 * (1.0 - t), true)
	for i in range(12):
		var angle := i * 2.39996
		var p := Vector2.from_angle(angle) * radius * (0.5 + float(i % 3) * 0.3)
		var c := Color(tint.lightened(0.35), fade * 0.85)
		if element == "luck":
			var points := PackedVector2Array([p * 0.2, p * 0.6 + Vector2(9, -7), p * 0.5, p])
			draw_polyline(points, c, 2.5, true)
		elif element in ["asta", "yami"]:
			draw_line(p * 0.55, p, c, 2.5, true)
		elif element == "yuno":
			draw_arc(p, 9.0 + t * 8, angle, angle + PI, 12, c, 1.7, true)
		elif element == "noelle":
			draw_circle(p, 2.0 + (1.0 - t) * 3.0, c, false, 1.5, true)
		else:
			draw_colored_polygon(PackedVector2Array([p + Vector2(-3, 4), p + Vector2(0, -10), p + Vector2(4, 4)]), c)
