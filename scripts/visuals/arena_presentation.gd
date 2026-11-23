extends Node2D
## Presentation adapter: no combat data, decisions or cooldowns are mutated.
const Layout = preload("res://scripts/visuals/idle_layout.gd")
@export var background: Texture2D
var manager: Node
var elapsed := 0.0
var timer_label: Label
var allies_label: Label
var enemies_label: Label
var cards: Array[Dictionary] = []
var team_marker := 0
var backdrop: Sprite2D
var header: Control
var footer: Control
var controls: Control
var special: Button
var cinematic_label: Label
var camera: Camera2D
var screen_size := Vector2.ZERO
var cinematic_age := 0.0
var cinematic_duration := 0.6
var cinematic_active := false
var cinematic_ultimate := false
var cinematic_focus: WeakRef
var cinematic_armed := true
var hud_top := 0.0
var hud_bottom := 0.0
var player_ids: Array[String] = []
var enemy_ids: Array[String] = []
var cinematic_selected: WeakRef

func _ready() -> void:
	background = load("res://assets/backgrounds/clover_courtyard.png") if background == null else background
	var battle := get_parent()
	manager = battle.get("battle_manager")
	for layer in ["background_layer", "midground_layer", "ground_layer"]:
		var old: CanvasItem = battle.get(layer)
		if old: old.hide()
	backdrop = Sprite2D.new()
	backdrop.texture = background
	backdrop.centered = false
	backdrop.z_index = -20
	add_child(backdrop)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = false
	add_child(camera)
	var hud := CanvasLayer.new()
	hud.layer = 2
	add_child(hud)
	header = Control.new()
	header.name = "ResponsiveHeader"
	hud.add_child(header)
	footer = Control.new()
	footer.name = "ResponsiveFooter"
	hud.add_child(footer)
	var footer_back := Panel.new()
	footer_back.position = Vector2(16, -12)
	footer_back.size = Vector2(1048, 450)
	footer_back.add_theme_stylebox_override("panel", _panel(Color("11182dcc"), Color("6e665875")))
	footer.add_child(footer_back)
	var panel := Panel.new()
	panel.position = Vector2(130, 0)
	panel.size = Vector2(820, 100)
	panel.add_theme_stylebox_override("panel", _panel(Color("14223bea"), Color("d4b771")))
	header.add_child(panel)
	_label(header, "ALIADOS", Vector2(165, 6), 28, Color("eee1bc"))
	_label(header, "VS", Vector2(510, 4), 50, Color("ffd785"))
	_label(header, "INIMIGOS", Vector2(730, 6), 28, Color("eee1bc"))
	allies_label = _label(header, "", Vector2(165, 52), 21, Color("b7d7e6"))
	enemies_label = _label(header, "", Vector2(730, 52), 21, Color("e9bcb6"))
	timer_label = _label(header, "00:00", Vector2(504, 65), 22, Color("e2d4a9"))
	var stage := _label(header, "Reino Clover · Treino", Vector2(350, 108), 26, Color("fff1d0"))
	stage.add_theme_constant_override("outline_size", 6)
	cinematic_label = _label(header, "", Vector2(230, 158), 26, Color("fff1d0"))
	cinematic_label.hide()
	var ui: Node = battle.get("battle_ui")
	if ui:
		ui.get("title_label").hide()
		for key in ["auto_btn", "speed_1x_btn", "speed_2x_btn", "pause_btn", "restart_btn"]:
			var button: Button = ui.get(key)
			button.add_theme_stylebox_override("normal", _panel(Color("201c26ef"), Color("e7bd69")))
			button.add_theme_stylebox_override("hover", _panel(Color("294a4d"), Color("d9c68f")))
			button.add_theme_stylebox_override("pressed", _panel(Color("42615a"), Color("f5dc95")))
			button.add_theme_font_size_override("font_size", 27)
			button.add_theme_color_override("font_color", Color("ffe5a2"))
			button.custom_minimum_size = Vector2(155, 68)
		controls = ui.get("auto_btn").get_parent()
		controls.reparent(footer)
		controls.position = Vector2(40, 352)
		controls.add_theme_constant_override("separation", 24)
		var result: PanelContainer = ui.get("result_panel")
		result.add_theme_stylebox_override("panel", _panel(Color("102733"), Color("c7b378")))
		var restart: Button = ui.get("restart_btn")
		var legacy := Callable(ui, "_on_restart")
		if restart.pressed.is_connected(legacy): restart.pressed.disconnect(legacy)
		restart.pressed.connect(_restart_current_teams)
	special = Button.new()
	special.name = "SpecialFocus"
	special.text = "✦"
	special.position = Vector2(900, 344)
	special.size = Vector2(125, 84)
	special.add_theme_font_size_override("font_size", 42)
	special.add_theme_color_override("font_color", Color("ffe9a0"))
	special.add_theme_stylebox_override("normal", _panel(Color("442753ef"), Color("e7bd69")))
	special.tooltip_text = "Realçar o próximo especial automático. Não antecipa nem modifica a habilidade."
	special.pressed.connect(_arm_special)
	footer.add_child(special)
	for i in range(manager.get("player_team").size()):
		_create_card(manager.get("player_team")[i], i)
	_update_layout()

