extends Button
## Code-native ornamental frames; generated icon textures remain separate.
enum Shape { PLAQUE, SHIELD, CIRCLE }
@export var shape := Shape.PLAQUE
@export var base_color := Color("211b2c")
@export var active := false
var glow := 0.0
static var plaque_texture: Texture2D

func _has_point(point: Vector2) -> bool:
	# Minimum 44px target at a 360px-wide phone, without enlarging the artwork.
	var target := Vector2(maxf(size.x, 88), maxf(size.y, 88))
	return Rect2((size - target) * 0.5, target).has_point(point)

func _ready() -> void:
	if plaque_texture == null:
		plaque_texture = load("res://assets/home/text-plaque.png")
	text = ""
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	mouse_entered.connect(func(): glow = 1; queue_redraw())
	mouse_exited.connect(func(): glow = 0; queue_redraw())
	focus_entered.connect(func(): glow = 1; queue_redraw())
	focus_exited.connect(func(): glow = 0; queue_redraw())
	resized.connect(queue_redraw)

func _outline(points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, color, width, true)

func _draw() -> void:
	var gold := Color("ffd77e")
	var bronze := Color("9a582b")
	var light := glow > 0 or active
	var c := base_color.lightened(0.16 if light else 0.0)
	if shape == Shape.PLAQUE and plaque_texture:
		# Exclude the generator's transparent canvas margins, keep the source intact.
		draw_texture_rect_region(plaque_texture, Rect2(Vector2.ZERO, size), Rect2(24, 174, 2124, 370), Color(1.17, 1.12, 1.04) if light else Color.WHITE)
		if light:
			draw_line(Vector2(23, 5), Vector2(size.x - 23, 5), Color(1, 0.82, 0.4, 0.65), 2, true)
		return
	if shape == Shape.CIRCLE:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.48
		if light: draw_circle(center, radius + 3, Color(1, 0.68, 0.13, 0.22))
		draw_circle(center + Vector2(0, 3), radius, Color(0.04, 0.03, 0.08, 0.6))
		draw_circle(center, radius, bronze)
		draw_circle(center, radius - 2, gold)
		draw_circle(center, radius - 4, c)
		draw_arc(center, radius - 7, PI, TAU, 36, Color("ffe9b4"), 1.4, true)
		return
	var w := size.x
	var h := size.y
	var points: PackedVector2Array
	if shape == Shape.SHIELD:
		points = PackedVector2Array([Vector2(w * 0.5, 1), Vector2(w - 12, 10), Vector2(w - 2, h * 0.38), Vector2(w - 10, h - 13), Vector2(w * 0.5, h - 1), Vector2(10, h - 13), Vector2(2, h * 0.38), Vector2(12, 10)])
	else:
		points = PackedVector2Array([Vector2(16, 3), Vector2(w - 16, 3), Vector2(w - 2, h * 0.5), Vector2(w - 16, h - 3), Vector2(16, h - 3), Vector2(2, h * 0.5)])
	if light: _outline(points, Color(1, 0.63, 0.1, 0.25), 12)
	draw_colored_polygon(points, c)
	_outline(points, Color("59331f"), 7)
	_outline(points, gold, 3)
	var inner := PackedVector2Array()
	for p in points: inner.append(size * 0.5 + (p - size * 0.5) * 0.92)
	_outline(inner, bronze, 1)
	draw_line(Vector2(21, 7), Vector2(w - 21, 7), Color("fff0b7"), 1.2, true)
	for x in [17.0, w - 17]:
		var y := 5.0 if shape == Shape.PLAQUE else 13.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, y - 4), Vector2(x + 3, y), Vector2(x, y + 4), Vector2(x - 3, y)]), Color("fff0b7"))
