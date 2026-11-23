extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
func capture(name: String) -> void:
	await create_timer(0.18).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/idle-clover-" + name + ".png")
func _run() -> void:
	var game = load("res://main.tscn").instantiate()
	game.save_path = "user://clover_idle_qa.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path))
	root.add_child(game)
	await process_frame
	game.set_process(false)
	check(game.allies.size() == 5, "Five starting heroes")
	await capture("campaign")
	game._show_page("Heróis")
	await capture("heroes")
	var previous_level: int = game.levels[0]
	var previous_gold: int = game.gold
	game._upgrade()
	check(game.levels[0] == previous_level + 1, "Upgrade adds one level")
	check(game.gold == previous_gold - previous_level * 100, "Upgrade resource debit")
	game._equip()
	check(game.equipped[0], "Equipment upgrade")
	await create_timer(3.0).timeout
	game._show_page("Convocação")
	await capture("summon-room")
	var previous_gems: int = game.gems
	game._summon(10)
	await create_timer(1.5).timeout
	check(game.gems == previous_gems - 3000, "Ten summons cost 3000")
	check(game.copies.reduce(func(a, b): return a + b, 0) >= 9, "Duplicate accounting")
	await capture("summon-results")
	game._close_popup()
	game._show_page("Mapa")
	await capture("map")
	game._show_page("Inventário")
	await capture("inventory")
	game._show_page("Campanha")
	game._formation()
	var formation_panel = game.popup.get_child(1)
	var formation_buttons = formation_panel.get_children().filter(func(n): return n is Button)
	formation_buttons[6].pressed.emit()
	check(game.team[0] == 1 and game.team.count(0) == 1 and game.team.count(1) == 1, "Formation swaps heroes without duplication")
	await capture("formation")
	game._close_popup()
	game.idle_gold = 120
	var before_claim: int = game.gold
	game._claim()
	check(game.gold == before_claim + 120, "AFK claim")
	game._close_popup()
	game._start_battle()
	check(game.allies.size() == 5 and game.foes.size() == 5, "Five versus five")
	game._process(0.01)
	for i in range(9):
		game._combat_tick()
		await create_timer(0.04).timeout
	await capture("battle")
	var previous_stage: int = game.stage
	for i in range(450):
		if not game.fighting: break
		game._combat_tick()
	check(not game.fighting, "Battle terminates")
	check(game.stage == previous_stage + 1, "Starting battle is winnable and unlocks next stage")
	await capture("victory")
	game._close_popup()
	game._show_page("Campanha")
	game._start_battle()
	for unit in game.allies: unit.alive = false
	var before_loss: int = game.stage
	game._combat_tick()
	check(not game.fighting and game.stage == before_loss, "Loss grants no phase advancement")
	game._close_popup()
	game._save_game()
	var saved_gold: int = game.gold
	game.gold = 0
	game._load_game()
	check(game.gold == saved_gold, "Save reload roundtrip")
	game._show_page("Campanha")
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path))
	print("CLOVER_IDLE_QA: ", "PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
