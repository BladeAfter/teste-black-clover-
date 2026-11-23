extends Node2D
## Portrait entry point. Reuses the existing save, roster and combat engine.
const Game = preload("res://scripts/clover_idle.gd")
const Frame = preload("res://scripts/visuals/premium_button.gd")
const PlayerCard = preload("res://scripts/visuals/premium_player_card.gd")
const ActivityScreens = preload("res://scripts/activities/activity_screens.gd")
const GOLD := Color("ffdc8c")
const WHITE := Color("fff3da")
const MUTED := Color("c7bdd0")
class DockTab extends Button:
	func _has_point(point: Vector2) -> bool:
		return Rect2(Vector2(0, -8), Vector2(size.x, size.y + 16)).has_point(point)

var game: Node2D
var game_save_path := "user://clover_idle_v2.json"
var home_save_path := "user://clover_home.json"
var state: Dictionary = {"name": "Cavaleiro", "avatar": 0, "vip": 0, "welcome": false, "checkin": "", "missions": [], "achievements": []}
var ui: Control
var screen: Control
var hud: Control
var navigation: Control
var popup_layer: Control
var popup: Control
var background: TextureRect
var title_font: Font
var body_font: Font
var current_page := "Início"
var wallet_labels: Array[Label] = []
var power_label: Label
var nav_buttons: Array = []
var selected := 0
var selected_slot := 0
var update_clock := 0.0
var auto_battle := false
var home_background: Texture2D
var summon_revealing := false
var transition: Tween
var menu_art: Texture2D
var resource_art: Texture2D
var art_cache: Dictionary = {}
var landscape_mode := false
var battle_view := false
var web_back_callback: JavaScriptObject
var web_layout_callback: JavaScriptObject
var player_card_texture: Texture2D
var player_card: Control
var avatar_cache: Dictionary = {}
var layout_settle_frames := 0
var content_offset := Vector2.ZERO
var activities: RefCounted
var roster = preload("res://scripts/activities/roster_browser.gd").new(self)
var avatar_page := 0
var active_activity := "Campanha"

func _ready() -> void:
	get_tree().quit_on_go_back = false
	RenderingServer.set_default_clear_color(Color("171020"))
	game = Game.new()
	game.external_presentation = true
	game.save_path = game_save_path
	add_child(game)
	game.battle_resolved.connect(_battle_result)
	menu_art = load("res://assets/home/icons-atlas.png")
	resource_art = load("res://assets/home/resources-atlas.png")
	player_card_texture = load("res://assets/home/player-card.png")
	home_background = load("res://assets/home/kingdom-portrait.png")
	title_font = game.title_font
	body_font = game.body_font
	activities = ActivityScreens.new(self)
	_load_home()
	ui = Control.new()
	ui.name = "HomeScene"
	add_child(ui)
	var theme := Theme.new()
	theme.default_font = body_font
	theme.default_font_size = 20
	ui.theme = theme
	# Fill the entire viewport independently of the safe, rotated UI rectangle.
	background = _image(home_background, Rect2(0, 0, 720, 1280), self)
	background.z_index = -100
	ui.clip_contents = true
	screen = Control.new()
	screen.name = "InteractiveLocations"
	ui.add_child(screen)
	hud = Control.new()
	hud.name = "TopPlayerHUD"
	ui.add_child(hud)
	navigation = Control.new()
	navigation.name = "BottomNavigation"
	ui.add_child(navigation)
	popup_layer = Control.new()
	popup_layer.name = "Dialogs"
	popup_layer.z_index = 2000
	popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(popup_layer)
	get_viewport().size_changed.connect(_queue_resize)
	if not OS.has_feature("mobile") and not OS.has_feature("web") and DisplayServer.get_name() != "headless" and not "--script" in OS.get_cmdline_args():
		_fit_desktop_window()
	_resize()
	_route("Início")
	if OS.has_feature("web"):
		web_back_callback = JavaScriptBridge.create_callback(_web_back)
		web_layout_callback = JavaScriptBridge.create_callback(_web_resize)
		var platform = JavaScriptBridge.get_interface("CloverPlatform")
		if platform:
			platform.setBackHandler(web_back_callback)
			platform.setInsetsHandler(web_layout_callback)

func _desktop_size(usable: Vector2i, decorations: Vector2i) -> Vector2i:
	var available := Vector2(maxi(180, usable.x - decorations.x - 32), maxi(320, usable.y - decorations.y - 40))
	var height := minf(960, minf(available.y, available.x * 16.0 / 9.0))
	return Vector2i(int(height * 9.0 / 16.0), int(height))

func _fit_desktop_window() -> void:
	var window := get_window()
	var usable := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var decorations := DisplayServer.window_get_size_with_decorations() - DisplayServer.window_get_size()
	var target := _desktop_size(usable.size, decorations)
	if landscape_mode:
		var width := minf(1280, minf(usable.size.x - decorations.x - 40, (usable.size.y - decorations.y - 40) * 16.0 / 9.0))
		target = Vector2i(int(width), int(width * 9.0 / 16.0))
	window.size = target
	window.position = usable.position + (usable.size - target) / 2

