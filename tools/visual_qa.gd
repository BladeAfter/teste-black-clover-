extends SceneTree
var failures: Array[String] = []
func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(540, 960)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	root.add_child(view)
	view.size_2d_override = Vector2i(1080, 1920)
	view.size_2d_override_stretch = true
	var scene := load("res://main.tscn").instantiate() as Node
	
	view.add_child(scene)
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	var manager: Node = scene.get("battle_manager")
	var team: Array = manager.get("player_team")
	check(team.size() == 5 and manager.get("enemy_team").size() == 5, "5v5 spawn")
	check(scene.has_node("ArenaPresentation"), "presentation adapter installed")
	var asta: Node = team[0]
	var visual: Node = asta.get("visual")
	check(visual != null and visual.parts.size() == 5, "Asta articulated layers")
	for unit in team + manager.get("enemy_team"):
		check(unit.get("visual").parts.size() == 5, "articulated hero: " + unit.get("hero_id"))
		unit.set_process(false)
	for state in ["idle", "run", "attack", "skill", "hit"]:
		asta.is_moving = state == "run"
		visual.play(state)
		await create_timer(0.1).timeout
		check(visual.anim_player.current_animation == state or state == "hit", "animation " + state)
	manager.set_speed(2.0)
	await process_frame
	await process_frame
	check(is_equal_approx(visual.anim_player.speed_scale, 2.0), "2x animation speed")
	manager.toggle_pause()
	await process_frame
	await process_frame
	check(is_zero_approx(visual.anim_player.speed_scale), "pause freezes animation")
	manager.toggle_pause()
	manager.set_speed(1.0)
	for size_px in [Vector2i(540, 960), Vector2i(720, 1280)]:
		view.size = size_px
		view.size_2d_override = Vector2i(1080, 1920)
		visual.play("idle")
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var path := "res://artifacts/visual-qa/battle-%dx%d.png" % [size_px.x, size_px.y]
		check(view.get_texture().get_image().save_png(path) == OK, "capture " + path)
	manager.battle_ended.emit(true)
	await process_frame
	await process_frame
	check(visual.current_state == visual.AnimState.VICTORY, "victory event")
	visual.return_to_idle()
	check(visual.current_state == visual.AnimState.VICTORY, "victory protected from stale callback")
	var enemy: Node = manager.get("enemy_team")[0]
	enemy.get("visual").play("death")
	enemy.get("visual").return_to_idle()
	check(enemy.get("visual").current_state == visual.AnimState.DEATH, "death protected from stale callback")
	for unit in team + manager.get("enemy_team"):
		unit.set_process(true)
	await create_timer(1.0).timeout
	manager.reset()
	var ids: Array[String] = ["bc_asta", "bc_yuno", "bc_noelle", "bc_yami", "bc_magna"]
	var enemies: Array[String] = ["bc_luck", "bc_magna", "bc_yami", "bc_noelle", "bc_yuno"]
	manager.start_battle(ids, enemies)
	await create_timer(0.3).timeout
	check(scene.get_node("ArenaPresentation").cards.size() == 5, "restart retains five HUD cards")
	check(scene.get_node("ArenaPresentation").elapsed < 1.0, "restart resets visual clock")
	await create_timer(1.0).timeout
	check(get_nodes_in_group("battle_units").size() == 10, "restart spawns 10 units")
	print("VISUAL_QA: ", "PASS" if failures.is_empty() else "FAIL", " | failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
