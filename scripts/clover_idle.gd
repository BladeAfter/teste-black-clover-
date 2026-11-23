extends Node2D
signal battle_resolved(won: bool)
var hero_catalog = preload("res://scripts/activities/hero_catalog.gd").new()
var external_presentation := false
var battle_kind := "campaign"
var activity_rank := 1
## Black Clover idle RPG with generated, pre-rendered 3D chibi artwork.
const Knight = preload("res://scripts/visuals/chibi_knight.gd")
const SpriteFX = preload("res://scripts/visuals/combat_sprite_fx.gd")
static var NAMES := ["Asta", "Yuno", "Noelle", "Yami", "Magna", "Luck"]
static var ELEMENTS := ["Antimagia", "Vento", "Água", "Escuridão", "Fogo", "Relâmpago"]
static var ROLES := ["Guerreiro", "Mago", "Suporte", "Guerreiro", "Mago", "Assassino"]
static var SKILLS := ["Corte do Exterminador", "Tornado do Espírito", "Rugido do Dragão Marinho", "Corte Dimensional", "Bola de Fogo Explosiva", "Botas do Deus do Trovão"]
static var COLORS := [Color("e97691"), Color("8ad9a1"), Color("8ad6f4"), Color("ba97ed"), Color("f2aa6e"), Color("f7d975")]
const GOLD := Color("f5d18a")
const CREAM := Color("f7ecd5")
const MUTED := Color("bcb8ad")
const INK := Color("201d26")
var save_path := "user://clover_idle_v2.json"
var gold := 12500
var gems := 6000
var essence := 900
var stage := 1
var player_xp := 0
var levels: Array = [5, 5, 5, 5, 5, 1]
var owned: Array = [true, true, true, true, true, false]
var copies: Array = [0, 0, 0, 0, 0, 0]
var team: Array = [0, 3, 1, 2, 4]
var idle_gold := 0.0
var selected := 0
var selected_slot := 0
var page := "Campanha"
var fighting := false
var auto_next := false
var speed := 1
var round_number := 1
var battle_time := 0.0
var beat := 0.0
var action_index := 0
var total_damage := 0.0
var equipment_tab := false
var equipped: Array = [false, false, false, false, false, false]
var root_ui: Control
var content: Control
var popup_layer: Control
var popup: Control
var field: Node2D
var effects: Node2D
var actors: Array = []
var allies: Array = []
var foes: Array = []
var wallet: Label
var afk_text: Label
var battle_label: Label
var log_label: Label
var atlas: Texture2D
var forest: Texture2D
var tower: Texture2D
var title_font: Font
var body_font: Font
var autosave := 0.0
var summon_busy := false
var queued_next := false

func _ready() -> void:
	atlas = load("res://assets/idle-clover/heroes-atlas.png")
	forest = load("res://assets/idle-clover/clover-forest.png")
	tower = load("res://assets/idle-clover/grimoire-tower.png")
	title_font = load("res://assets/idle-clover/title.ttf")
	body_font = load("res://assets/idle-clover/body.ttf")
	if NAMES.size() == 6:
		for entry in hero_catalog.data.heroes:
			NAMES.append(entry.name)
			ELEMENTS.append(entry.element)
			ROLES.append(entry.role)
			SKILLS.append(entry.skill)
			COLORS.append(Color(entry.color))
	for key in ["levels", "owned", "copies", "equipped"]:
		var values: Array = get(key)
		while values.size() < hero_catalog.count(): values.append(1 if key == "levels" else 0 if key == "copies" else false)
	_load_game()
	if external_presentation: return
	var layer := CanvasLayer.new()
	add_child(layer)
	root_ui = Control.new()
	root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root_ui)
	var theme := Theme.new()
	theme.default_font = body_font
	theme.default_font_size = 18
	root_ui.theme = theme
	_texture(forest, Rect2(0, 0, 1280, 720), root_ui).modulate = Color(0.32, 0.38, 0.4)
	var shade := ColorRect.new()
	shade.color = Color(0.07, 0.07, 0.12, 0.7)
	shade.size = Vector2(1280, 720)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(shade)
	_build_header()
	content = Control.new()
	root_ui.add_child(content)
	_build_nav()
	popup_layer = Control.new()
	popup_layer.z_index = 1500
	popup_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(popup_layer)
	_show_page("Campanha")

func _style(bg: Color, border := Color("ad8350"), radius := 12, width := 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0, 0, 0, 0.38)
	s.shadow_size = 5
	s.shadow_offset = Vector2(0, 3)
	return s

func _panel(rect: Rect2, parent: Node, bg := Color("27252e"), border := Color("ad8350"), radius := 12) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.add_theme_stylebox_override("panel", _style(bg, border, radius))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p

