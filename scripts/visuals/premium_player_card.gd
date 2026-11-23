extends Control
## Generated frame with live profile data; no player information is baked in.
signal pressed
const CIRCLE = preload("res://shaders/avatar_circle.gdshader")
var avatar: TextureRect
var name_label: Label
var level_label: Label
var vip_label: Label
var experience: ProgressBar

func setup(frame: Texture2D, portrait: Texture2D, player_name: String, level: int, vip: int, progress: float, title: Font, body: Font) -> void:
	size = Vector2(300, 110)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := TextureRect.new()
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.texture = frame
	background.size = size
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	avatar = TextureRect.new()
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_SCALE
	avatar.texture = portrait
	avatar.position = Vector2(13, 16)
	avatar.size = Vector2(76, 76)
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = CIRCLE
	mat.set_shader_parameter("box_size", avatar.size)
	avatar.material = mat
	add_child(avatar)
	name_label = _label(player_name, Rect2(97, 23, 177, 26), title, 18 if player_name.length() < 14 else 15, Color("fff0cb"))
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	level_label = _label("Nv. %d" % level, Rect2(101, 60, 80, 21), body, 14, Color("fff0cb"))
	vip_label = _label("VIP %d" % vip, Rect2(194, 60, 79, 21), title, 14, Color("ffdd88"))
	experience = ProgressBar.new()
	experience.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("f3c65d")
	fill.set_corner_radius_all(2)
	experience.add_theme_stylebox_override("fill", fill)
	experience.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	experience.position = Vector2(97, 87)
	experience.size = Vector2(170, 4)
	experience.value = clampf(progress, 0, 100)
	experience.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(experience)
	var hit := Button.new()
	hit.size = size
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.tooltip_text = "%s · Nível do jogador %d · VIP %d\nToque para editar o perfil e trocar o avatar." % [player_name, level, vip]
	for state in ["normal", "hover", "pressed", "focus"]:
		hit.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	hit.pressed.connect(func(): pressed.emit())
	add_child(hit)

func _label(value: String, rect: Rect2, font: Font, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color("160d20"))
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label