func _resize() -> void:
	if not is_instance_valid(ui): return
	var view := get_viewport_rect().size
	var available := view
	var origin := Vector2.ZERO
	if OS.has_feature("web"):
		var data = JavaScriptBridge.eval("JSON.stringify(window.CloverPlatform ? window.CloverPlatform.getInsets() : [0,0,0,0])", true)
		var insets = JSON.parse_string(str(data))
		if insets is Array and insets.size() == 4:
			origin = Vector2(float(insets[0]) * view.x, float(insets[1]) * view.y)
			available -= origin + Vector2(float(insets[2]) * view.x, float(insets[3]) * view.y)
	elif OS.has_feature("mobile"):
		var physical := Vector2(DisplayServer.screen_get_size())
		var safe := DisplayServer.get_display_safe_area()
		if physical.x > 0 and physical.y > 0 and safe.has_area():
			origin = Vector2(safe.position) * view / physical
			available = Vector2(safe.size) * view / physical
	var design := Vector2(1280, 720) if landscape_mode else Vector2(720, 1280)
	var rotate := landscape_mode and (OS.has_feature("web") or OS.has_feature("mobile")) and view.y > view.x
	var displayed := Vector2(design.y, design.x) if rotate else design
	var fit := minf(available.x / displayed.x, available.y / displayed.y)
	ui.scale = Vector2.ONE * fit
	ui.rotation = PI * 0.5 if rotate else 0.0
	var visible_design := available / fit
	ui.size = Vector2(visible_design.y, visible_design.x) if rotate else visible_design
	content_offset = (ui.size - design) * 0.5
	ui.position = origin
	if rotate: ui.position.x += available.x
	screen.position = content_offset
	popup_layer.position = content_offset
	hud.position = content_offset if landscape_mode else Vector2(content_offset.x, 0)
	navigation.position = Vector2(content_offset.x, ui.size.y - design.y)
	background.position = Vector2.ZERO
	background.size = view
	background.texture = activities.background_for(active_activity) if landscape_mode else home_background
	background.modulate = Color(0.3, 0.28, 0.36) if landscape_mode else Color.WHITE
	if OS.has_feature("web"):
		var metrics := {"width": view.x, "height": view.y, "x": ui.position.x, "y": ui.position.y, "scale": fit, "rotated": rotate, "content_x": content_offset.x, "content_y": content_offset.y, "design_width": ui.size.x, "design_height": ui.size.y}
		metrics["page"] = current_page
		var final := get_viewport().get_final_transform()
		metrics["final"] = [final.x.x, final.x.y, final.y.x, final.y.y, final.origin.x, final.origin.y]
		metrics["window"] = [get_window().size.x, get_window().size.y]
		JavaScriptBridge.eval("if(window.CloverPlatform) window.CloverPlatform.layout = %s" % JSON.stringify(metrics), true)

func _queue_resize() -> void:
	layout_settle_frames = 3
	call_deferred("_resize")

func _web_resize(_args: Array) -> void:
	_resize()
	_queue_resize()

func _set_orientation(horizontal: bool) -> void:
	var changed := landscape_mode != horizontal
	if changed:
		ui.hide()
		layout_settle_frames = 3
	landscape_mode = horizontal
	get_window().content_scale_size = Vector2i(1280, 720) if horizontal else Vector2i(720, 1280)
	if OS.has_feature("mobile") and not OS.has_feature("web"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE if horizontal else DisplayServer.SCREEN_SENSOR_PORTRAIT)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.CloverPlatform && window.CloverPlatform.setLandscape(%s)" % ("true" if horizontal else "false"), true)
	elif changed and DisplayServer.get_name() != "headless" and not OS.has_feature("mobile") and not "--script" in OS.get_cmdline_args():
		_fit_desktop_window()
	_resize()
	_queue_resize()

func _web_back(_args: Array) -> void:
	if game.fighting:
		game.fighting = false
		auto_battle = false
	_route("Início")

func _image(texture: Texture2D, rect: Rect2, parent: Node) -> TextureRect:
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.texture = texture
	t.position = rect.position
	t.size = rect.size
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)
	return t

func _text(value: String, rect: Rect2, parent: Node, font_size := 22, color := WHITE, fancy := false, centered := false) -> Label:
	var l := Label.new()
	l.text = value
	l.position = rect.position
	l.size = rect.size
	l.add_theme_font_override("font", title_font if fancy else body_font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color("100a1e"))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if centered: l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l

func _art(id: int, rect: Rect2, parent: Node) -> TextureRect:
	if not art_cache.has(id):
		var source := menu_art if id < 16 else resource_art
		var columns := 4 if id < 16 else 2
		var index := id if id < 16 else id - 16
		var cell := source.get_width() / float(columns)
		var texture := AtlasTexture.new()
		texture.atlas = source
		texture.region = Rect2((index % columns) * cell, (index / columns) * cell, cell, cell)
		art_cache[id] = texture
	var art := _image(art_cache[id], rect, parent)
	art.name = "GeneratedArt%d" % id
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return art

func _avatar_texture(id: int) -> Texture2D:
	if id >= 6:
		if not avatar_cache.has(id):
			var full: Texture2D = game.hero_catalog.texture(id,game.atlas)
			var face := AtlasTexture.new()
			face.atlas = full
			var size := full.get_size()
			face.region = Rect2(size*Vector2(0.18,0.02),size*Vector2(0.64,0.64))
			avatar_cache[id]=face
		return avatar_cache[id]
	if not avatar_cache.has(id):
		# Center the complete head silhouette, rather than the full battle sprite.
		var regions := [Rect2(135, 0, 300, 300), Rect2(605, 0, 300, 300), Rect2(1110, 0, 330, 330), Rect2(135, 512, 270, 270), Rect2(650, 512, 290, 290), Rect2(1135, 512, 310, 310)]
		var texture := AtlasTexture.new()
		texture.atlas = game.atlas
		texture.region = regions[clampi(id, 0, 5)]
		avatar_cache[id] = texture
	return avatar_cache[id]

func _create_player_card(parent: Node, position: Vector2, factor := 1.0) -> Control:
	var card = PlayerCard.new()
	card.name = "PlayerCard"
	card.position = position
	card.scale = Vector2.ONE * factor
	parent.add_child(card)
	card.setup(player_card_texture, _avatar_texture(int(state.avatar)), str(state.name), game.get_player_level(), int(state.vip), game.get_player_progress(), title_font, body_font)
	card.pressed.connect(_profile)
	return card

func _frame(rect: Rect2, parent: Node, action: Callable, kind := 0, active := false, color := Color("21192d")) -> Button:
	var b := Frame.new()
	b.position = rect.position
	b.size = rect.size
	b.shape = kind
	b.active = active
	b.base_color = color
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func _plate(title: String, rect: Rect2, parent: Node, action: Callable, active := false, font_size := 22, color := Color("21192d")) -> Button:
	var b := _frame(rect, parent, action, 0, active, color)
	_text(title, Rect2(12, (rect.size.y - font_size - 9) * 0.5, rect.size.x - 24, font_size + 12), b, font_size, WHITE, true, true)
	return b

