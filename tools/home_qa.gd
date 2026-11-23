extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)
func capture(name: String) -> void:
	await create_timer(0.22).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/home-" + name + ".png")
func click_at(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event)
		await process_frame
func _run() -> void:
	root.size = Vector2i(720, 1280)
	var home = load("res://scenes/premium_home.tscn").instantiate()
	home.game_save_path = "user://home_qa_game.json"
	home.home_save_path = "user://home_qa_profile.json"
	for path in [home.game_save_path, home.home_save_path]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	root.add_child(home)
	await process_frame
	home.game.set_process(false)
	check(home.current_page == "Início", "Portrait home is the entry point")
	check(home.nav_buttons.size() == 5, "Five primary navigation buttons")
	check(home.hud.has_node("PlayerCard"), "Premium profile card is present")
	check(home.player_card.level_label.text == "Nv. %d" % home.game.get_player_level(), "Profile shows player level")
	check(home.player_card.vip_label.text == "VIP %d" % int(home.state.vip), "Profile shows saved VIP")
	check(home.screen.has_node("Campanha") and home.screen.has_node("Invocação"), "Landmark routes exist")
	await capture("premium")
	home._profile()
	await capture("profile")
	var profile_panel = home.popup.get_child(1)
	profile_panel.get_node("AvatarChoice1").pressed.emit()
	check(home.state.avatar == 1, "Owned hero can become the avatar")
	home._load_home()
	check(home.state.avatar == 1, "Avatar selection persists")
	profile_panel.get_node("AvatarChoice0").pressed.emit()
	home._close()
	await click_at(Vector2(130, 658))
	check(home.current_page == "Invocação", "Real pointer input opens summoning portal")
	home._route("Início")
	await click_at(home.nav_buttons[2].get_global_rect().get_center())
	check(home.current_page == "Formação", "Real pointer input opens bottom formation navigation")
	for route in ["Heróis", "Bag", "Formação", "Evolução", "Missões", "Conquistas", "Loja", "Mercado", "Invocação", "Fusão", "Torre Infinita", "Arena", "Clã", "Batalha de Chefes"]:
		home._route(route)
		await process_frame
		check(home.current_page == route, "Route " + route)
		if route in ["Heróis", "Formação", "Invocação"]: await capture(route)
	home._route("Heróis")
	var before_level: int = home.game.levels[0]
	var account_level: int = home.game.get_player_level()
	home._evolve()
	check(home.game.levels[0] == before_level + 1, "Portrait evolution uses existing roster")
	check(home.game.get_player_level() == account_level, "Hero leveling does not change player level")
	home._route("Invocação")
	var before_gems: int = home.game.gems
	home._summon(10)
	check(home.game.gems == before_gems - 3000, "Summon debits real diamonds")
	await create_timer(1.2).timeout
	await capture("summon-results")
	home._close()
	home._route("Início")
	home._events()
	var event_button = home.screen.find_child("WelcomeClaim",true,false)
	var before_event: int = home.game.gems
	event_button.pressed.emit()
	check(home.state.welcome and home.game.gems == before_event + 300, "Welcome gift grants once")
	home._events()
	check(home.game.gems == before_event + 300, "Welcome gift cannot repeat")
	home._close()
	home._checkin()
	var checkin_button = home.screen.get_node("ClaimCheckin")
	var before_checkin: int = home.game.gems
	checkin_button.pressed.emit()
	check(home.game.gems == before_checkin + 200, "Daily check-in reward")
	home._checkin()
	check(home.game.gems == before_checkin + 200, "Daily check-in cannot repeat")
	home._close()
	home.game.idle_gold = 120
	var before_afk: int = home.game.gold
	home._claim_afk()
	home.screen.get_node("ClaimAFK").pressed.emit()
	check(home.game.gold == before_afk + 120, "AFK resource accounting")
	home._close()
	root.size = Vector2i(1280, 720)
	await process_frame
	home._route("Campanha")
	check(home.landscape_mode and root.content_scale_size == Vector2i(1280, 720), "Campaign selects landscape design")
	home._start_battle()
	check(home.game.allies.size() == 5 and home.game.foes.size() == 5, "Portrait five versus five")
	home._route("Campanha")
	check(home.game.foes.size() == 5 and home.game.fighting, "Navigation cannot reset an active battle")
	home._close()
	for i in range(8): home.game._combat_tick()
	await capture("battle")
	var before_stage: int = home.game.stage
	var before_xp: int = home.game.player_xp
	for i in range(700):
		if not home.game.fighting: break
		home.game._combat_tick()
	check(not home.game.fighting and home.game.stage == before_stage + 1, "Existing combat resolves portrait victory")
	check(home.game.player_xp == before_xp + 75, "Campaign grants account experience")
	home.game._load_game()
	check(home.game.player_xp == before_xp + 75, "Account experience persists")
	await capture("victory")
	home._close()
	home._route("Início")
	check(not home.landscape_mode and root.content_scale_size == Vector2i(720, 1280), "Leaving campaign restores portrait design")
	for usable in [Vector2i(1366, 728), Vector2i(1920, 1040), Vector2i(800, 560)]:
		var fitted: Vector2i = home._desktop_size(usable, Vector2i(16, 39))
		check(fitted.y + 39 + 40 <= usable.y and fitted.x + 16 + 32 <= usable.x, "Desktop window fits usable monitor " + str(usable))
	# Wider and taller windows must keep every navigation item inside the viewport.
	for resolution in [Vector2i(720, 1600), Vector2i(960, 1280), Vector2i(360, 640), Vector2i(559, 741)]:
		root.size = resolution
		await process_frame
		home._resize()
		check(home.ui.position.x >= -0.1 and home.ui.position.y >= -0.1, "Centered safe layout " + str(resolution))
		var edge: Vector2 = home.ui.position + Vector2(720, 1280) * home.ui.scale
		var viewport_size: Vector2 = root.get_visible_rect().size
		check(edge.x <= viewport_size.x + 0.1 and edge.y <= viewport_size.y + 0.1, "Full interface stays visible " + str(resolution))
	root.size = Vector2i(720, 1280)
	await process_frame
	await capture("premium")
	for path in [home.game_save_path, home.home_save_path]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("HOME_QA: ", "PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