func _label(text: String, rect: Rect2, parent: Node, size := 20, color := CREAM, fancy := false, center := false) -> Label:
	var l := Label.new()
	l.text = text
	l.position = rect.position
	l.size = rect.size
	l.add_theme_font_override("font", title_font if fancy else body_font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if center: l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l

func _button(text: String, rect: Rect2, action: Callable, parent: Node, accent := false) -> Button:
	var b := Button.new()
	b.text = text
	b.position = rect.position
	b.size = rect.size
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_color_override("font_color", Color("442b1f") if accent else CREAM)
	b.add_theme_color_override("font_hover_color", Color("442b1f") if accent else Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color("8e8b83"))
	b.add_theme_stylebox_override("normal", _style(Color("ecc16d") if accent else Color("39303a"), Color("ffe2a0") if accent else Color("a08052"), 9))
	b.add_theme_stylebox_override("hover", _style(Color("ffdb88") if accent else Color("645040"), Color("ffe3a0"), 9))
	b.add_theme_stylebox_override("pressed", _style(Color("bd8948"), Color("efc574"), 9))
	b.add_theme_stylebox_override("disabled", _style(Color("302e33"), Color("666057"), 9))
	b.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, Color("fff1bb"), 9))
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func _texture(tex: Texture2D, rect: Rect2, parent: Node) -> TextureRect:
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.texture = tex
	t.position = rect.position
	t.size = rect.size
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)
	return t

func _portrait(id: int, rect: Rect2, parent: Node, full := false) -> TextureRect:
	var tex: Texture2D = hero_catalog.texture(id,atlas)
	var t := _texture(tex, rect, parent)
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if full else TextureRect.STRETCH_KEEP_ASPECT_COVERED
	return t

func _line(y: float, x: float, width: float, parent: Node) -> void:
	var line := ColorRect.new()
	line.position = Vector2(x, y)
	line.size = Vector2(width, 1)
	line.color = Color("866c49")
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)

func _build_header() -> void:
	_panel(Rect2(16, 12, 1248, 74), root_ui, Color("24212b"))
	_label("♣", Rect2(32, 12, 60, 60), root_ui, 47, GOLD)
	_label("BLACK CLOVER", Rect2(93, 21, 360, 33), root_ui, 26, GOLD, true)
	_label("CAVALEIROS DO GRIMÓRIO", Rect2(96, 55, 330, 22), root_ui, 12, MUTED)
	_panel(Rect2(502, 27, 620, 44), root_ui, Color("171820"), Color("735c42"), 22)
	wallet = _label("", Rect2(524, 34, 585, 32), root_ui, 19)
	_button("?", Rect2(1140, 27, 43, 44), _help, root_ui)
	_button("☰", Rect2(1197, 27, 43, 44), _settings, root_ui)
	_update_wallet()

func _build_nav() -> void:
	_panel(Rect2(16, 642, 1248, 65), root_ui, Color("24212b"))
	var titles := ["⚔  Campanha", "♟  Heróis", "✦  Convocação", "♣  Mapa", "▣  Inventário"]
	var pages := ["Campanha", "Heróis", "Convocação", "Mapa", "Inventário"]
	for i in range(5):
		var p: String = pages[i]
		var b := _button(titles[i], Rect2(29 + i * 247, 651, 232, 46), func():
			if fighting:
				_toast("Conclua a batalha antes de sair.")
				return
			_close_popup()
			_show_page(p), root_ui)
		b.name = "Nav" + p

func _update_wallet() -> void:
	if is_instance_valid(wallet): wallet.text = "●  %s     ◇  %s     ✦  %s" % [_number(gold), _number(gems), _number(essence)]

func _number(n: int) -> String:
	if n >= 1000000: return "%.1fM" % (n / 1000000.0)
	if n >= 10000: return "%.1fK" % (n / 1000.0)
	return str(n)

func _show_page(next: String) -> void:
	page = next
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()
	actors.clear()
	allies.clear()
	foes.clear()
	field = null
	effects = null
	afk_text = null
	for p in ["Campanha", "Heróis", "Convocação", "Mapa", "Inventário"]:
		var b := root_ui.get_node("Nav" + p) as Button
		b.add_theme_stylebox_override("normal", _style(Color("674730") if p == page else Color("39303a"), GOLD if p == page else Color("a08052"), 9))
	match page:
		"Campanha": _campaign()
		"Heróis": _heroes()
		"Convocação": _summoning()
		"Mapa": _map()
		"Inventário": _inventory()