func _create_card(unit: Node, index: int) -> void:
	var card := Panel.new()
	card.position = Vector2(44 + index * 200, 0)
	card.size = Vector2(184, 300)
	card.clip_contents = true
	var id := str(unit.get("hero_id")).trim_prefix("bc_")
	var accents := {"asta": Color("6a1926"), "yuno": Color("164b37"), "noelle": Color("244c77"), "yami": Color("3d245e"), "magna": Color("78371c")}
	card.add_theme_stylebox_override("panel", _panel(accents.get(id, Color("172139")), Color("e5b85b")))
	footer.add_child(card)
	var portrait := Control.new()
	portrait.position = Vector2(5, 5)
	portrait.size = Vector2(174, 220)
	portrait.clip_contents = true
	card.add_child(portrait)
	var source: Texture2D = load("res://assets/heroes/painted/%s.png" % id)
	var crops := {"asta": Rect2(0.12, 0, 0.43, 0.42), "yuno": Rect2(0.31, 0, 0.45, 0.42), "noelle": Rect2(0.26, 0, 0.43, 0.42), "yami": Rect2(0.16, 0, 0.46, 0.42), "magna": Rect2(0.35, 0, 0.46, 0.42)}
	var region: Rect2 = crops.get(id, Rect2(0.2, 0, 0.5, 0.45))
	var pixels := Rect2(region.position * source.get_size(), region.size * source.get_size())
	var face := Sprite2D.new()
	face.texture = source
	face.centered = false
	var zoom := maxf(174.0 / pixels.size.x, 220.0 / pixels.size.y)
	face.scale = Vector2.ONE * zoom
	face.position = Vector2(87, 110) - pixels.get_center() * zoom
	portrait.add_child(face)
	var caption := Panel.new()
	caption.position = Vector2(4, 218)
	caption.size = Vector2(176, 78)
	caption.add_theme_stylebox_override("panel", _panel(Color("17151cf2"), Color.TRANSPARENT))
	card.add_child(caption)
	var ornament := TextureRect.new()
	ornament.texture = load("res://assets/ui/hero_card_gold.svg")
	ornament.size = card.size
	ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(ornament)
	_label(card, unit.get("data").get("name", ""), Vector2(16, 221), 27, Color("fff3d1"))
	_label(card, "✦ ✦ ✦ ✦ ✦", Vector2(12, 263), 20, Color("ffd46d"))
	# TextureProgress/ProgressBar impose theme minimum heights. These two simple
	# controls have exact geometry and read the combat's actual HP/energy ratios.
	var hp := _bar(footer, card.position + Vector2(6, 306), Vector2(172, 10), Color("80d7ac"))
	var energy := _bar(footer, card.position + Vector2(6, 322), Vector2(172, 6), Color("41c7f8"))
	cards.append({"unit": weakref(unit), "hp": hp, "energy": energy, "portrait": portrait})

func _bar(host: Node, point: Vector2, extent: Vector2, color: Color) -> ColorRect:
	var track := ColorRect.new()
	track.color = Color("0b1823")
	track.position = point
	track.size = extent
	host.add_child(track)
	var fill := ColorRect.new()
	fill.color = color
	fill.size = extent
	fill.set_meta("full_width", extent.x)
	track.add_child(fill)
	return fill

func _arm_special() -> void:
	cinematic_armed = true
	special.text = "✦"
	special.modulate = Color("ffe6b0")
	var ready: Node = null
	for actor in manager.get("player_team"):
		if is_instance_valid(actor) and not actor.get("is_dead"):
			if ready == null or actor.get("current_energy") > ready.get("current_energy"): ready = actor
	if ready:
		cinematic_selected = weakref(ready.get("visual"))
		cinematic_label.text = "Próximo especial: " + ready.get("data").get("name", "")
		cinematic_label.modulate = Color("ffe6b0")
		cinematic_label.show()

func _restart_current_teams() -> void:
	# Reuse the displayed teams rather than the legacy UI's obsolete hero IDs.
	var ui: Node = get_parent().get("battle_ui")
	ui.get("result_panel").hide()
	manager.reset()
	manager.start_battle(player_ids, enemy_ids)
	ui.get("pause_btn").text = "||"