func _panel(rect: Rect2, parent: Node, color := Color(0.12, 0.08, 0.19, 0.96)) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("bc8b47")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 8
	p.add_theme_stylebox_override("panel", style)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p

func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _route(page: String, combat_view := false) -> void:
	if game.fighting:
		_notice("Batalha em andamento", "Conclua a batalha ou toque em Recuar para voltar ao reino.")
		return
	_close()
	battle_view = combat_view
	current_page = page
	if page != "Campanha":
		active_activity = "Campanha"
		game.battle_kind = "campaign"
	_set_orientation(page in ["Campanha", "Forma\u00e7\u00e3o"])
	_clear(screen)
	_clear(hud)
	_clear(navigation)
	wallet_labels.clear()
	nav_buttons.clear()
	game.actors.clear()
	game.allies.clear()
	game.foes.clear()
	game.field = null
	game.effects = null
	if landscape_mode:
		hud.visible = not battle_view
		if not battle_view: _build_landscape_hud()
		if page == "Campanha": _campaign()
		else: _formation_landscape()
	else:
		hud.show()
		_build_hud()
		_build_nav()
	if page == "Início": _home()
	elif landscape_mode: pass
	else:
		_panel(Rect2(14, 166, 692, 968), screen)
		activities.backdrop(page)
		_plate("Reino", Rect2(28, 180, 142, 43), screen, func(): _route("Início"), false, 19)
		_text(page, Rect2(185, 180, 485, 43), screen, 28, GOLD, true, true)
		match page:
			"Heróis": _heroes()
			"Bag": _bag()
			"Formação": _formation()
			"Invocação": _summoning()
			"Missões", "Conquistas": _missions()
			"Loja", "Mercado": _shop()
			"Fusão": _fusion()
			_:
				if not activities.render(page): _unavailable(page)
	if is_instance_valid(transition): transition.kill()
	screen.modulate.a = 0
	transition = create_tween()
	transition.tween_property(screen, "modulate:a", 1.0, 0.14)

func _build_hud() -> void:
	# Compact player profile on the left, three resource bars on the right.
	player_card = _create_player_card(hud, Vector2(8, 8))
	_art(15, Rect2(30, 120, 24, 24), hud)
	power_label = _text("", Rect2(63, 119, 220, 27), hud, 21, GOLD, true)
	for i in range(3):
		var x := 310 + i * 133
		var bar := _frame(Rect2(x, 22, 127, 42), hud, func(): _route("Loja"))
		_art(16 + i, Rect2(5, 6, 32, 32), bar)
		var l := _text("", Rect2(39, 11, 77, 25), bar, 17, WHITE, false, true)
		wallet_labels.append(l)
	var mail := _frame(Rect2(591, 80, 49, 49), hud, _mail, 1)
	_art(4, Rect2(8, 8, 33, 33), mail)
	var settings := _frame(Rect2(651, 80, 49, 49), hud, _settings, 1)
	_art(5, Rect2(8, 8, 33, 33), settings)
	_plate("Jornada", Rect2(460, 85, 115, 43), hud, _journey_menu, false, 16)
	_sync_wallet()

func _build_landscape_hud() -> void:
	_panel(Rect2(12, 10, 1256, 78), hud, Color(0.08, 0.06, 0.13, 0.96))
	_plate("Reino", Rect2(25, 24, 150, 48), hud, func():
		if game.fighting:
			_notice("Batalha em andamento", "Toque em Recuar para encerrar a batalha e voltar ao reino.")
		else: _route("Início"), false, 22)
	player_card = _create_player_card(hud, Vector2(187, 13), 0.57)
	var encounter_title: String = active_activity.to_upper()
	var encounter_rank: int = game.stage if active_activity == "Campanha" else int(state.tower_floor)
	if active_activity in ["Campanha", "Torre Infinita"]:
		encounter_title = activities.encounters.scene_info(active_activity, encounter_rank).name
	if current_page == "Forma\u00e7\u00e3o": encounter_title = "FORMACAO - 2 NA FRENTE / 3 ATRAS"
	var location_label := _text(encounter_title, Rect2(382, 20, 420, 28), hud, 15, GOLD, true)
	location_label.clip_text = true
	location_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	power_label = _text("", Rect2(420, 53, 150, 24), hud, 17, WHITE)
	_art(15, Rect2(387, 50, 26, 26), hud)
	var progress_text := "Fase %d" % game.stage if active_activity == "Campanha" else "Andar %d" % encounter_rank if active_activity == "Torre Infinita" else "Desafio %d" % game.enemy_rank()
	if active_activity in ["Campanha", "Torre Infinita"] and activities.encounters.is_boss(active_activity, encounter_rank): progress_text += " - BOSS"
	if current_page == "Forma\u00e7\u00e3o": progress_text = "Seu esquadrao"
	_text(progress_text, Rect2(580, 50, 220, 27), hud, 18, GOLD, true)
	for i in range(3):
		var bar := _frame(Rect2(815 + i * 146, 25, 140, 46), hud, func():
			if not game.fighting: _route("Loja"))
		_art(16 + i, Rect2(9, 6, 34, 34), bar)
		wallet_labels.append(_text("", Rect2(43, 12, 86, 28), bar, 19, WHITE, false, true))
	_sync_wallet()

func _sync_wallet() -> void:
	var amounts := [game.gold, game.gems, game.essence]
	for i in range(wallet_labels.size()): wallet_labels[i].text = game._number(amounts[i])
	if is_instance_valid(power_label): power_label.text = game._number(game._team_power())
	if is_instance_valid(player_card):
		player_card.level_label.text = "Nv. %d" % game.get_player_level()
		player_card.vip_label.text = "VIP %d" % int(state.vip)
		player_card.experience.value = game.get_player_progress()