func _campaign() -> void:
	_panel(Rect2(18, 100, 172, 524), content, Color("2b2730"))
	_label("CAMPANHA", Rect2(30, 117, 148, 30), content, 18, GOLD, true, true)
	_line(158, 32, 143, content)
	_label("CAPÍTULO 01", Rect2(30, 176, 148, 28), content, 14, MUTED, false, true)
	_label("Vila de Hage", Rect2(28, 205, 152, 32), content, 20, CREAM, true, true)
	_label("♣", Rect2(48, 252, 115, 80), content, 70, GOLD, true, true)
	_label("Fase 1–%d" % stage, Rect2(29, 346, 150, 34), content, 26, GOLD, true, true)
	_label("Poder: %s" % _number(_team_power()), Rect2(28, 387, 150, 28), content, 17, CREAM, false, true)
	_button("Formação", Rect2(32, 443, 143, 44), _formation, content)
	_button("Ganhos AFK", Rect2(32, 507, 143, 44), _claim, content, true)
	afk_text = _label("", Rect2(24, 562, 160, 44), content, 14, GOLD, false, true)
	_panel(Rect2(204, 100, 1058, 425), content, Color("3d332c"), GOLD)
	var scene := Control.new()
	scene.position = Vector2(210, 106)
	scene.size = Vector2(1046, 413)
	scene.clip_contents = true
	content.add_child(scene)
	_texture(forest, Rect2(0, 0, 1046, 413), scene)
	var banner := _panel(Rect2(12, 10, 1022, 48), scene, Color(0.1, 0.12, 0.17, 0.85), Color("a58c59"), 7)
	_label("♣  FLORESTA DOS GRIMÓRIOS", Rect2(18, 11, 630, 28), banner, 18, GOLD)
	_label("+%d ouro / min" % (120 + stage * 10), Rect2(680, 12, 320, 26), banner, 16, CREAM, false, true)
	field = Node2D.new()
	scene.add_child(field)
	var positions := [Vector2(290, 338), Vector2(440, 338), Vector2(218, 270), Vector2(364, 267), Vector2(510, 268)]
	for i in range(team.size()):
		_spawn(team[i], positions[i], false, 199 if i < 2 else 171, true)
	effects = Node2D.new()
	effects.z_index = 500
	scene.add_child(effects)
	var encounter := _panel(Rect2(795, 91, 229, 275), scene, Color(0.13, 0.14, 0.18, 0.89), Color("b09565"))
	_label("PRÓXIMO DESAFIO", Rect2(12, 15, 205, 24), encounter, 14, GOLD, false, true)
	_portrait((stage + 4) % 6, Rect2(48, 46, 135, 135), encounter, true)
	_label("Cavaleiros rivais", Rect2(8, 189, 213, 28), encounter, 18, CREAM, true, true)
	_label("Recompensas: ouro + cristais", Rect2(8, 229, 213, 22), encounter, 13, MUTED, false, true)
	encounter.name = "Encounter"
	_panel(Rect2(204, 538, 1058, 86), content, Color("312831"), GOLD)
	for i in range(6):
		var n := maxi(1, stage - 2) + i
		var b := _button(("✓ " if n < stage else ("⚔ " if n == stage else "")) + "1–%d" % n, Rect2(222 + i * 111, 555, 99, 51), func(): _toast("Avance pela campanha para liberar novas fases."), content, n == stage)
		b.disabled = n > stage
	_button("BATALHAR  ⚔", Rect2(925, 550, 318, 60), _start_battle, content, true).name = "BattleButton"

func _spawn(id: int, pos: Vector2, enemy: bool, height: float, bars := true) -> Node2D:
	var unit = Knight.new()
	unit.position = pos
	unit.home = pos
	unit.z_index = int(pos.y)
	field.add_child(unit)
	unit.setup(id if id < 6 else 0, atlas, COLORS[id], height, enemy, bars)
	unit.hero_id = id
	unit.skill_pattern = int(hero_catalog.info(id).behavior)
	if id >= 6:
		unit.body.texture = hero_catalog.texture(id, atlas)
		var cell_size: Vector2 = unit.body.texture.get_size()
		unit.body.scale = Vector2.ONE * height / cell_size.y
		unit.body.offset = Vector2(0,-cell_size.y*0.42)
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/encounter_alpha.gdshader")
		unit.body.material = material
		unit.combat_element = int(hero_catalog.info(id).vfx)
		unit.attack_modifier = float(hero_catalog.info(id).attack)
	unit.max_hp = hero_hp(id) if not enemy else (800 + enemy_rank() * 170)
	unit.hp = unit.max_hp
	actors.append(unit)
	if enemy: foes.append(unit)
	else: allies.append(unit)
	return unit

func _team_power() -> int:
	var p := 0
	for id in team: p += int((150 + levels[id] * 82) * float(hero_catalog.info(id).attack)) + (100 if equipped[id] else 0)
	return p

func _card(id: int, rect: Rect2, parent: Node, action: Callable, small := false) -> Button:
	var b := _button("", rect, action, parent)
	b.clip_contents = true
	b.add_theme_stylebox_override("normal", _style(Color("373043"), COLORS[id].lerp(GOLD, 0.4), 10, 2))
	var glow := _panel(Rect2(5, 5, rect.size.x - 10, rect.size.y - 10), b, Color(COLORS[id], 0.12), Color(COLORS[id], 0.3), 7)
	var h := rect.size.y - (29 if small else 57)
	_portrait(id, Rect2(3, 2, rect.size.x - 6, h), glow, true)
	_label("Lv.%d" % levels[id], Rect2(7, 5, rect.size.x - 14, 22), b, 12, CREAM)
	if not owned[id]:
		b.modulate = Color(0.56, 0.56, 0.62)
		_label("NÃO OBTIDO", Rect2(0, h - 25, rect.size.x, 22), b, 11, CREAM, false, true)
	_label("★★★★★", Rect2(0, h - 7, rect.size.x, 24), b, 13, GOLD, false, true)
	_label(NAMES[id], Rect2(0, h + 14, rect.size.x, 26), b, 14 if small else 19, CREAM, false, true)
	if not small: _label(ELEMENTS[id], Rect2(0, h + 39, rect.size.x, 20), b, 12, COLORS[id], false, true)
	return b

