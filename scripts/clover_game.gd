extends Node3D
## Playable landscape prototype. Geometry-built chibi models, no external assets.
const NAMES = ["Asta", "Yuno", "Noelle", "Yami", "Magna", "Luck"]
const ELEMENTS = ["ANTIMAGIA", "VENTO", "ÁGUA", "ESCURIDÃO", "FOGO", "RELÂMPAGO"]
const COLORS = [Color("ed667c"), Color("65ddb2"), Color("80d5fa"), Color("ae8ce9"), Color("ff9761"), Color("ffe58a")]
var gold := 5000
var gems := 3000
var stage := 1
var levels := [1, 1, 1, 1, 1, 1]
var owned := [true, true, true, false, false, false]
var team: Array = [0, 1, 2]
var actors: Array[Node3D] = []
var ui: Control
var modal: Panel
var status: Label
var page := "Campanha"
var fighting := false
var speed := 1
var clock := 0.0
var hp := 100.0
var enemy_hp := 100.0
var turn := 0.0
var bars: Label
var selected := 0
var idle_gold := 0.0
var save_path := "user://clover_chibi.json"

func _ready() -> void:
	_load_game()
	_build_world()
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(ui)
	_show_page("Campanha")

func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.75
	return m

func _mesh(parent: Node3D, shape: Mesh, pos: Vector3, color: Color, size := Vector3.ONE) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = shape
	n.material_override = _material(color)
	n.position = pos
	n.scale = size
	parent.add_child(n)
	return n