func _build_nav() -> void:
	# One shared ornamental dock instead of a separate framed card per tab.
	var skin := AtlasTexture.new()
	skin.atlas = Frame.plaque_texture
	skin.region = Rect2(24, 174, 2124, 370)
	var dock := _image(skin, Rect2(10, 1185, 700, 83), navigation)
	dock.stretch_mode = TextureRect.STRETCH_SCALE
	var titles := ["Heróis", "Bag", "Formação", "Evolução", "Loja"]
	var artwork := [8, 9, 10, 11, 14]
	for i in range(5):
		var title: String = titles[i]
		var b := DockTab.new()
		b.position = Vector2(49 + i * 126, 1189)
		b.size = Vector2(118, 72)
		b.clip_contents = true
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var highlight := StyleBoxFlat.new()
		highlight.bg_color = Color(1, 0.73, 0.27, 0.12)
		highlight.set_corner_radius_all(10)
		b.add_theme_stylebox_override("normal", highlight if current_page == title else StyleBoxEmpty.new())
		b.add_theme_stylebox_override("hover", highlight)
		b.add_theme_stylebox_override("pressed", highlight)
		b.add_theme_stylebox_override("focus", highlight)
		b.pressed.connect(func(): _route(title))
		navigation.add_child(b)
		_art(artwork[i], Rect2(43, 7, 32, 32), b)
		var caption := _text(title, Rect2(0, 42, 118, 24), b, 16 if i in [2, 3] else 17, GOLD if current_page == title else WHITE, true, true)
		caption.clip_text = true
		caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.size = Vector2(118, 24)
		if current_page == title:
			var underline := ColorRect.new()
			underline.position = Vector2(39, 67)
			underline.size = Vector2(40, 2)
			underline.color = GOLD
			underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(underline)
		if i < 4:
			var separator := ColorRect.new()
			separator.position = Vector2(171 + i * 126, 1204)
			separator.size = Vector2(1, 30)
			separator.color = Color(0.88, 0.65, 0.31, 0.22)
			separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
			navigation.add_child(separator)
		nav_buttons.append(b)

func _journey_menu() -> void:
	var p := _open("Jornada", 360)
	_text("Objetivos e recompensas do Reino", Rect2(30, 90, 562, 28), p, 19, MUTED, false, true)
	var missions := _plate("Missões", Rect2(75, 144, 472, 65), p, func(): _route("Missões"), false, 25)
	_art(12, Rect2(26, 11, 43, 43), missions)
	var achievements := _plate("Conquistas", Rect2(75, 242, 472, 65), p, func(): _route("Conquistas"), false, 25)
	_art(13, Rect2(26, 11, 43, 43), achievements)

func _home() -> void:
	# Keep landmark labels aligned with their 9:16 artwork on taller phones.
	_image(home_background, Rect2(0, 0, 720, 1280), screen)
	var quick := Control.new()
	quick.name = "SideQuickMenu"
	screen.add_child(quick)
	var names := ["Eventos", "Recompensas", "Check-in"]
	for i in range(3):
		var title: String = names[i]
		var action: Callable = [_events, _claim_afk, _checkin][i]
		var b := _frame(Rect2(16, 151 + i * 98, 67, 67), quick, action, 2)
		_art(i + 1, Rect2(10, 9, 48, 48), b)
		_plate(title, Rect2(-15, 57, 99, 29), b, action, false, 12)
	var banners := Control.new()
	banners.name = "EventBanners"
	screen.add_child(banners)
	var pass_b := _frame(Rect2(506, 159, 201, 62), banners, _journey_pass, 0, false, Color("4b137b"))
	_text("Passe de\nJornada", Rect2(12, 6, 135, 52), pass_b, 18, WHITE, true, true)
	_art(6, Rect2(152, 14, 34, 34), pass_b)
	var event := _plate("Boas-vindas" if not state.welcome else "Jornada de Clover", Rect2(506, 234, 201, 62), banners, _events, false, 16, Color("63172b"))
	var locations := [
		["Torre Infinita", Rect2(90, 436, 199, 42)],
		["Arena", Rect2(500, 480, 164, 42)],
		["Invocação", Rect2(29, 636, 205, 44)],
		["Clã", Rect2(399, 620, 153, 42)],
		["Batalha de Chefes", Rect2(513, 703, 197, 44)],
		["Fusão", Rect2(26, 839, 188, 44)],
		["Mercado", Rect2(516, 851, 188, 44)],
		["Campanha", Rect2(223, 863, 274, 61)]
	]
	for entry in locations:
		var destination: String = entry[0]
		var b := _plate(destination, entry[1], screen, func(): _route(destination), destination == "Campanha", 27 if destination == "Campanha" else (18 if destination == "Batalha de Chefes" else 22))
		b.name = destination
		if destination == "Torre Infinita":
			var caption := b.get_child(0) as Label
			caption.add_theme_font_size_override("font_size", 20)
			caption.position = Vector2(12, 0)
			caption.size = Vector2(b.size.x - 24, b.size.y)
			caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if destination == "Campanha":
			_art(15, Rect2(14, 16, 31, 31), b)
			b.get_child(0).position.x = 48
			b.get_child(0).size.x = 210
	_build_effects()

func _build_effects() -> void:
	var fx := preload("res://scripts/visuals/home_effects.gd").new()
	fx.name = "SceneEffects"
	# Below the buttons, above the environment; input remains on real controls.
	screen.add_child(fx)
	fx.z_index = 0
	fx.enabled = bool(state.effects_enabled)

