extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value: failures.append(message); push_error(message)
func capture(name: String) -> void:
	await create_timer(0.8).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/layout-"+name+".png")
func run() -> void:
	root.size=Vector2i(1280,720)
	var home=load("res://scenes/premium_home.tscn").instantiate()
	home.game_save_path="user://battle_layout_qa_game.json"
	home.home_save_path="user://battle_layout_qa_profile.json"
	for path in [home.game_save_path,home.home_save_path]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	root.add_child(home)
	await process_frame
	home.game.set_process(false)
	home._route("Formação")
	check(home.landscape_mode,"Formation is landscape")
	await capture("formation")
	home.game.stage=10
	home._start_battle()
	check(home.game.fighting and home.battle_view,"Combat uses full battle view")
	check(not home.hud.visible and home.hud.get_child_count()==0,"Player HUD hidden and removed during combat")
	check(home.navigation.get_child_count()==0,"No dock during battle")
	var controls=home.screen.get_node("BattleControls")
	check(controls.get_child_count()==3,"Only speed, battle and retreat buttons")
	check(not home.screen.has_node("Battle") and not home.screen.has_node("AutoPreference"),"Preparation controls removed")
	for party in [home.game.allies,home.game.foes]:
		check(is_equal_approx(party[0].home.x,party[1].home.x),"Two front units share a column")
		check(is_equal_approx(party[2].home.x,party[3].home.x) and is_equal_approx(party[3].home.x,party[4].home.x),"Three rear units share a column")
		check(party[0].home.x<party[2].home.x if party[0].enemy else party[0].home.x>party[2].home.x,"Front column faces opposing side")
		check(party[2].home.y>=350,"Rear units stand on floor")
	var speed:int=home.game.speed
	controls.get_node("Speed").pressed.emit()
	check(home.game.speed!=speed,"Speed control switches 1x and 2x")
	await capture("boss-fight")
	for i in range(3):
		var texture: Texture2D=load("res://assets/encounters/bosses-0%d-clean.png" % (i+1))
		var image:=texture.get_image()
		check(image.get_pixel(0,0).a<0.01,"Boss atlas has real transparent alpha")
	controls.get_node("Retreat").pressed.emit()
	check(not home.game.fighting and not home.battle_view and not home.landscape_mode and home.hud.visible,"Retreat restores portrait home and HUD")
	for path in [home.game_save_path,home.home_save_path]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if failures.is_empty(): print("BATTLE_LAYOUT_QA: PASS")
	else: print("BATTLE_LAYOUT_QA: FAIL ",failures)
	quit(0 if failures.is_empty() else 1)