func _update_layout() -> void:
	screen_size = get_viewport_rect().size
	var ui_scale := Layout.ui_scale(screen_size)
	var safe := Layout.safe_margins(get_viewport())
	var fit := maxf(screen_size.x / background.get_width(), screen_size.y / background.get_height())
	backdrop.scale = Vector2.ONE * fit
	backdrop.position = (screen_size - background.get_size() * fit) * 0.5
	header.scale = Vector2.ONE * ui_scale
	header.position = Vector2((screen_size.x - 1080 * ui_scale) * 0.5, safe.x)
	footer.scale = Vector2.ONE * ui_scale
	footer.position = Vector2((screen_size.x - 1080 * ui_scale) * 0.5, screen_size.y - safe.y - 432 * ui_scale)
	hud_top = header.position.y + 150 * ui_scale
	hud_bottom = footer.position.y
	var ui: Node = get_parent().get("battle_ui")
	if ui:
		var result: Control = ui.get("result_panel")
		result.scale = Vector2.ONE * ui_scale
		result.position = Vector2((screen_size.x - 700 * ui_scale) * 0.5, hud_top + 30 * ui_scale)
	camera.position = screen_size * 0.5
	camera.zoom = Vector2.ONE

func set_background(texture: Texture2D) -> void:
	background = texture
	backdrop.texture = texture
	_update_layout()

func highlight_skill(actor: Node2D, ultimate: bool = false) -> void:
	# Triggered by the existing skill event; this never casts or spends energy.
	if cinematic_active or not cinematic_armed: return
	if cinematic_selected and is_instance_valid(cinematic_selected.get_ref()) and cinematic_selected.get_ref() != actor: return
	cinematic_selected = null
	cinematic_active = true
	cinematic_ultimate = ultimate
	cinematic_age = 0
	cinematic_duration = 0.8 if ultimate else 0.5
	cinematic_focus = weakref(actor)
	cinematic_label.text = ("%s · " % actor.unit.get("data").get("name", "")) + actor.skill_label.text
	cinematic_label.modulate = actor.element_color.lightened(0.5)
	cinematic_label.show()
	special.modulate = Color.WHITE

func _panel(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0.03, 0.02, 0.04, 0.5)
	style.shadow_size = 4
	style.set_content_margin_all(0)
	return style

func _label(host: Node, text: String, point: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = point
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("111827"))
	label.add_theme_constant_override("outline_size", 2)
	host.add_child(label)
	return label

func _process(delta: float) -> void:
	if not is_instance_valid(manager): return
	if screen_size != get_viewport_rect().size: _update_layout()
	var running := int(manager.get("state")) == 1
	var speed: float = float(manager.get("speed_multiplier")) if running else 0
	if running: elapsed += delta * speed
	var team: Array = manager.get("player_team")
	if not team.is_empty() and is_instance_valid(team[0]) and team[0].get_instance_id() != team_marker:
		team_marker = team[0].get_instance_id()
		player_ids.clear()
		enemy_ids.clear()
		for actor in team:
			if is_instance_valid(actor): player_ids.append(actor.get("hero_id"))
		for actor in manager.get("enemy_team"):
			if is_instance_valid(actor): enemy_ids.append(actor.get("hero_id"))
		elapsed = 0
		cinematic_active = false
		cinematic_selected = null
		cinematic_label.hide()
	timer_label.text = "%02d:%02d" % [int(elapsed) / 60, int(elapsed) % 60]
	allies_label.text = "%d / 5" % _alive(team)
	enemies_label.text = "%d / 5" % _alive(manager.get("enemy_team"))
	for i in range(cards.size()):
		var entry := cards[i]
		var actor: Node = team[i] if i < team.size() and is_instance_valid(team[i]) else null
		entry.unit = weakref(actor) if actor else null
		var ratio := float(actor.get("current_hp")) / maxf(float(actor.get("max_hp")), 1) if actor else 0.0
		entry.hp.size.x = entry.hp.get_meta("full_width") * clampf(ratio, 0, 1)
		entry.energy.size.x = entry.energy.get_meta("full_width") * (clampf(float(actor.get("current_energy")) / maxf(float(actor.get("max_energy")), 1), 0, 1) if actor else 0.0)
		entry.portrait.modulate = Color.WHITE if ratio > 0 else Color("50616b")
	if cinematic_active:
		cinematic_age += delta * speed
		var t := clampf(cinematic_age / cinematic_duration, 0, 1)
		var pulse := sin(t * PI)
		var actor: Node2D = cinematic_focus.get_ref()
		camera.zoom = Vector2.ONE * (1 + pulse * (0.045 if cinematic_ultimate else 0.025))
		camera.position = screen_size * 0.5
		if is_instance_valid(actor):
			camera.position += (actor.global_position - screen_size * 0.5) * pulse * 0.015
		if t >= 1 or not running and int(manager.get("state")) == 3:
			cinematic_active = false
			cinematic_label.hide()
			camera.zoom = Vector2.ONE
			camera.position = screen_size * 0.5
	else:
		camera.zoom = Vector2.ONE
		camera.position = screen_size * 0.5

func _alive(team: Array) -> int:
	var count := 0
	for actor in team:
		if is_instance_valid(actor) and not bool(actor.get("is_dead")): count += 1
	return count