func _hero_card(id: int, rect: Rect2, action: Callable, parent: Node) -> Button:
	var b := _frame(rect, parent, action, 1, selected == id)
	var meta: Dictionary = game.hero_catalog.info(id)
	var rarity_color: Color = game.hero_catalog.rarity_color(id)
	var t := _image(game.hero_catalog.texture(id,game.atlas),Rect2(10,8,rect.size.x-20,rect.size.y-49),b)
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if not game.owned[id]: t.modulate = Color(0.42,0.42,0.5)
	var level_text := "Lv.%d" % game.levels[id]
	if current_page in ["Bag", "Fus\u00e3o"]: level_text = "x%d" % game.copies[id]
	_text(level_text,Rect2(10,7,65,22),b,13)
	var rare_label := _text(str(meta.rarity),Rect2(rect.size.x-110,7,100,22),b,12,rarity_color,false,true)
	rare_label.clip_text=true
	for star in range(int(meta.stars)):
		_art(19,Rect2((rect.size.x-int(meta.stars)*17)*0.5+star*17,rect.size.y-48,15,15),b)
	var name_label := _text(game.NAMES[id],Rect2(4,rect.size.y-28,rect.size.x-8,25),b,15,WHITE,true,true)
	name_label.clip_text=true
	name_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	return b

func _heroes() -> void:
	roster.render(Rect2(33,245,654,410),"heroes",func(id): selected=id; _route(current_page))
	var p := _panel(Rect2(34,667,652,438),screen,Color("261e32"))
	var name_label := _text(game.NAMES[selected]+" - "+game.ELEMENTS[selected],Rect2(22,18,610,38),p,25,game.COLORS[selected],true)
	name_label.clip_text=true
	_text(str(game.hero_catalog.info(selected).rarity)+" - NIVEL %d / 100 - %s" % [game.levels[selected],game.ROLES[selected]],Rect2(22,68,610,29),p,18,GOLD)
	_text("Vida                  %d\nAtaque              %d\nDefesa               %d" % [game.hero_hp(selected),game.hero_attack(selected),game.hero_defense(selected)],Rect2(24,116,600,119),p,23)
	_text(game.SKILLS[selected],Rect2(24,249,600,29),p,19,game.COLORS[selected])
	_text("Evoluir: %d ouro + %d essencia" % [game.levels[selected]*100,game.levels[selected]*5],Rect2(22,290,610,25),p,18,MUTED)
	_plate("Evoluir" if game.owned[selected] else "Obter heroi",Rect2(23,338,289,59),p,_evolve,true,24)
	_plate("Equipamento",Rect2(332,338,297,59),p,func(): _route("Equipamento"),false,20)

func _evolve() -> void:
	if not game.owned[selected]: _route("Invocação"); return
	if game.levels[selected] >= 100:
		_notice("Nível máximo", "Este cavaleiro já alcançou o nível 100.")
		return
	var cost: int = game.levels[selected] * 100
	var mana: int = game.levels[selected] * 5
	if game.gold < cost or game.essence < mana:
		_notice("Recursos insuficientes", "Colete seus ganhos AFK ou complete fases da campanha.")
		return
	game.gold -= cost
	game.essence -= mana
	game.levels[selected] += 1
	game._save_game()
	_route(current_page)

func _equip() -> void:
	if not game.owned[selected] or game.equipped[selected]: return
	if game.gold < 1000: _notice("Ouro insuficiente", "Você precisa de 1.000 ouro para aprimorar o grimório."); return
	game.gold -= 1000
	game.equipped[selected] = true
	game._save_game()
	_route(current_page)

func _formation() -> void:
	_text("Selecione uma posição e depois um cavaleiro.", Rect2(30, 240, 660, 32), screen, 20, MUTED, false, true)
	_text("FRENTE", Rect2(30, 290, 660, 28), screen, 17, GOLD, false, true)
	for i in range(5):
		var slot := i
		var pos := Vector2(147 + i * 225, 331) if i < 2 else Vector2(34 + (i - 2) * 229, 531)
		var b: Button
		if i < game.team.size():
			b = _hero_card(game.team[i], Rect2(pos, Vector2(204, 180)), func(): selected_slot = slot; _route("Formação"), screen)
		else:
			b = _plate("Vazio", Rect2(pos, Vector2(204, 180)), screen, func(): selected_slot = slot; _route("Formação"))
		b.active = i == selected_slot
	_text("RETAGUARDA", Rect2(30, 495, 660, 28), screen, 17, GOLD, false, true)
	_text("CAVALEIROS DISPONÍVEIS", Rect2(30, 738, 660, 28), screen, 17, GOLD, false, true)
	roster.render(Rect2(34,779,652,353),"formation",_choose_formation,true)

func _choose_formation(id: int) -> void:
	if not game.owned[id]: return
	var previous: int = game.team.find(id)
	if previous >= 0:
		if selected_slot >= game.team.size(): return
		game.team[previous]=game.team[selected_slot]
	if selected_slot < game.team.size(): game.team[selected_slot]=id
	elif game.team.size() < 5: game.team.append(id)
	game._save_game()
	_route("Forma\u00e7\u00e3o")

func _bag() -> void:
	var titles := ["Ouro", "Diamantes", "Essência mágica"]
	var amounts := [game.gold, game.gems, game.essence]
	for i in range(3):
		var p := _panel(Rect2(35, 247 + i * 104, 650, 86), screen)
		_art(16 + i, Rect2(15, 11, 64, 64), p)
		_text(titles[i], Rect2(100, 10, 510, 28), p, 21, GOLD, true)
		_text(str(amounts[i]), Rect2(102, 45, 510, 28), p, 22)
	_text("FRAGMENTOS DE CAVALEIRO", Rect2(34, 592, 650, 35), screen, 20, GOLD, true)
	roster.render(Rect2(34,644,652,474),"bag",func(id): selected=id; _route("Her\u00f3is"))

func _summoning() -> void:
	_image(game.tower, Rect2(24, 237, 672, 633), screen)
	_text("O grimório escolhe seu cavaleiro.", Rect2(37, 895, 646, 35), screen, 23, GOLD, true, true)
	_text("106 herois - Incomum 50% | Raro 30% | Epico 17% | Lendario 3%\nDuplicatas: 500 ouro e 1 fragmento", Rect2(37,943,646,64), screen,16,MUTED,false,true)
	_plate("Invocar 1 · 300 diamantes", Rect2(35, 1033, 310, 60), screen, func(): _summon(1), true, 17)
	_plate("Invocar 10 · 3.000 diamantes", Rect2(370, 1033, 315, 60), screen, func(): _summon(10), false, 17)