func _heroes() -> void:
	_panel(Rect2(18, 100, 1244, 524), content, Color(0.12, 0.12, 0.17, 0.94), GOLD)
	_label("Salão dos Cavaleiros", Rect2(41, 115, 650, 40), content, 28, GOLD, true)
	_label("%d / 6 heróis" % owned.count(true), Rect2(970, 125, 255, 26), content, 18, MUTED, false, true)
	_line(167, 42, 1196, content)
	for i in range(6):
		var id := i
		_card(i, Rect2(43 + (i % 3) * 155, 186 + (i / 3) * 198, 140, 185), content, func(): selected = id; equipment_tab = false; _show_page("Heróis"))
	var showcase := _panel(Rect2(527, 186, 309, 407), content, Color("252638"), Color("76634f"))
	_texture(tower, Rect2(6, 6, 297, 395), showcase).modulate = Color(0.55, 0.59, 0.77)
	_portrait(selected, Rect2(8, 12, 293, 334), showcase, true)
	_label(NAMES[selected], Rect2(5, 345, 299, 40), showcase, 29, GOLD, true, true)
	_panel(Rect2(854, 186, 383, 407), content, Color("342a31"), Color("c6a16a"))
	_button("Informação", Rect2(870, 200, 168, 41), func(): equipment_tab = false; _show_page("Heróis"), content, not equipment_tab)
	_button("Equipamento", Rect2(1048, 200, 173, 41), func(): equipment_tab = true; _show_page("Heróis"), content, equipment_tab)
	if equipment_tab:
		_label("Arsenal do cavaleiro", Rect2(875, 261, 340, 35), content, 22, GOLD, true, true)
		_label("⚔", Rect2(980, 313, 140, 90), content, 64, GOLD, false, true)
		_label("Grimório aprimorado" if equipped[selected] else "Grimório de aprendiz", Rect2(870, 412, 353, 28), content, 20, CREAM, false, true)
		_label("+100 de poder  •  +20% de dano" if equipped[selected] else "Melhore seu equipamento por 1.000 ouro.", Rect2(864, 453, 367, 26), content, 15, MUTED, false, true)
		_button("Equipado" if equipped[selected] else "Aprimorar • 1.000 ouro", Rect2(878, 522, 335, 50), _equip, content, true).disabled = equipped[selected] or not owned[selected]
	else:
		_label("%s  •  %s" % [ELEMENTS[selected], ROLES[selected]], Rect2(877, 259, 340, 30), content, 19, COLORS[selected])
		_label("★★★★★    Nível %d / 100" % levels[selected], Rect2(877, 299, 340, 27), content, 18, GOLD)
		_line(341, 877, 335, content)
		_label("Vida\nAtaque\nDefesa", Rect2(879, 355, 180, 108), content, 20, MUTED)
		_label("%d\n%d\n%d" % [850 + levels[selected] * 130, 95 + levels[selected] * 27, 40 + levels[selected] * 9], Rect2(1098, 355, 120, 108), content, 20, CREAM)
		_label(SKILLS[selected], Rect2(877, 457, 340, 27), content, 15, COLORS[selected])
		_label("Custo: %d ouro + %d essência" % [levels[selected] * 100, levels[selected] * 5], Rect2(877, 493, 340, 23), content, 15, MUTED)
		_button("EVOLUIR  ↑" if owned[selected] else "Obtenha na Convocação", Rect2(878, 529, 335, 46), _upgrade, content, true).disabled = not owned[selected] or levels[selected] >= 100

func _equip() -> void:
	if gold < 1000:
		_toast("Ouro insuficiente. Colete ganhos AFK.")
		return
	gold -= 1000
	equipped[selected] = true
	_save_game()
	_update_wallet()
	_show_page("Heróis")
	_toast("Grimório aprimorado! +20% de dano.")

func _upgrade() -> void:
	if not owned[selected] or levels[selected] >= 100: return
	if gold < levels[selected] * 100 or essence < levels[selected] * 5:
		_toast("Recursos insuficientes. Ganhe mais nas batalhas e ganhos AFK.")
		return
	gold -= levels[selected] * 100
	essence -= levels[selected] * 5
	levels[selected] += 1
	_save_game()
	_update_wallet()
	_show_page("Heróis")
	_toast("%s evoluiu para o nível %d!" % [NAMES[selected], levels[selected]])

func _summoning() -> void:
	_panel(Rect2(18, 100, 1244, 524), content, INK, GOLD)
	var room := Control.new()
	room.position = Vector2(24, 106)
	room.size = Vector2(1232, 512)
	room.clip_contents = true
	content.add_child(room)
	_texture(tower, Rect2(0, 0, 1232, 512), room)
	_label("Torre dos Grimórios", Rect2(32, 24, 620, 48), room, 31, GOLD, true)
	_label("O seu próximo cavaleiro espera por você.", Rect2(35, 77, 650, 30), room, 18, CREAM)
	_panel(Rect2(30, 139, 324, 240), room, Color(0.1, 0.1, 0.2, 0.89), Color("a58c65"))
	_label("✦  CONVOCAÇÃO HEROICA", Rect2(47, 155, 290, 30), room, 18, GOLD)
	_label("Heróis de Black Clover\n\nAsta • Yuno • Noelle\nYami • Magna • Luck", Rect2(48, 206, 280, 132), room, 19, CREAM)
	_label("Chance igual: 16,67% por herói", Rect2(47, 344, 295, 24), room, 14, MUTED)
	_label("Duplicatas: +500 ouro e 1 fragmento", Rect2(33, 397, 540, 25), room, 15, MUTED)
	_button("CONVOCAR 1  •  ◇ 300", Rect2(34, 445, 350, 50), func(): _summon(1), room, true)
	_button("CONVOCAR 10  •  ◇ 3.000", Rect2(405, 445, 355, 50), func(): _summon(10), room, true)
	_button("Ver coleção", Rect2(925, 445, 270, 50), func(): _show_page("Heróis"), room)

