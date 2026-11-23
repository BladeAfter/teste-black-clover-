extends SceneTree
var failures: Array[String]=[]
func _initialize() -> void: call_deferred("_run")
func check(value: bool,message: String) -> void:
	if not value: failures.append(message); push_error(message)
func capture(name: String) -> void:
	await create_timer(0.24).timeout
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/activity-"+name+".png")
func _run() -> void:
	root.size=Vector2i(720,1280)
	var home=load("res://scenes/premium_home.tscn").instantiate()
	home.game_save_path="user://activity_qa_game.json"
	home.home_save_path="user://activity_qa_home.json"
	for path in [home.game_save_path,home.home_save_path]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	root.add_child(home)
	await process_frame
	home.game.set_process(false)
	var pages=["Torre Infinita","Arena","Clã","Batalha de Chefes","Eventos","Recompensas","Check-in","Passe de Jornada","Correio","Configurações","Evolução","Equipamento"]
	for i in range(pages.size()):
		home._route(pages[i])
		check(home.current_page==pages[i],"Activity route: "+pages[i])
		await capture(str(i))
	# New economy actions are atomic and cannot be repeatedly claimed.
	home._route("Clã")
	var before_gold:int=home.game.gold
	home.activities.create_clan("Touros de Teste")
	check(home.state.clan_name=="Touros de Teste" and home.game.gold==before_gold-1000,"Clan foundation consumes gold")
	home.activities.create_clan("Duplicate")
	check(home.game.gold==before_gold-1000,"Clan cannot be founded twice")
	home.activities.donate_clan()
	var after_donation:int=home.game.gold
	home.activities.donate_clan()
	check(home.game.gold==after_donation and home.state.clan_xp==50,"Daily clan donation cannot repeat")
	home.activities.claim_clan()
	var after_claim:int=home.game.gems
	home.activities.claim_clan()
	check(home.game.gems==after_claim,"Clan treasure cannot repeat")
	await capture("clan-created")
	home._route("Passe de Jornada")
	var initial_gems:int=home.game.gems
	home.activities.claim_pass(2)
	check(home.game.gems==initial_gems,"Pass requires campaign milestone")
	home.game.stage=3
	home.activities.claim_pass(2)
	check(home.game.gems==initial_gems+100,"Pass milestone awards exact gems")
	home.activities.claim_pass(2)
	check(home.game.gems==initial_gems+100,"Pass reward cannot repeat")
	# Tower progression never advances campaign or grants duplicate campaign loot.
	var campaign:int=home.game.stage
	home.activities.launch("Torre Infinita")
	for foe in home.game.foes: foe.alive=false
	home.game._combat_tick()
	check(home.state.tower_floor==2 and home.game.stage==campaign,"Tower and campaign progress are independent")
	home._close()
	home._route("Arena")
	home.state.arena_attempts=4
	home.activities.launch("Arena")
	for ally in home.game.allies: ally.alive=false
	home.game._combat_tick()
	check(home.state.arena_attempts==5 and home.state.arena_rating==985,"Arena loss and daily accounting")
	home._close()
	home.activities.launch("Arena")
	check(not home.game.fighting,"Arena daily limit enforced")
	home._close()
	home._route("Batalha de Chefes")
	home.activities.launch("Batalha de Chefes")
	check(home.game.foes.size()==1,"Boss is one raid target")
	check(home.game.foes[0].body.texture.resource_path.ends_with("boss-dragon.png"),"Boss uses generated dragon art")
	home.game.total_damage=1000
	for ally in home.game.allies: ally.alive=false
	home.game._combat_tick()
	check(home.state.boss_damage==1000 and home.game.stage==campaign,"Boss damage persists without advancing campaign")
	home._close()
	home.activities.launch("Batalha de Chefes")
	check(is_equal_approx(home.game.foes[0].hp,home.activities.boss_max_hp()-1000),"Boss remaining health carries to retry")
	root.size=Vector2i(1280,720)
	await process_frame
	# Render every generated attack row, including normal and special overlays.
	for id in range(6):
		var fx=load("res://scripts/visuals/combat_sprite_fx.gd").spawn(home.game.effects,id,Vector2(450,245),Vector2(850,245),true)
		fx._process(0.34)
	await capture("boss-combat")
	home.game.total_damage=999999
	for foe in home.game.foes: foe.alive=false
	home.game._combat_tick()
	check(home.state.boss_level==2 and home.state.boss_damage==0,"Boss victory opens next level")
	check(home.game.stage==campaign,"Activity victories never advance campaign")
	home._close()
	home._route("Início")
	home._save_home()
	home.state.tower_floor=1
	home._load_home()
	check(home.state.tower_floor==2,"Activity progress reloads from save")
	for path in [home.game_save_path,home.home_save_path]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("ACTIVITY_QA: ","PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