func _summon(count: int) -> void:
	if summon_revealing: return
	if game.gems < count * 300: _notice("Diamantes insuficientes", "Complete fases da campanha para receber diamantes."); return
	game.gems -= count * 300
	var results: Array = []
	for i in range(count):
		var id: int = game.hero_catalog.roll()
		if game.owned[id]:
			game.gold += 500
			game.copies[id] += 1
		else: game.owned[id] = true
		results.append(id)
	game._save_game()
	_sync_wallet()
	var p := _open("O grimório escolheu você", 895 if count == 10 else 700)
	summon_revealing = true
	for i in range(count):
		var rect := Rect2(27 + (i % 3) * 195, 102 + (i / 3) * 162, 183, 151) if count == 10 else Rect2(116, 105, 390, 430)
		var b := _hero_card(results[i], rect, func(): pass, p)
		b.modulate.a = 0
		var tw := create_tween()
		tw.tween_interval(i * 0.08)
		tw.tween_property(b, "modulate:a", 1.0, 0.3)
	_plate("Continuar", Rect2(150, p.size.y - 82, 320, 58), p, _close, true)

func _fusion() -> void:
	_text("Una 3 fragmentos para ganhar 3 niveis.\nSelecione um cavaleiro para fundir.",Rect2(35,246,650,66),screen,20,MUTED,false,true)
	roster.render(Rect2(34,332,652,620),"fusion",func(id): selected=id; _route(current_page))
	_text(game.NAMES[selected]+" - %d/3 fragmentos" % game.copies[selected],Rect2(35,966,650,35),screen,23,GOLD,true,true)
	_plate("FUNDIR CAVALEIRO",Rect2(110,1027,500,62),screen,_fuse_selected,true,23)

func _fuse_selected() -> void:
	if not game.owned[selected] or game.copies[selected]<3:
		_notice("Fragmentos insuficientes","Invoque copias do mesmo cavaleiro para obter fragmentos.")
		return
	if game.levels[selected]>=100: return
	game.copies[selected]-=3
	game.levels[selected]=mini(100,game.levels[selected]+3)
	game._save_game()
	_route("Fus\u00e3o")

func _shop() -> void:
	_text("Mercado do Reino", Rect2(35, 252, 650, 36), screen, 29, GOLD, true, true)
	_text("Trocas com recursos do jogo. Sem pagamentos reais.", Rect2(35, 306, 650, 29), screen, 18, MUTED, false, true)
	var p := _panel(Rect2(36, 378, 648, 260), screen)
	_art(18, Rect2(28, 25, 122, 122), p)
	_text("Essência mágica ×100", Rect2(174, 37, 445, 37), p, 25, GOLD, true)
	_text("Treine e evolua seus cavaleiros.", Rect2(174, 95, 445, 32), p, 20)
	_plate("Comprar · 1.000 ouro", Rect2(140, 178, 377, 59), p, func():
		if game.gold < 1000: _notice("Ouro insuficiente", "Colete os ganhos AFK ou vença batalhas."); return
		game.gold -= 1000
		game.essence += 100
		game._save_game()
		_sync_wallet(), true, 23)
	_plate("Ganhos AFK", Rect2(161, 730, 398, 62), screen, _claim_afk, false, 25)

func _campaign() -> void:
	_panel(Rect2(12,12,1256,696) if battle_view else Rect2(12,100,1256,478),screen,Color("211b2c"))
	var stage_texture: Texture2D = activities.background_for(active_activity)
	if active_activity not in ["Campanha", "Torre Infinita"]:
		# Frame the floor when converting square activity art to landscape.
		var ground_view := AtlasTexture.new()
		ground_view.atlas = stage_texture
		var art_size := stage_texture.get_size()
		ground_view.region = Rect2(0, art_size.y * 0.50, art_size.x, art_size.x * 466.0 / 1244.0)
		stage_texture = ground_view
	_image(stage_texture,Rect2(18,18,1244,684) if battle_view else Rect2(18,106,1244,466),screen)
	game.field = Node2D.new()
	game.field.position = Vector2(18,18) if battle_view else Vector2(18,106)
	game.field.set_meta("expanded",battle_view)
	game.field.y_sort_enabled = true
	screen.add_child(game.field)
	var left := preload("res://scripts/visuals/battle_formation.gd").slots(false,battle_view)
	for i in range(game.team.size()): game._spawn(game.team[i], left[i], false, preload("res://scripts/visuals/battle_formation.gd").height_for(i,false,false,battle_view), true)
	game.effects = Node2D.new()
	game.effects.position = game.field.position
	game.effects.z_index = 600
	screen.add_child(game.effects)
	game.log_label = _text("Seu esquadrão está pronto.", Rect2(24,657,680,29) if battle_view else Rect2(280,541,720,28), screen, 18, GOLD, false, true)
	game.log_label.z_index = 800
	game.battle_label = _text("", Rect2(467,24,350,32) if battle_view else Rect2(467,113,350,32), screen, 20, WHITE, false, true)
	game.battle_label.z_index = 800
	if battle_view:
		game.log_label.add_theme_font_size_override("font_size",14)
		game.log_label.clip_text=true
		_build_battle_controls()
		return
	_panel(Rect2(12,610,1256,92),screen)
	_plate("Formação", Rect2(28,628,174,46), screen, func(): _route("Formação"), false, 22)
	_plate("Ganhos AFK", Rect2(224,628,174,46), screen, _claim_afk, false, 21)
	_plate("Auto ligado" if auto_battle else "Auto", Rect2(420,628,174,46), screen, func():
		auto_battle = not auto_battle
		if not game.fighting: _route("Campanha"), auto_battle, 21).name = "AutoPreference"
	_plate("BATALHAR", Rect2(908,620,300,60), screen, _start_battle, true, 29).name = "Battle"