func _summon(count: int) -> void:
	if summon_busy: return
	if gems < count * 300:
		_toast("Cristais insuficientes. Complete fases da campanha.")
		return
	gems -= count * 300
	var results: Array = []
	var new_count := 0
	for i in range(count):
		var id := randi_range(0, 5)
		var fresh: bool = not owned[id]
		if not fresh:
			gold += 500
			copies[id] += 1
		else:
			owned[id] = true
			new_count += 1
		results.append({"id": id, "fresh": fresh})
	selected = results[0].id
	_save_game()
	_update_wallet()
	var panel := _open_popup("✦  O GRIMÓRIO ESCOLHEU VOCÊ", Vector2(1000, 498))
	summon_busy = true
	_label("%d novo(s) cavaleiro(s)  •  Duplicatas convertidas em ouro e fragmentos" % new_count, Rect2(30, 73, 940, 27), panel, 17, MUTED, false, true)
	for i in range(results.size()):
		var id: int = results[i].id
		var rect := Rect2(59 + (i % 5) * 181, 111 + (i / 5) * 150, 157, 140) if count == 10 else Rect2(373, 107, 254, 285)
		var card := _card(id, rect, panel, func(): pass, count == 10)
		card.modulate.a = 0
		var tw := create_tween()
		tw.tween_interval(i * 0.1)
		tw.tween_property(card, "modulate:a", 1.0, 0.3)
		if results[i].fresh: _label("NOVO!", Rect2(rect.position.x, rect.position.y + 23, rect.size.x, 25), panel, 17, GOLD, true, true)
	_button("Continuar", Rect2(348, 432, 304, 45), _close_popup, panel, true)

func _map() -> void:
	_panel(Rect2(18, 100, 1244, 524), content, INK, GOLD)
	var map := Control.new()
	map.position = Vector2(24, 106)
	map.size = Vector2(1232, 512)
	map.clip_contents = true
	content.add_child(map)
	_texture(forest, Rect2(0, 0, 1232, 512), map).modulate = Color(0.65, 0.72, 0.72)
	_label("Reino de Clover", Rect2(30, 19, 600, 50), map, 33, GOLD, true)
	_label("CAPÍTULO 01  •  O começo de uma lenda", Rect2(34, 77, 700, 28), map, 18)
	var locations := ["Vila de Hage", "Floresta dos Grimórios", "Torre dos Magos", "Capital Real", "Templo Subaquático", "Reino de Diamond"]
	for i in range(6):
		var n := i * 5 + 1
		var y := 191 + (i % 2) * 125
		var b := _button(("♣" if stage >= n else "◇") + "\n" + locations[i], Rect2(20 + i * 202, y, 184, 99), func():
			if stage >= n: _show_page("Campanha")
			else: _toast("Complete a fase 1–%d para liberar esta região." % (n - 1)), map, stage >= n)
		b.add_theme_font_size_override("font_size", 16)
		_label("FASES %d–%d" % [n, n + 4], Rect2(20 + i * 202, y + 111, 184, 23), map, 13, CREAM, false, true)

func _inventory() -> void:
	_panel(Rect2(18, 100, 1244, 524), content, Color("29252e"), GOLD)
	_label("Baú dos Cavaleiros", Rect2(44, 119, 900, 44), content, 30, GOLD, true)
	_label("Recursos e fragmentos obtidos na sua jornada", Rect2(47, 168, 900, 28), content, 18, MUTED)
	var titles := ["Ouro", "Cristais", "Essência mágica"]
	var symbols := ["●", "◇", "✦"]
	var values := [gold, gems, essence]
	for i in range(3):
		var p := _panel(Rect2(44 + i * 398, 222, 376, 120), content, Color("37303d"), GOLD)
		_label(symbols[i], Rect2(20, 22, 70, 70), p, 47, GOLD)
		_label(titles[i], Rect2(100, 20, 250, 32), p, 21, CREAM, true)
		_label(_number(values[i]), Rect2(101, 62, 230, 34), p, 25, GOLD)
	_label("FRAGMENTOS DE CAVALEIRO", Rect2(46, 372, 900, 30), content, 18, GOLD)
	for i in range(6):
		var p := _panel(Rect2(45 + i * 199, 417, 179, 172), content, Color("39303d"), COLORS[i])
		_portrait(i, Rect2(28, 4, 123, 117), p, true)
		_label("%s  ×%d" % [NAMES[i], copies[i]], Rect2(5, 128, 169, 28), p, 18, CREAM, false, true)