func _ball(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	return _mesh(parent, SphereMesh.new(), pos, color, size)

func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	return _mesh(parent, BoxMesh.new(), pos, color, size)

func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("9cc9c8")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("b8c9ec")
	e.ambient_light_energy = 0.65
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -30, 0)
	sun.light_color = Color("fff0cb")
	sun.light_energy = 1.7
	sun.shadow_enabled = true
	add_child(sun)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 10, 16)
	add_child(camera)
	camera.look_at(Vector3(0, 0.7, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 18.5
	_box(self, Vector3(0, -0.55, 0), Vector3(32, 1, 22), Color("497e63"))
	var arena := CylinderMesh.new()
	arena.top_radius = 6.5
	arena.bottom_radius = 7.1
	arena.height = 0.35
	_mesh(self, arena, Vector3(0, 0, 0), Color("acac83"))
	var inset := CylinderMesh.new()
	inset.top_radius = 6.2
	inset.bottom_radius = 6.2
	inset.height = 0.08
	_mesh(self, inset, Vector3(0, 0.21, 0), Color("739b78"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 82
	for i in range(30):
		var x := rng.randf_range(-15, 15)
		var z := rng.randf_range(-10, 6)
		if absf(x) < 7 and z > -5: continue
		_box(self, Vector3(x, 1, z), Vector3(0.4, 2.4, 0.4), Color("645747"))
		_ball(self, Vector3(x, 3, z), Vector3(3, 2.8, 3), Color("305e53"))
	for x in [-7.2, 7.2]:
		for z in [-4.0, 2.0]:
			_box(self, Vector3(x, 1.6, z), Vector3(0.7, 3.5, 0.7), Color("b3b49a"))
			_ball(self, Vector3(x, 3.5, z), Vector3(0.9, 0.8, 0.9), Color("f5d382"))

func _hero(id: int, pos: Vector3, enemy := false) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	root.position = pos
	var skin := Color("f5c6a5")
	var hair: Color = [Color("d4d9df"), Color("202833"), Color("dce3ef"), Color("25252c"), Color("b5baca"), Color("ecd58a")][id]
	var coat: Color = Color("e5dce3") if id == 2 else Color("202d3e")
	_ball(root, Vector3(0, 0.98, 0), Vector3(0.92, 0.87, 0.65), coat)
	_box(root, Vector3(0, 1.08, -0.24), Vector3(1.12, 0.72, 0.14), Color("272634"))
	for x in [-0.24, 0.24]:
		_box(root, Vector3(x, 0.43, 0), Vector3(0.29, 0.55, 0.32), Color("41465b"))
		_ball(root, Vector3(x, 0.24, 0.12), Vector3(0.4, 0.3, 0.55), Color("202737"))
		_ball(root, Vector3(x * 2.25, 1.02, 0), Vector3(0.3, 0.48, 0.3), skin)
	_ball(root, Vector3(0, 1.91, 0), Vector3(1.3, 1.23, 1.12), skin)
	_ball(root, Vector3(0, 2.23, -0.04), Vector3(1.34, 0.82, 1.15), hair)
	for j in range(7):
		var spike := PrismMesh.new()
		var n := _mesh(root, spike, Vector3(-0.55 + j * 0.18, 2.58 + sin(j * 2.0) * 0.09, 0.01), hair, Vector3(0.28, 0.5, 0.6))
		n.rotation.z = (j - 3) * -0.12
	for x in [-0.25, 0.25]:
		_ball(root, Vector3(x, 1.94, 0.51), Vector3(0.29, 0.33, 0.12), Color.WHITE)
		_ball(root, Vector3(x, 1.93, 0.57), Vector3(0.16, 0.23, 0.07), COLORS[id])
		_ball(root, Vector3(x, 1.93, 0.6), Vector3(0.07, 0.16, 0.04), Color("182635"))
	_box(root, Vector3(0, 1.64, 0.53), Vector3(0.13, 0.025, 0.03), Color("9b605a"))
	_box(root, Vector3(0, 1.23, 0.34), Vector3(0.18, 0.21, 0.06), Color("e8c477"))
	if id == 0 or id == 4:
		_box(root, Vector3(0, 2.2, 0.53), Vector3(1.22, 0.16, 0.07), Color("242934"))
	if id == 0 or id == 3:
		var sword := _box(root, Vector3(-0.8, 1.0, 0.24), Vector3(0.24 if id == 3 else 0.42, 1.85, 0.12), Color("343c4d"))
		sword.rotation.z = -0.3
		_box(root, Vector3(-0.56, 0.65, 0.24), Vector3(0.65, 0.1, 0.17), Color("d8b977"))
	else:
		_ball(root, Vector3(-0.78, 1.4, 0.35), Vector3(0.48, 0.48, 0.48), COLORS[id])
	if id == 2:
		for x in [-0.75, 0.75]:
			_ball(root, Vector3(x, 1.92, -0.05), Vector3(0.47, 0.95, 0.5), hair)
	if enemy: root.rotation.y = -0.28
	else: root.rotation.y = 0.22
	actors.append(root)
	return root

func _style(bg: Color, border := Color("bfa575")) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(14)
	return s

func _label(text: String, rect: Rect2, font_size := 22, color := Color("f5e8c8"), parent: Control = ui) -> Label:
	var l := Label.new()
	l.text = text
	l.position = rect.position
	l.size = rect.size
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l

func _button(text: String, rect: Rect2, action: Callable, parent: Control = ui, accent := false) -> Button:
	var b := Button.new()
	b.text = text
	b.position = rect.position
	b.size = rect.size
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_stylebox_override("normal", _style(Color("af713d") if accent else Color("233d40")))
	b.add_theme_stylebox_override("hover", _style(Color("647965")))
	b.add_theme_stylebox_override("pressed", _style(Color("96744c")))
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func _show_page(next: String) -> void:
	page = next
	for child in ui.get_children(): child.queue_free()
	for actor in actors: actor.queue_free()
	actors.clear()
	modal = null
	var top := Panel.new()
	top.position = Vector2(24, 18)
	top.size = Vector2(1232, 76)
	top.add_theme_stylebox_override("panel", _style(Color("152c32")))
	ui.add_child(top)
	_label("♣  C L O V E R", Rect2(45, 25, 400, 34), 28)
	_label("CRÔNICAS DOS CAVALEIROS", Rect2(48, 61, 400, 24), 12, Color("b9c9bb"))
	status = _label("", Rect2(760, 37, 450, 35), 22)
	_update_status()
	_label("REINO DE CLOVER  /  " + page.to_upper(), Rect2(45, 114, 650, 30), 17)
	for i in range(4):
		var title: String = ["Campanha", "Heróis", "Convocação", "Mapa"][i]
		_button(title, Rect2(36 + i * 310, 644, 294, 54), func():
			if not fighting: _show_page(title), ui, title == page)
	match page:
		"Campanha":
			_label("Floresta dos Grimórios", Rect2(45, 146, 650, 50), 34)
			_label("CAPÍTULO 01   •   FASE 1–%d" % stage, Rect2(48, 198, 600, 30), 17)
			for i in range(team.size()): _hero(team[i], Vector3(-3.5 + i * 1.8, 0.3, 0.2 + (i % 2) * 0.8))
			_button("Formação", Rect2(45, 564, 220, 54), _formation)
			_button("Coletar ganhos AFK", Rect2(285, 564, 250, 54), _claim)
			_button("BATALHAR  →", Rect2(975, 550, 260, 68), _start_battle, ui, true)
			_label("Seu esquadrão. Seu caminho ao Rei Mago.", Rect2(45, 526, 850, 32), 18)
		"Heróis":
			_hero(selected, Vector3(-3, 0.3, 0.5)).scale = Vector3.ONE * 1.35
			var box := Panel.new()
			box.position = Vector2(760, 150)
			box.size = Vector2(470, 460)
			box.add_theme_stylebox_override("panel", _style(Color("18363b")))
			ui.add_child(box)
			_label(NAMES[selected], Rect2(785, 170, 420, 48), 36, COLORS[selected])
			_label(ELEMENTS[selected] + "   •   ★★★★★", Rect2(785, 222, 420, 32), 18)
			_label("Nível %d\n\nVida       %d\nAtaque   %d\nDefesa    %d" % [levels[selected], 1000 + levels[selected] * 120, 100 + levels[selected] * 25, 50 + levels[selected] * 8], Rect2(785, 275, 420, 210), 23)
			_button("Evoluir • %d ouro" % (levels[selected] * 100), Rect2(785, 524, 420, 54), _upgrade, ui, true).disabled = not owned[selected]
			for i in range(6):
				var id := i
				_button(NAMES[i] + ("" if owned[i] else " ♢"), Rect2(42 + i * 116, 564, 108, 52), func(): selected = id; _show_page("Heróis"))
		"Convocação":
			_label("O chamado do grimório", Rect2(45, 155, 700, 50), 36)
			_label("Um novo cavaleiro aguarda por você.\nCada convocação custa 300 cristais.\nChances iguais para os seis heróis.\nDuplicatas concedem 500 de ouro.", Rect2(48, 224, 650, 150), 22)
			_hero(selected, Vector3(2, 0.3, 0)).scale = Vector3.ONE * 1.3
			_button("CONVOCAR • 300 cristais", Rect2(45, 550, 430, 64), _summon, ui, true)
		"Mapa":
			_label("Jornada pelo Reino", Rect2(45, 155, 700, 50), 36)
			for i in range(6):
				var n := i + 1
				var b := _button("1–%d\n%s" % [n, "Concluída" if n < stage else ("Atual" if n == stage else "Bloqueada")], Rect2(65 + i * 200, 300 + (i % 2) * 65, 170, 110), func(): _show_page("Campanha"))
				b.disabled = n > stage

func _update_status() -> void:
	status.text = "OURO  %s     ◇  %s" % [gold, gems]

func _dialog(title: String, message: String) -> void:
	if is_instance_valid(modal): modal.queue_free()
	modal = Panel.new()
	modal.position = Vector2(360, 190)
	modal.size = Vector2(560, 330)
	modal.add_theme_stylebox_override("panel", _style(Color("173239")))
	ui.add_child(modal)
	_label(title, Rect2(28, 22, 510, 55), 32, Color("f1cf8d"), modal)
	_label(message, Rect2(28, 90, 510, 145), 21, Color("e2e8d9"), modal)
	_button("Continuar", Rect2(140, 250, 280, 54), func(): modal.queue_free(), modal, true)

func _formation() -> void:
	_dialog("Formação do esquadrão", "Selecione até 3 heróis. Os primeiros\nocupam a linha de frente.")
	for i in range(6):
		var id := i
		var b := _button(("✓ " if i in team else "") + NAMES[i], Rect2(22 + (i % 3) * 174, 126 + (i / 3) * 55, 164, 46), func():
			if id in team:
				if team.size() > 1: team.erase(id)
			elif team.size() < 3: team.append(id)
			_save_game()
			_show_page("Campanha")
			_formation(), modal)
		b.disabled = not owned[i]

func _upgrade() -> void:
	if gold < levels[selected] * 100:
		_dialog("Ouro insuficiente", "Vença batalhas ou colete seus ganhos AFK.")
		return
	gold -= levels[selected] * 100
	levels[selected] += 1
	_save_game()
	_show_page("Heróis")

func _summon() -> void:
	if gems < 300:
		_dialog("Cristais insuficientes", "Ganhe mais cristais nas batalhas da campanha.")
		return
	gems -= 300
	selected = randi_range(0, 5)
	var duplicate: bool = owned[selected]
	owned[selected] = true
	if duplicate: gold += 500
	_save_game()
	_show_page("Convocação")
	_dialog("★  " + NAMES[selected] + "  ★", "Grimório de " + ELEMENTS[selected].to_lower() + "!\n" + ("Herói repetido: +500 ouro." if duplicate else "Novo cavaleiro disponível na formação!"))

func _claim() -> void:
	var reward := int(idle_gold)
	gold += reward
	idle_gold -= reward
	_save_game()
	_update_status()
	_dialog("Ganhos AFK", "+%d ouro coletado.\nSeu esquadrão produz 2 de ouro por segundo.\nAcúmulo offline de até 8 horas." % reward)

func _start_battle() -> void:
	_show_page("Campanha")
	fighting = true
	hp = 100
	enemy_hp = 100
	turn = 0
	for i in range(3): _hero((stage + i + 2) % 6, Vector3(2 + i * 1.35, 0.3, -0.5 + (i % 2) * 1.7), true)
	bars = _label("", Rect2(450, 103, 760, 60), 21)
	_button("Velocidade ×1 / ×2", Rect2(975, 478, 260, 54), func(): speed = 2 if speed == 1 else 1)

func _process(delta: float) -> void:
	clock += delta
	idle_gold = minf(57600, idle_gold + delta * 2)
	for i in range(actors.size()):
		if is_instance_valid(actors[i]):
			actors[i].rotation.z = sin(clock * 2.2 + i) * 0.025
			actors[i].position.y = 0.32 + sin(clock * 3 + i) * 0.035
	if not fighting: return
	turn += delta * speed
	bars.text = "ESQUADRÃO  %d%%     •     INIMIGOS  %d%%" % [maxi(0, int(hp)), maxi(0, int(enemy_hp))]
	if turn < 0.9: return
	turn = 0
	var power := 0
	for id in team: power += 8 + levels[id] * 3
	enemy_hp -= power / float(2 + stage * 0.4)
	hp -= 5 + stage * 1.5
	var attacker := actors[randi_range(0, team.size() - 1)]
	var tween := create_tween()
	var origin := attacker.position.x
	tween.tween_property(attacker, "position:x", origin + 0.65, 0.12)
	tween.tween_property(attacker, "position:x", origin, 0.23)
	if enemy_hp <= 0 or hp <= 0:
		fighting = false
		var won := enemy_hp <= 0
		if won:
			gold += 800 + stage * 100
			gems += 150
			stage += 1
		_save_game()
		_show_page("Campanha")
		_dialog("VITÓRIA!" if won else "Esquadrão derrotado", "+%d ouro  •  +150 cristais\nPróxima fase desbloqueada." % (800 + (stage - 1) * 100) if won else "Evolua seus heróis e ajuste sua formação\npara tentar novamente.")

func _save_game() -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"gold": gold, "gems": gems, "stage": stage, "levels": levels, "owned": owned, "team": team, "idle": idle_gold, "time": Time.get_unix_time_from_system()}))

func _load_game() -> void:
	if not FileAccess.file_exists(save_path): return
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary: return
	gold = int(data.get("gold", gold))
	gems = int(data.get("gems", gems))
	stage = int(data.get("stage", stage))
	var saved_levels = data.get("levels", levels)
	var saved_owned = data.get("owned", owned)
	if saved_levels is Array and saved_levels.size() == 6: levels = saved_levels
	if saved_owned is Array and saved_owned.size() == 6: owned = saved_owned
	team.clear()
	for id in data.get("team", [0, 1, 2]):
		var index := int(id)
		if index >= 0 and index < 6 and owned[index] and not index in team and team.size() < 3: team.append(index)
	if team.is_empty(): team = [0]
	idle_gold = minf(57600, float(data.get("idle", 0)) + maxf(0, Time.get_unix_time_from_system() - float(data.get("time", Time.get_unix_time_from_system()))) * 2)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST: _save_game()
