extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, detail: String) -> void:
	if not value: failures.append(detail); push_error(detail)
func capture(name: String) -> void:
	await create_timer(0.8).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/roster-"+name+".png")
func run() -> void:
	root.size=Vector2i(720,1280)
	var home=load("res://scenes/premium_home.tscn").instantiate()
	home.game_save_path="user://roster_qa_game.json"
	home.home_save_path="user://roster_qa_home.json"
	for path in [home.game_save_path,home.home_save_path]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	# A genuine old-format six-hero save must migrate without losing its values.
	var old_save=FileAccess.open(home.game_save_path,FileAccess.WRITE)
	old_save.store_string(JSON.stringify({"gold":12345,"gems":9000,"levels":[12,10,8,6,4,2],"owned":[true,true,true,true,true,true],"copies":[3,2,1,0,0,0],"equipped":[true,false,false,false,false,false],"team":[0,1,2,3,4],"stage":12}))
	old_save.close()
	root.add_child(home)
	await process_frame
	home.game.set_process(false)
	var game=home.game
	var catalog=game.hero_catalog
	check(catalog.count()==106 and game.NAMES.size()==106,"Exactly 100 additions, original six IDs unchanged")
	check(game.levels.size()==106 and game.owned.size()==106 and game.copies.size()==106 and game.equipped.size()==106,"All save arrays expanded")
	check(game.gold==12345 and game.levels[0]==12 and game.copies[0]==3 and game.equipped[0] and game.stage==12,"Legacy progress preserved")
	check(not game.owned[105] and game.levels[105]==1,"New heroes begin unowned at level one")
	var counts := {}
	var elements := {}
	var names := {}
	for entry in catalog.data.heroes:
		check(not names.has(entry.name),"Unique hero name")
		names[entry.name]=true
		counts[entry.rarity]=counts.get(entry.rarity,0)+1
		elements[entry.element]=elements.get(entry.element,0)+1
		var texture: AtlasTexture=catalog.texture(entry.id,game.atlas)
		check(texture.atlas!=null and texture.region.end.x<=texture.atlas.get_width()+0.1 and texture.region.end.y<=texture.atlas.get_height()+0.1,"Valid sprite cell: "+entry.name)
	for i in range(4): check(int(counts[catalog.data.rarities[i]])==[20,30,30,20][i],"Rarity counts")
	for key in elements: check(elements[key]==10,"Ten new heroes per element")
	var rng := RandomNumberGenerator.new()
	rng.seed=394827
	var rolls := {}
	var seen := {}
	for i in range(30000):
		var id: int=catalog.roll(rng)
		seen[id]=true
		var rarity: String=catalog.info(id).rarity
		rolls[rarity]=rolls.get(rarity,0)+1
	check(seen.size()==106,"Every hero is obtainable from real weighted pool")
	for key in rolls: check(absf(float(rolls[key])/300.0-float(catalog.data.summon_weights[key]))<1.3,"Advertised summon probability: "+str(key))
	home.roster.rarity=3
	home.roster.element=9
	check(home.roster.ids().size()==3,"Rarity and element filters intersect, including original Asta")
	home._route("Heróis")
	await capture("filtered")
	home.roster.rarity=-1
	home.roster.element=-1
	home.roster.pages.heroes=17
	home.selected=105
	home._route("Heróis")
	check(home.screen.has_node("RosterHero105"),"Last hero reachable through collection pagination")
	await capture("last-page")
	game.owned[105]=true
	game.copies[105]=3
	home._fuse_selected()
	check(game.levels[105]==4 and game.copies[105]==0,"Fusion supports last new hero")
	home._equip()
	check(game.equipped[105],"New hero can equip grimoire")
	home._choose_formation(105)
	check(105 in game.team and game.team.size()==5,"New hero enters existing five-slot formation")
	home.avatar_page=17
	home._profile()
	home.popup.get_child(1).get_node("AvatarChoice105").pressed.emit()
	check(home.state.avatar==105,"New hero selectable as avatar")
	home._close()
	home._load_home()
	check(home.state.avatar==105,"New avatar survives reload")
	home._route("Evolução")
	await capture("evolution")
	for id in [6,13,25,65,105]: game.owned[id]=true
	game.team=[6,13,25,65,105]
	home._route("Início")
	root.size=Vector2i(1280,720)
	await process_frame
	home._start_battle()
	check(game.allies.size()==5 and game.allies[4].hero_id==105,"New characters spawn as playable units")
	for unit in game.allies:
		check(unit.body.texture!=null and unit.combat_element>=0 and unit.combat_element<6,"New hero art and attack VFX")
		unit.energy=100
	await capture("combat-ready")
	for i in range(10):
		if game.fighting: game._combat_tick()
	await capture("combat")
	game.fighting=false
	game._save_game()
	game.owned[105]=false
	game._load_game()
	check(game.owned[105] and 105 in game.team and game.levels[105]==4,"Expanded roster and formation persist")
	for path in [home.game_save_path,home.home_save_path]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if failures.is_empty(): print("ROSTER_QA: PASS - 100 new heroes, 4 rarities, 10 elements, migration, draws, filters, team, avatar and combat")
	else: print("ROSTER_QA: FAIL ", failures)
	quit(0 if failures.is_empty() else 1)