func _open_popup(title: String, size: Vector2) -> Panel:
	_close_popup()
	popup = Control.new()
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_layer.add_child(popup)
	var shade := ColorRect.new()
	shade.size = Vector2(1280, 720)
	shade.color = Color(0.025, 0.025, 0.06, 0.83)
	popup.add_child(shade)
	var p := _panel(Rect2((Vector2(1280, 720) - size) * 0.5, size), popup, Color("322a34"), GOLD, 17)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	_label(title, Rect2(18, 18, size.x - 36, 37), p, 25, GOLD, true, true)
	_line(67, 24, size.x - 48, p)
	return p

func _close_popup() -> void:
	if is_instance_valid(popup):
		popup_layer.remove_child(popup)
		popup.queue_free()
	popup = null
	summon_busy = false

func _formation() -> void:
	if fighting: return
	var p := _open_popup("FORMAÇÃO DOS CAVALEIROS", Vector2(1020, 520))
	_label("Escolha uma posição e depois um herói. Até 5 cavaleiros, sem repetir.", Rect2(25, 77, 970, 29), p, 17, MUTED, false, true)
	_label("LINHA DE FRENTE", Rect2(65, 119, 350, 24), p, 14, GOLD, false, true)
	_label("RETAGUARDA", Rect2(440, 119, 520, 24), p, 14, GOLD, false, true)
	for i in range(5):
		var slot := i
		var x := 61 + i * 184
		var b := _card(team[i], Rect2(x, 155, 160, 137), p, func(): selected_slot = slot; _formation(), true) if i < team.size() else _button("+", Rect2(x, 155, 160, 137), func(): selected_slot = slot; _formation(), p)
		if selected_slot == i: b.add_theme_stylebox_override("normal", _style(Color("61503d"), GOLD, 10, 4))
	_line(316, 31, 958, p)
	for i in range(6):
		var id := i
		var b := _card(i, Rect2(57 + i * 153, 334, 140, 110), p, func():
			if not owned[id]: return
			if id in team:
				var previous := team.find(id)
				if selected_slot < team.size():
					var swapped: int = team[selected_slot]
					team[selected_slot] = id
					team[previous] = swapped
			elif selected_slot < team.size(): team[selected_slot] = id
			elif team.size() < 5: team.append(id)
			_save_game()
			_formation(), true)
		b.disabled = not owned[i]
	_button("CONFIRMAR FORMAÇÃO", Rect2(344, 463, 333, 41), func(): _close_popup(); _show_page("Campanha"), p, true)

func _claim() -> void:
	if fighting: return
	var amount := int(idle_gold)
	var mana := int(amount / 12.0)
	gold += amount
	essence += mana
	idle_gold -= amount
	_save_game()
	_update_wallet()
	var p := _open_popup("TESOURO AFK COLETADO", Vector2(660, 365))
	_label("Seus cavaleiros continuam treinando enquanto você descansa.", Rect2(20, 83, 620, 30), p, 16, MUTED, false, true)
	_label("●  +%s ouro     ✦  +%s essência" % [_number(amount), _number(mana)], Rect2(25, 146, 610, 46), p, 26, GOLD, true, true)
	_label("Acúmulo offline por até 8 horas. Ganhos crescem com a campanha.", Rect2(20, 220, 620, 30), p, 15, MUTED, false, true)
	_button("Receber", Rect2(190, 286, 280, 50), _close_popup, p, true)

func _start_battle() -> void:
	if fighting or team.is_empty(): return
	_close_popup()
	_show_page("Campanha")
	fighting = true
	battle_time = 0
	beat = 0
	action_index = 0
	total_damage = 0
	round_number = 1
	var scene := field.get_parent()
	var encounter := scene.get_node("Encounter")
	encounter.queue_free()
	var left_slots := [Vector2(325, 260), Vector2(325, 369), Vector2(145, 228), Vector2(145, 312), Vector2(145, 395)]
	var right_slots := [Vector2(721, 260), Vector2(721, 369), Vector2(901, 228), Vector2(901, 312), Vector2(901, 395)]
	for i in range(allies.size()):
		var a = allies[i]
		a.position = left_slots[i]
		a.home = a.position
		a.z_index = int(a.position.y)
		a.scale = Vector2.ONE * 0.83
	for i in range(5):
		var id := (stage + i + 2) % 6
		_spawn(id, right_slots[i], true, 161, true)
	for c in content.get_children():
		if c.name == "BattleButton": c.queue_free()
	_button("×%d" % speed, Rect2(932, 551, 91, 58), func(): speed = 2 if speed == 1 else 1; _update_battle_controls(), content).name = "SpeedButton"
	_button("AUTO ✓" if auto_next else "AUTO", Rect2(1033, 551, 116, 58), func(): auto_next = not auto_next; _update_battle_controls(), content, auto_next).name = "AutoButton"
	_button("Sair", Rect2(1159, 551, 82, 58), _retreat, content)
	battle_label = _label("", Rect2(530, 175, 350, 30), content, 17, GOLD, true, true)
	battle_label.z_index = 700
	log_label = _label("Os cavaleiros entram em combate!", Rect2(360, 493, 700, 25), content, 16, GOLD, false, true)

