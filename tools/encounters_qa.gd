extends SceneTree
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func capture(name: String) -> void:
	await create_timer(0.2).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/encounter-"+name+".png")

func run() -> void:
	root.size = Vector2i(1280,720)
	var home = load("res://scenes/premium_home.tscn").instantiate()
	home.game_save_path="user://encounter_qa_game.json"
	home.home_save_path="user://encounter_qa_home.json"
	for path in [home.game_save_path,home.home_save_path]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	root.add_child(home)
	await process_frame
	home.game.set_process(false)
	var catalog = home.activities.encounters
	check(catalog.data.enemies.size()==100,"100 enemies")
	check(catalog.data.bosses.size()==30,"30 bosses")
	check(catalog.data.scenes.size()==40,"40 environments")
	for category in ["enemies","bosses","scenes"]:
		var names := {}
		for entry in catalog.data[category]:
			check(not names.has(entry.name),"Unique name: "+entry.name)
			names[entry.name]=true
			var texture: AtlasTexture = catalog.texture(entry)
			check(texture!=null and texture.atlas!=null,"Real image: "+entry.name)
			check(texture.region.end.x<=texture.atlas.get_width()+0.1 and texture.region.end.y<=texture.atlas.get_height()+0.1,"Atlas bounds: "+entry.name)
	for mode in ["Campanha","Torre Infinita"]:
		var enemies_seen := {}
		var bosses_seen := {}
		var scenes_seen := {}
		var cadence: int=catalog.interval(mode,"boss")
		for rank in range(1,401):
			var wave: Array=catalog.lineup(mode,rank)
			check(wave.size()==5,"Five opponents at every rank")
			check(catalog.is_boss(mode,rank)==(rank%cadence==0),"Boss cadence")
			check(wave==catalog.lineup(mode,rank),"Deterministic encounter")
			for i in range(wave.size()):
				if catalog.is_boss(mode,rank) and i==0: bosses_seen[wave[i].id]=true
				else: enemies_seen[wave[i].id]=true
			scenes_seen[catalog.scene_info(mode,rank).id]=true
		check(enemies_seen.size()==100,"All regular enemies reachable: "+mode)
		check(bosses_seen.size()==30,"All bosses reachable: "+mode)
		check(scenes_seen.size()==40,"All scenery reachable: "+mode)
	for rank in [1,10,11,100,300,391]:
		home.game.fighting=false
		home.active_activity="Campanha"
		home.game.battle_kind="campaign"
		home.game.stage=rank
		home._start_battle()
		check(home.game.foes.size()==5,"Actual spawn at rank "+str(rank))
		for enemy in home.game.foes:
			check(enemy.has_meta("encounter_id"),"Enemy uses catalog art")
			check(enemy.hp>0 and enemy.attack_modifier>0,"Valid combat stats")
			check(enemy.body.position==Vector2.ZERO,"Feet remain grounded")
		check(bool(home.game.foes[0].get_meta("boss"))==catalog.is_boss("Campanha",rank),"Actual boss spawn")
		# Each resting sprite plus its health bar must occupy its own space.
		for party in [home.game.allies,home.game.foes]:
			for a in range(party.size()):
				for b in range(a+1,party.size()):
					var first = party[a]
					var second = party[b]
					var first_width: float=first.body.texture.get_width()*first.body.scale.x
					var second_width: float=second.body.texture.get_width()*second.body.scale.x
					var first_box := Rect2(first.home-Vector2(first_width*.5,first.height+12),Vector2(first_width,first.height+12))
					var second_box := Rect2(second.home-Vector2(second_width*.5,second.height+12),Vector2(second_width,second.height+12))
					check(not first_box.intersects(second_box),"Sprites and bars have separate resting space")
		await capture("campaign-"+str(rank))
		home.game._combat_tick()
		home.game._combat_tick()
	home.game.fighting=false
	home._route("Início")
	home.state.tower_floor=5
	home.activities.launch("Torre Infinita")
	check(home.game.foes[0].get_meta("boss"),"Tower boss at floor 5")
	await capture("tower-5")
	var before_stage:int=home.game.stage
	for enemy in home.game.foes: enemy.alive=false
	home.game._combat_tick()
	check(home.state.tower_floor==6 and home.game.stage==before_stage,"Tower victory advances only tower")
	for path in [home.game_save_path,home.home_save_path]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if failures.is_empty(): print("ENCOUNTERS_QA: PASS - 100 enemies, 30 bosses, 40 scenes, both progressions")
	else: print("ENCOUNTERS_QA: FAIL ",failures)
	quit(0 if failures.is_empty() else 1)