func _start_battle() -> void:
	if game.fighting: return
	_route("Campanha",true)
	game.fighting = true
	game.battle_time = 0
	game.beat = 0
	game.action_index = 0
	game.total_damage = 0
	game.round_number = 1
	var right := preload("res://scripts/visuals/battle_formation.gd").slots(true,true)
	if not activities.spawn_opponents():
		for i in range(5): game._spawn((game.stage + i + 2) % 6, right[i], true, preload("res://scripts/visuals/battle_formation.gd").height_for(i,true,false,true), true)
	if active_activity in ["Campanha", "Torre Infinita"]:
		var rank: int = game.stage if active_activity == "Campanha" else int(state.tower_floor)
		var wave: Array = activities.encounters.lineup(active_activity, rank)
		game.log_label.text = "CHEFÃO · " + str(wave[0].name) if activities.encounters.is_boss(active_activity, rank) else "Derrote a patrulha de " + str(wave[0].name)

func _battle_result(won: bool) -> void:
	if activities.finish(won): return
	_sync_wallet()
	var p := _open("VITÓRIA!" if won else "Esquadrão derrotado", 480)
	var reward: int = 700 + (game.stage - 1) * 100
	var message := "Fase concluída!\n\n+%d ouro\n+150 diamantes\n+%d essência mágica" % [reward, 50 + (game.stage - 1) * 5] if won else "Evolua seus cavaleiros, aprimore os\ngrimórios e ajuste sua formação."
	_text(message, Rect2(25, 113, 570, 197), p, 25, GOLD, false, true)
	_plate("Continuar", Rect2(145, 390, 330, 59), p, func():
		_close()
		if auto_battle and won: _start_battle()
		else: _route("Campanha"), true, 26)
	if auto_battle and won:
		get_tree().create_timer(2.5).timeout.connect(func():
			if auto_battle and is_instance_valid(popup) and not game.fighting and current_page == "Campanha":
				_close()
				_start_battle())

func _mission_list() -> Array:
	return [
		{"id": "stage3", "title": "O primeiro grimório", "text": "Conclua 3 fases da campanha", "done": game.stage > 3, "reward": 200},
		{"id": "stage6", "title": "Cavaleiro em ascensão", "text": "Conclua 6 fases da campanha", "done": game.stage > 6, "reward": 300},
		{"id": "level10", "title": "Além dos seus limites", "text": "Evolua um herói até o nível 10", "done": game.levels.max() >= 10, "reward": 200},
		{"id": "roster6", "title": "Os Touros Negros", "text": "Colecione os 6 cavaleiros", "done": game.owned.slice(0,6).count(true) == 6, "reward": 300}
	]

func _has_mission() -> bool:
	for m in _mission_list():
		if m.done and not m.id in state.missions: return true
	return false

func _missions() -> void:
	_text("Seu progresso no Reino de Clover", Rect2(35, 249, 650, 32), screen, 22, MUTED, false, true)
	var list := _mission_list()
	for i in range(list.size()):
		var m: Dictionary = list[i]
		var claimed: bool = m.id in state.missions
		var p := _panel(Rect2(35, 311 + i * 190, 650, 170), screen)
		_art(13 if current_page == "Conquistas" else 12, Rect2(17, 25, 90, 90), p)
		_text(m.title, Rect2(121, 16, 510, 35), p, 23, GOLD, true)
		_text(m.text, Rect2(121, 64, 510, 27), p, 18)
		_plate("Recebido" if claimed else ("Receber %d diamantes" % m.reward if m.done else "Em progresso"), Rect2(238, 107, 385, 48), p, func():
			if not m.done or m.id in state.missions: return
			state.missions.append(m.id)
			game.gems += m.reward
			_save_home()
			game._save_game()
			_route(current_page), m.done and not claimed, 19)

func _open(title: String, height: float) -> Panel:
	_close()
	popup = Control.new()
	popup_layer.add_child(popup)
	var shade := ColorRect.new()
	shade.position = -content_offset
	var design := Vector2(1280, 720) if landscape_mode else Vector2(720, 1280)
	shade.size = ui.size
	shade.color = Color(0.025, 0.015, 0.06, 0.83)
	popup.add_child(shade)
	var p := _panel(Rect2((design.x - 622) * 0.5, (design.y - height) * 0.5, 622, height), popup, Color("261d32"))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var emblem := 0
	if "VITÓRIA" in title: emblem = 13
	elif "derrotado" in title: emblem = 8
	elif "Boas-vindas" in title: emblem = 1
	elif "Check-in" in title: emblem = 3
	elif "Configurações" in title: emblem = 5
	elif "Recompensas" in title: emblem = 2
	elif "grimório" in title: emblem = 6
	_art(emblem, Rect2(19, 22, 52, 52), p)
	_text(title, Rect2(82, 25, 515, 50), p, 25, GOLD, true, true)
	return p

func _close() -> void:
	if is_instance_valid(popup):
		popup_layer.remove_child(popup)
		popup.queue_free()
	popup = null
	summon_revealing = false

func _notice(title: String, message: String) -> void:
	var p := _open(title, 420)
	var l := _text(message, Rect2(32, 119, 558, 168), p, 22, WHITE, false, true)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_plate("Voltar", Rect2(157, 326, 308, 57), p, _close, true, 24)

func _claim_afk() -> void:
	_route("Recompensas")

func _events() -> void:
	_route("Eventos")

func _checkin() -> void:
	_route("Check-in")

func _journey_pass() -> void:
	_route("Passe de Jornada")

func _mail() -> void:
	_route("Correio")

func _settings() -> void:
	_route("Configurações")