func _update_battle_controls() -> void:
	var b = content.get_node_or_null("SpeedButton")
	if b: b.text = "×%d" % speed
	var a = content.get_node_or_null("AutoButton")
	if a: a.text = "AUTO ✓" if auto_next else "AUTO"

func _retreat() -> void:
	fighting = false
	auto_next = false
	_show_page("Campanha")
	_toast("Batalha encerrada. Ajuste sua equipe e tente novamente.")

func _living(units: Array) -> Array:
	return units.filter(func(u): return is_instance_valid(u) and u.alive)

func _combat_tick() -> void:
	var living_allies := _living(allies)
	var living_foes := _living(foes)
	if living_allies.is_empty() or living_foes.is_empty():
		_finish_battle(not living_allies.is_empty())
		return
	var attackers := living_allies if action_index % 2 == 0 else living_foes
	var targets := living_foes if action_index % 2 == 0 else living_allies
	var attacker = attackers[(action_index / 2) % attackers.size()]
	var target = targets[0]
	attacker.energy = minf(100, attacker.energy + 34)
	var ultimate: bool = attacker.energy >= 100
	var base: float = ((95.0 + levels[attacker.hero_id] * 27) if not attacker.enemy else (90.0 + enemy_rank() * 17)) * attacker.attack_modifier
	if not attacker.enemy and equipped[attacker.hero_id]: base *= 1.2
	# Defense reduces damage; Asta's anti-magic partially bypasses protection.
	var target_rank: float = target.defense_rank if target.defense_rank >= 0 else enemy_rank()
	var armor: float = 40 + (target_rank * 9 if not attacker.enemy else levels[target.hero_id] * 9)
	base *= 100.0 / (100.0 + armor * (0.3 if attacker.hero_id == 0 else 0.6))
	var damage: float = base * randf_range(0.87, 1.13) * (2.7 if ultimate else 1.0)
	attacker.strike(target.home, ultimate)
	if ultimate:
		attacker.energy = 0
		log_label.text = (NAMES[attacker.hero_id] + "  •  " + SKILLS[attacker.hero_id]) if attacker.custom_skill.is_empty() else attacker.custom_skill
		log_label.modulate = COLORS[attacker.hero_id]
		if attacker.skill_pattern == 2:
			for friend in attackers:
				friend.hp = minf(friend.max_hp, friend.hp + base * 0.65)
	var attack_targets: Array = targets.slice(0, mini(3, targets.size())) if ultimate and attacker.skill_pattern in [1, 2, 4] else [target]
	for victim in attack_targets:
		victim.receive(damage)
		_impact(attacker, victim, damage, ultimate)
		if not attacker.enemy: total_damage += damage
	action_index += 1
	round_number = 1 + int(action_index / 10)
	if _living(foes).is_empty(): _finish_battle(true)
	elif _living(allies).is_empty(): _finish_battle(false)

func _impact(attacker: Node2D, target: Node2D, damage: float, ultimate: bool) -> void:
	var color: Color = COLORS[attacker.hero_id]
	var hit := target.position + Vector2(0, -80)
	SpriteFX.spawn(effects, attacker.combat_element if attacker.combat_element >= 0 else (4 if not attacker.custom_skill.is_empty() else attacker.hero_id), attacker.position + Vector2(0, -80), hit, ultimate)
	var number := _label(("CRÍTICO " if ultimate else "−") + str(int(damage)), Rect2(hit + Vector2(-70, -45), Vector2(180, 35)), effects, 28 if ultimate else 22, GOLD if ultimate else Color.WHITE, true, true)
	number.z_index = 1000
	var tw := create_tween()
	tw.tween_property(number, "position:y", number.position.y - 48, 0.7)
	tw.parallel().tween_property(number, "modulate:a", 0.0, 0.7)
	tw.tween_callback(number.queue_free)

func _finish_battle(won: bool) -> void:
	if not fighting: return
	fighting = false
	if external_presentation and battle_kind != "campaign":
		battle_resolved.emit(won)
		return
	var reward := 700 + stage * 100
	var mana := 50 + stage * 5
	if won:
		gold += reward
		gems += 150
		essence += mana
		player_xp += 75
		stage += 1
	else: auto_next = false
	_save_game()
	_update_wallet()
	if external_presentation:
		battle_resolved.emit(won)
		return
	var p := _open_popup("✦  VITÓRIA!  ✦" if won else "ESQUADRÃO DERROTADO", Vector2(730, 433))
	_label("FASE 1–%d  •  %d rodadas  •  %ds" % [stage - 1 if won else stage, round_number, int(battle_time)], Rect2(30, 83, 670, 30), p, 19, MUTED, false, true)
	if won:
		var rewards := ["●\n%d\nOURO" % reward, "◇\n150\nCRISTAIS", "✦\n%d\nESSÊNCIA" % mana]
		for i in range(3):
			var box := _panel(Rect2(65 + i * 207, 146, 185, 145), p, Color("493547"), GOLD)
			_label(rewards[i], Rect2(7, 14, 171, 119), box, 23, GOLD, false, true)
		_label("Dano causado: %s  •  Próxima fase desbloqueada" % _number(int(total_damage)), Rect2(20, 309, 690, 27), p, 17, CREAM, false, true)
	else:
		_label("Evolua seus cavaleiros e aprimore os grimórios.\nA linha de frente protege os magos da retaguarda.", Rect2(40, 163, 650, 110), p, 22, CREAM, false, true)
	_button("Continuar", Rect2(220, 361, 290, 48), func():
		_close_popup()
		_show_page("Campanha")
		if auto_next and won: _start_battle(), p, true)
	if auto_next and won:
		queued_next = true
		get_tree().create_timer(2.5).timeout.connect(func():
			if queued_next and auto_next and not fighting and is_instance_valid(popup):
				queued_next = false
				_close_popup()
				_start_battle())

