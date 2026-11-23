extends SceneTree
const Layout = preload("res://scripts/visuals/idle_layout.gd")
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func frames(count: int = 3) -> void:
	for i in range(count): await process_frame
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
	await frames(5)
	var manager: Node = scene.get("battle_manager")
	var actors: Array = manager.get("player_team") + manager.get("enemy_team")
	check(actors.size() == 10, "ten units spawned")
	var original: Dictionary = {}
	for actor in actors:
		actor.set_process(false)
		original[actor.get_instance_id()] = {"data": actor.data.duplicate(true), "home": actor.home_position}
	var presentation: Node = scene.get_node("ArenaPresentation")
	for spec in [Vector2i(540, 960), Vector2i(390, 844), Vector2i(480, 960), Vector2i(600, 1000)]:
		view.size = spec
		var logical := Vector2i(1080, roundi(1080.0 * spec.y / spec.x))
		view.size_2d_override = logical
		await frames(5)
		var bounds: Array[Rect2] = []
		for actor in actors:
			var visual: Node2D = actor.visual
			var rect: Rect2 = visual.get_rest_bounds()
			check(Rect2(Vector2.ZERO, Vector2(logical)).encloses(rect), "sprite in viewport " + str(spec) + actor.hero_id)
			check(rect.end.y < presentation.hud_bottom - 12, "clear of cards " + actor.hero_id)
			check(rect.position.y > presentation.hud_top, "clear of header " + actor.hero_id)
			check(actor.data == original[actor.get_instance_id()].data, "stats preserved")
			check(actor.home_position == original[actor.get_instance_id()].home, "logical home preserved")
			check(is_equal_approx(visual.scale.x, visual.scale.y), "uniform sprite scaling")
			bounds.append(rect)
		for i in range(bounds.size()):
			for j in range(i + 1, bounds.size()):
				check(not bounds[i].intersects(bounds[j]), "rest overlap " + str(i) + "/" + str(j) + " " + str(spec))
		for enemy in [false, true]:
			var team: Array = manager.enemy_team if enemy else manager.player_team
			for i in range(5):
				var target := Layout.anchor(Vector2(logical), i, enemy)
				check(team[i].visual.global_position.distance_to(target) < 0.1, "slot " + str(i))
		check(presentation.special.get_global_rect().end.y <= logical.y, "special safe area")
		check(presentation.footer.position.y > bounds[4].end.y, "footer separation")
		check(presentation.camera.zoom == Vector2.ONE, "stable rest camera")
		await RenderingServer.frame_post_draw
		view.get_texture().get_image().save_png("res://artifacts/idle-redesign/formation-%dx%d.png" % [spec.x, spec.y])
	var first: Node = actors[0]
	var visual: Node = first.visual
	var rest: Vector2 = visual.global_position
	visual.play("attack")
	await create_timer(0.16).timeout
	check(visual.rig.position.x > 0, "short approach at impact")
	check(presentation.camera.zoom == Vector2.ONE, "basic attack never zooms")
	await create_timer(0.6).timeout
	check(visual.rig.position.length() < 3, "return to formation")
	check(visual.global_position.distance_to(rest) < 0.1, "root stays in fixed slot")
	visual.play("skill")
	await create_timer(0.12).timeout
	check(presentation.cinematic_active, "special cinematic event")
	check(presentation.camera.zoom.x > 1 and presentation.camera.zoom.x < 1.05, "bounded cinematic zoom")
	manager.toggle_pause()
	await frames()
	var clock: float = presentation.cinematic_age
	var pose: float = visual.anim_player.current_animation_position
	await create_timer(0.1).timeout
	check(is_equal_approx(presentation.cinematic_age, clock), "paused cinematic")
	check(is_equal_approx(visual.anim_player.current_animation_position, pose), "paused animation")
	manager.toggle_pause()
	manager.set_speed(2)
	await frames()
	check(is_equal_approx(visual.anim_player.speed_scale, 2), "2x visual speed")
	await create_timer(0.6).timeout
	check(presentation.camera.zoom == Vector2.ONE, "camera restored after special")
	visual.play("ultimate")
	await create_timer(0.12).timeout
	check(presentation.cinematic_ultimate, "ultimate visual entry")
	await create_timer(0.7).timeout
	check(presentation.camera.zoom == Vector2.ONE, "ultimate camera restored")
	actors[1].visual.play("death")
	actors[1].visual.return_to_idle()
	check(actors[1].visual.current_state == actors[1].visual.AnimState.DEATH, "death pose protected")
	manager.battle_ended.emit(true)
	await frames()
	check(first.visual.current_state == first.visual.AnimState.VICTORY, "victory event")
	scene.get("battle_ui").get("restart_btn").pressed.emit()
	await frames(5)
	check(get_nodes_in_group("battle_units").size() == 10, "restart 5v5")
	check(presentation.cards.size() == 5, "restart cards")
	check(presentation.elapsed < 1, "restart clock")
	check(not scene.get("battle_ui").get("result_panel").visible, "restart closes result")
	view.size = Vector2i(810, 1440)
	view.size_2d_override = Vector2i(1080, 1920)
	await create_timer(1.8).timeout
	await RenderingServer.frame_post_draw
	check(presentation.header.is_visible_in_tree(), "team header visible after restart")
	view.get_texture().get_image().save_png("res://artifacts/idle-redesign/combat.png")
	print("IDLE_QA: ", "PASS" if failures.is_empty() else "FAIL", " | failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