func _profile() -> void:
	var p := _open("Perfil do cavaleiro", 690)
	var preview = _create_player_card(p, Vector2(71, 100), 1.6)
	var name_input := LineEdit.new()
	name_input.text = state.name
	name_input.max_length = 16
	name_input.position = Vector2(62, 302)
	name_input.size = Vector2(498, 52)
	name_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(name_input)
	name_input.text_changed.connect(func(value: String): preview.name_label.text = value)
	_text("ESCOLHA SEU AVATAR", Rect2(30, 380, 562, 28), p, 18, GOLD, true, true)
	var choices: Array = []
	for i in range(avatar_page*6,mini(avatar_page*6+6,game.hero_catalog.count())):
		var id := i
		var choice := _frame(Rect2(29 + (i%6) * 94, 434, 89, 89), p, func():
			if not game.owned[id]: return
			state.avatar = id
			_save_home()
			preview.avatar.texture = _avatar_texture(id)
			if is_instance_valid(player_card): player_card.avatar.texture = _avatar_texture(id)
			for index in range(choices.size()):
				choices[index].active = choices[index].name == "AvatarChoice%d" % id
				choices[index].queue_redraw(), 2, int(state.avatar) == i)
		choice.name = "AvatarChoice%d" % i
		var face := _image(_avatar_texture(i), Rect2(9, 9, 71, 71), choice)
		var material := ShaderMaterial.new()
		material.shader = PlayerCard.CIRCLE
		material.set_shader_parameter("box_size", face.size)
		face.material = material
		if not game.owned[i]:
			choice.disabled = true
			choice.modulate = Color(0.4, 0.4, 0.45)
		_text(Game.NAMES[i], Rect2(0, 94, 89, 25), choice, 14, WHITE, false, true)
		choices.append(choice)
	_text("Nível da conta: %d  ·  Experiência: %d\nVIP %d" % [game.get_player_level(), game.player_xp, int(state.vip)], Rect2(30, 588, 562, 32), p, 17, MUTED, false, true)
	_plate("Anterior",Rect2(35,556,150,28),p,func(): avatar_page=maxi(0,avatar_page-1); _profile(),false,14)
	_text("%d / %d" % [avatar_page+1,ceili(game.hero_catalog.count()/6.0)],Rect2(245,556,132,28),p,15,GOLD,false,true)
	_plate("Proximo",Rect2(435,556,150,28),p,func(): avatar_page=mini(ceili(game.hero_catalog.count()/6.0)-1,avatar_page+1); _profile(),false,14)
	_plate("Salvar perfil", Rect2(150, 624, 322, 47), p, func():
		var value := name_input.text.strip_edges()
		if not value.is_empty(): state.name = value; _save_home()
		_route(current_page), true, 23)

func _unavailable(mode: String) -> void:
	_art(0, Rect2(300, 282, 120, 120), screen)
	_text(mode, Rect2(40, 410, 640, 47), screen, 32, GOLD, true, true)
	var description := "Esta atividade ainda não está disponível\nna versão local do jogo.\n\nSeu progresso na campanha continua salvo."
	if mode == "Arena": description = "O modo PvP precisa de um servidor online.\nEle ainda não está conectado nesta versão.\n\nA campanha PvE já está disponível."
	_text(description, Rect2(40, 510, 640, 180), screen, 23, MUTED, false, true)
	_plate("Jogar campanha", Rect2(161, 800, 398, 62), screen, func(): _route("Campanha"), true, 25)

func _today() -> String:
	return Time.get_date_string_from_system()

func _save_home() -> void:
	var file := FileAccess.open(home_save_path, FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(state))

func _load_home() -> void:
	if not FileAccess.file_exists(home_save_path): return
	var data = JSON.parse_string(FileAccess.get_file_as_string(home_save_path))
	if data is Dictionary:
		for key in state.keys():
			if data.has(key): state[key] = data[key]
	state.avatar = clampi(int(state.avatar), 0, game.hero_catalog.count()-1)
	if not game.owned[int(state.avatar)]: state.avatar = 0
	state.vip = clampi(int(state.vip), 0, 20)

func _process(delta: float) -> void:
	if layout_settle_frames > 0 and is_instance_valid(ui):
		_resize()
		layout_settle_frames -= 1
		if layout_settle_frames == 0: ui.show()
	update_clock += delta
	if update_clock >= 1:
		update_clock = 0
		if is_instance_valid(ui): _sync_wallet()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_instance_valid(ui):
		if is_instance_valid(popup): _close()
		elif current_page != "Início": _web_back([])
	if what in [NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED]:
		_save_home()
		if is_instance_valid(game): game._save_game()

func _build_battle_controls() -> void:
	var controls := Control.new()
	controls.name = "BattleControls"
	controls.mouse_filter=Control.MOUSE_FILTER_IGNORE
	screen.add_child(controls)
	_plate("%dx" % game.speed,Rect2(738,654,120,46),controls,func():
		game.speed=2 if game.speed==1 else 1
		controls.get_node("Speed").get_child(0).text="%dx" % game.speed,false,18).name="Speed"
	_plate("Batalha auto" if auto_battle else "Batalha",Rect2(870,654,180,46),controls,func():
		auto_battle=not auto_battle
		controls.get_node("Auto").get_child(0).text="Batalha auto" if auto_battle else "Batalha",false,17).name="Auto"
	_plate("Recuar",Rect2(1062,654,180,46),controls,_retreat_battle,false,17).name="Retreat"

func _retreat_battle() -> void:
	game.fighting=false
	auto_battle=false
	_route("In\u00edcio")

func _formation_landscape() -> void:
	_panel(Rect2(12,108,500,596),screen)
	_panel(Rect2(530,108,738,596),screen)
	_text("RETAGUARDA",Rect2(30,118,180,26),screen,17,GOLD,true,true)
	_text("FRENTE",Rect2(250,118,215,26),screen,17,GOLD,true,true)
	for i in range(5):
		var slot := i
		var position := Vector2(268,220+i*198) if i<2 else Vector2(42,153+(i-2)*182)
		var button: Button
		if i<game.team.size(): button=_hero_card(game.team[i],Rect2(position,Vector2(170,156)),func(): selected_slot=slot; _route("Forma\u00e7\u00e3o"),screen)
		else: button=_plate("Vazio",Rect2(position,Vector2(170,156)),screen,func(): selected_slot=slot; _route("Forma\u00e7\u00e3o"))
		button.active=i==selected_slot
	roster.render(Rect2(550,128,696,550),"formation",_choose_formation,true)
	_plate("Confirmar",Rect2(252,646,236,42),screen,func(): _route("Campanha"),true,18)
