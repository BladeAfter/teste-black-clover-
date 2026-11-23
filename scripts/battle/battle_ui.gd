extends CanvasLayer

# BattleState enum values matching battle_manager.gd
const STATE_IDLE = 0
const STATE_RUNNING = 1
const STATE_PAUSED = 2
const STATE_ENDED = 3

var battle_manager = null

# Control references
var auto_btn: Button
var speed_1x_btn: Button
var speed_2x_btn: Button
var pause_btn: Button
var result_panel: PanelContainer
var result_label: Label
var restart_btn: Button
var title_label: Label

func setup(manager) -> void:
	battle_manager = manager
	_create_ui()
	if battle_manager:
		battle_manager.battle_ended.connect(_on_battle_ended)

func _create_ui() -> void:
	# Dark fantasy color palette
	var bg_dark := Color(0.08, 0.06, 0.12, 0.95)
	var accent_gold := Color(0.9, 0.75, 0.3)
	var btn_normal := Color(0.15, 0.12, 0.22)
	var btn_hover := Color(0.25, 0.2, 0.35)
	var btn_pressed := Color(0.35, 0.28, 0.45)

	# Title bar
	title_label = Label.new()
	title_label.text = "BATALHA"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.position = Vector2(0, 40)
	title_label.custom_minimum_size = Vector2(1080, 50)
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", accent_gold)
	add_child(title_label)

	# Bottom control bar container
	var control_bar := HBoxContainer.new()
	control_bar.position = Vector2(140, 1780)
	control_bar.custom_minimum_size = Vector2(800, 80)
	control_bar.add_theme_constant_override("separation", 20)
	add_child(control_bar)

	# Create buttons
	auto_btn = _make_button("AUTO", btn_normal, btn_hover, btn_pressed, accent_gold)
	auto_btn.pressed.connect(_on_auto_pressed)
	control_bar.add_child(auto_btn)

	speed_1x_btn = _make_button("1x", btn_normal, btn_hover, btn_pressed, accent_gold)
	speed_1x_btn.pressed.connect(_on_speed_1x)
	control_bar.add_child(speed_1x_btn)

	speed_2x_btn = _make_button("2x", btn_normal, btn_hover, btn_pressed, accent_gold)
	speed_2x_btn.pressed.connect(_on_speed_2x)
	control_bar.add_child(speed_2x_btn)

	pause_btn = _make_button("||", btn_normal, btn_hover, btn_pressed, accent_gold)
	pause_btn.pressed.connect(_on_pause)
	control_bar.add_child(pause_btn)

	# Result panel (hidden initially)
	result_panel = PanelContainer.new()
	result_panel.position = Vector2(190, 800)
	result_panel.custom_minimum_size = Vector2(700, 300)
	result_panel.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = bg_dark
	style.border_color = accent_gold
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(30)
	result_panel.add_theme_stylebox_override("panel", style)
	add_child(result_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 30)
	result_panel.add_child(vbox)

	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 48)
	result_label.add_theme_color_override("font_color", accent_gold)
	vbox.add_child(result_label)

	restart_btn = _make_button("REINICIAR", btn_normal, btn_hover, btn_pressed, accent_gold)
	restart_btn.custom_minimum_size = Vector2(300, 60)
	restart_btn.pressed.connect(_on_restart)
	vbox.add_child(restart_btn)

func _make_button(text: String, normal: Color, hover: Color, pressed: Color, font_color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(140, 70)
	btn.add_theme_font_size_override("font_size", 28)
	btn.add_theme_color_override("font_color", font_color)

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = normal
	normal_style.set_corner_radius_all(8)
	normal_style.set_border_width_all(2)
	normal_style.border_color = font_color
	btn.add_theme_stylebox_override("normal", normal_style)

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = hover
	hover_style.set_corner_radius_all(8)
	hover_style.set_border_width_all(2)
	hover_style.border_color = font_color
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = pressed
	pressed_style.set_corner_radius_all(8)
	pressed_style.set_border_width_all(2)
	pressed_style.border_color = font_color
	btn.add_theme_stylebox_override("pressed", pressed_style)

	return btn

func _on_auto_pressed() -> void:
	if not battle_manager:
		return
	battle_manager.auto_mode = not battle_manager.auto_mode
	auto_btn.text = "AUTO" if battle_manager.auto_mode else "MANUAL"

func _on_speed_1x() -> void:
	if not battle_manager:
		return
	battle_manager.set_speed(1.0)

func _on_speed_2x() -> void:
	if not battle_manager:
		return
	battle_manager.set_speed(2.0)

func _on_pause() -> void:
	if not battle_manager:
		return
	battle_manager.toggle_pause()
	pause_btn.text = "▶" if battle_manager.state == STATE_PAUSED else "||"

func _on_battle_ended(player_won: bool) -> void:
	result_panel.visible = true
	if player_won:
		result_label.text = "VITÓRIA!"
		result_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
	else:
		result_label.text = "DERROTA"
		result_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))

func _on_restart() -> void:
	result_panel.visible = false
	if battle_manager:
		battle_manager.reset()
		# Restart with same teams (placeholder IDs)
		var player_ids: Array[String] = ["asta", "yuno", "noelle", "yami", "magna"]
		var enemy_ids: Array[String] = ["luck", "magna", "yami", "noelle", "yuno"]
		battle_manager.start_battle(player_ids, enemy_ids)
		pause_btn.text = "||"