func _toast(message: String) -> void:
	var p := _panel(Rect2(260, 92, 760, 46), popup_layer, Color("49362b"), GOLD)
	p.z_index = 2000
	_label(message, Rect2(8, 9, 744, 30), p, 17, CREAM, false, true)
	var tw := create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(p.queue_free)

func _help() -> void:
	var p := _open_popup("COMO JOGAR", Vector2(780, 458))
	_label("1. Monte seu time com até cinco cavaleiros em Formação.\n2. Toque em Batalhar: ataques e habilidades são automáticos.\n3. Ative AUTO para avançar pelas fases sem interromper.\n4. Evolua seus heróis e aprimore seus grimórios no salão.\n5. Convoque novos heróis e colete seus ganhos AFK.\n\nAntimagia • Vento • Água • Escuridão • Fogo • Relâmpago", Rect2(35, 92, 710, 260), p, 20)
	_button("Entendi", Rect2(240, 377, 300, 49), _close_popup, p, true)

func _settings() -> void:
	var p := _open_popup("AJUSTES", Vector2(640, 335))
	_label("Progresso salvo automaticamente neste computador.\nArte Chibi 3D pré-renderizada • combate automático", Rect2(30, 92, 580, 82), p, 19, MUTED, false, true)
	_button("Salvar progresso", Rect2(45, 196, 260, 49), func(): _save_game(); _toast("Progresso salvo."), p)
	_button("Voltar", Rect2(335, 196, 260, 49), _close_popup, p, true)

func _process(delta: float) -> void:
	idle_gold = minf((120 + stage * 10) * 480.0, idle_gold + delta * (120 + stage * 10) / 60.0)
	autosave += delta
	if autosave >= 20:
		autosave = 0
		_save_game()
	if is_instance_valid(afk_text): afk_text.text = "●  %s ouro\nACUMULADO" % _number(int(idle_gold))
	if not fighting: return
	battle_time += delta * speed
	beat += delta * speed
	if is_instance_valid(battle_label): battle_label.text = "RODADA %d  •  %02d:%02d" % [round_number, int(battle_time) / 60, int(battle_time) % 60]
	if battle_time >= 120:
		_finish_battle(false)
		return
	if beat >= 0.48:
		beat = 0
		_combat_tick()

func enemy_rank() -> int:
	return stage if battle_kind == "campaign" else activity_rank

func get_player_level() -> int:
	return mini(100, 1 + int(player_xp / 100))

func get_player_progress() -> float:
	return 100.0 if get_player_level() >= 100 else float(player_xp % 100)

func _save_game() -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"gold": gold, "gems": gems, "essence": essence, "stage": stage, "player_xp": player_xp, "levels": levels, "owned": owned, "copies": copies, "equipped": equipped, "team": team, "idle": idle_gold, "time": Time.get_unix_time_from_system()}))

func _load_game() -> void:
	if not FileAccess.file_exists(save_path): return
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary: return
	gold = maxi(0, int(data.get("gold", gold)))
	gems = maxi(0, int(data.get("gems", gems)))
	essence = maxi(0, int(data.get("essence", essence)))
	stage = maxi(1, int(data.get("stage", stage)))
	player_xp = maxi(0, int(data.get("player_xp", (stage - 1) * 75)))
	for key in ["levels", "owned", "copies", "equipped"]:
		var values = data.get(key)
		if values is Array:
			var target: Array = get(key)
			for i in range(mini(values.size(),hero_catalog.count())):
				if key == "levels": target[i]=clampi(int(values[i]),1,100)
				elif key == "copies": target[i]=maxi(0,int(values[i]))
				else: target[i]=bool(values[i])
	team.clear()
	for id in data.get("team", [0, 3, 1, 2, 4]):
		var index := int(id)
		if index >= 0 and index < hero_catalog.count() and owned[index] and not index in team and team.size() < 5: team.append(index)
	if team.is_empty():
		team = [0]
		owned[0] = true
	idle_gold = minf((120 + stage * 10) * 480.0, maxf(0, float(data.get("idle", 0))) + maxf(0, Time.get_unix_time_from_system() - float(data.get("time", Time.get_unix_time_from_system()))) * (120 + stage * 10) / 60.0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_game()

func hero_hp(id: int) -> int:
	return int((850 + int(levels[id])*130)*float(hero_catalog.info(id).hp))

func hero_attack(id: int) -> int:
	return int((95 + int(levels[id])*27)*float(hero_catalog.info(id).attack))

func hero_defense(id: int) -> int:
	return 40 + int(levels[id])*9
