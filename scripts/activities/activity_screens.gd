extends RefCounted
## Activity lobbies and secondary pages. All progression is local and persisted.
const DB = preload("res://scripts/clover_idle.gd")
const EncounterCatalog = preload("res://scripts/activities/encounter_catalog.gd")
var encounters := EncounterCatalog.new()
var h
var atlas: Texture2D
var scenes: Array[Texture2D] = []
var opponent := 0
var last_boss_hp := 0.0

func _init(host) -> void:
	h = host
	atlas = load("res://assets/screens/activity-atlas.png")
	for i in range(4):
		var texture := AtlasTexture.new()
		texture.atlas = atlas
		var cell := atlas.get_width() / 2.0
		texture.region = Rect2((i % 2) * cell, (i / 2) * cell, cell, cell)
		scenes.append(texture)
	var defaults := {"tower_floor":1,"arena_rating":1000,"arena_best":1000,"arena_date":"","arena_attempts":0,"boss_level":1,"boss_damage":0.0,"boss_best":0,"boss_date":"","boss_attempts":0,"clan_name":"","clan_xp":0,"clan_donation_date":"","clan_claimed_level":0,"pass_claims":[],"checkin_days":0,"effects_enabled":true,"mail_read":false}
	for key in defaults:
		if not h.state.has(key): h.state[key] = defaults[key]

func render(page: String) -> bool:
	match page:
		"Torre Infinita": _tower()
		"Arena": _arena()
		"Clã": _clan()
		"Batalha de Chefes": _boss()
		"Eventos": _events()
		"Recompensas": _rewards()
		"Check-in": _checkin()
		"Passe de Jornada": _pass()
		"Correio": _mail()
		"Configurações": _settings()
		"Evolução": _evolution()
		"Equipamento": equipment()
		_: return false
	return true

func background_for(mode: String) -> Texture2D:
	if mode in ["Campanha", "Torre Infinita"]:
		var rank: int = h.game.stage if mode == "Campanha" else int(h.state.tower_floor)
		return encounters.texture(encounters.scene_info(mode, rank))
	return scenes[{"Torre Infinita":0,"Arena":1,"Clã":2,"Batalha de Chefes":3}.get(mode, 0)] if mode != "Campanha" else h.game.forest

func backdrop(page: String) -> void:
	var index: int = {"Torre Infinita":0,"Arena":1,"Clã":2,"Batalha de Chefes":3,"Loja":2,"Mercado":2,"Bag":2,"Missões":0,"Conquistas":1,"Fusão":0,"Evolução":0}.get(page,0)
	var image = h._image(scenes[index],Rect2(24,237,672,879),h.screen)
	image.modulate = Color(0.5,0.4,0.65,0.20)

func _title(value: String, y: float, size := 23, color := Color("ffdc8c")) -> void:
	h._text(value,Rect2(42,y,636,38),h.screen,size,color,true,true)

func _banner(index: int, eyebrow: String, title: String, detail: String) -> void:
	h._image(background_for("Torre Infinita") if h.current_page == "Torre Infinita" else scenes[index],Rect2(33,242,654,255),h.screen)
	h._panel(Rect2(34,363,652,134),h.screen,Color(0.08,0.05,0.15,0.88))
	h._text(eyebrow,Rect2(54,376,612,24),h.screen,14,Color("d6c1eb"),false,true)
	h._text(title,Rect2(48,404,624,42),h.screen,29,h.GOLD,true,true)
	h._text(detail,Rect2(48,453,624,28),h.screen,17,h.WHITE,false,true)

func _row(y: float, title: String, detail: String, art: int, caption: String, action: Callable, enabled := true) -> Button:
	var p = h._panel(Rect2(34,y,652,118),h.screen,Color("292033"))
	h._art(art,Rect2(15,23,68,68),p)
	var name_label = h._text(title,Rect2(105,12,520,32),p,21,h.GOLD,true)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var description = h._text(detail,Rect2(105,49,510,25),p,16,h.WHITE)
	description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var b = h._plate(caption,Rect2(420,77,210,34),p,action,false,16)
	b.disabled = not enabled
	if not enabled: b.modulate = Color(0.55,0.55,0.6)
	return b

func _save() -> void:
	h._save_home()
	h.game._save_game()
	h._sync_wallet()

func _refresh() -> void:
	h._route(h.current_page)

func _daily(kind: String) -> int:
	if h.state[kind + "_date"] != h._today():
		h.state[kind + "_date"] = h._today()
		h.state[kind + "_attempts"] = 0
	return int(h.state[kind + "_attempts"])

func _tower() -> void:
	var floor_number := int(h.state.tower_floor)
	var place: String = encounters.scene_info("Torre Infinita", floor_number).name
	_banner(0,"CHEFÃO A CADA 5 ANDARES · 40 CENÁRIOS","Torre Infinita","Andar %d · %s" % [floor_number,place])
	_title("Recompensa do próximo andar",522)
	for i in range(3):
		var p = h._panel(Rect2(35+i*228,575,195,126),h.screen)
		h._art(16+i,Rect2(14,17,60,60),p)
		h._text(str([400+floor_number*120,40,30][i]),Rect2(78,34,108,35),p,25,h.GOLD,true,true)
		var names := ["Ouro","Diamantes","Essência"]
		h._text(names[i],Rect2(9,88,177,25),p,17,h.WHITE,false,true)
	_row(739,"Seu esquadrão", "%d cavaleiros · Poder %s" % [h.game.team.size(),h.game._number(h.game._team_power())],10,"Editar formação",func(): h._route("Formação"))
	_row(871,"Resistência crescente","Vença para abrir o próximo andar. Derrotas não apagam progresso.",15,"Evoluir heróis",func(): h._route("Evolução"))
	h._plate("DESAFIAR ANDAR %d" % floor_number,Rect2(112,1030,496,64),h.screen,func(): launch("Torre Infinita"),true,24)

func _arena() -> void:
	var attempts := _daily("arena")
	_banner(1,"ARENA DE TREINO · ADVERSÁRIOS CONTROLADOS PELO JOGO","Torneio do Reino","Pontuação %d  ·  Melhor marca %d  ·  %d/5 duelos hoje" % [h.state.arena_rating,h.state.arena_best,attempts])
	var names := ["Patrulha Real","Esquadrão Carmesim","Guarda do Crepúsculo"]
	var difficulties := ["Iniciante","Intermediário","Avançado"]
	for i in range(3):
		var id := i
		var b = _row(525+i*148,names[i],difficulties[i]+" · treino offline · 5 cavaleiros",[8,15,13][i],"Selecionado" if opponent==i else "Selecionar",func(): opponent=id; _refresh())
		b.active = opponent==i
	_title("Vitória: 300 ouro + 15 diamantes · +25 pontos",986,17)
	h._plate("INICIAR DUELO",Rect2(112,1030,496,64),h.screen,func(): launch("Arena"),true,25).disabled = attempts>=5

func _boss() -> void:
	var attempts := _daily("boss")
	var level := int(h.state.boss_level)
	var maximum := boss_max_hp()
	_banner(3,"CHEFE SOLO · 3 TENTATIVAS POR DIA","Guardião das Chamas","Nível %d  ·  %d/3 desafios utilizados" % [level,attempts])
	_title("Vida do guardião",519)
	var bar := ProgressBar.new()
	bar.position = Vector2(53,574)
	bar.size = Vector2(614,28)
	bar.value = maxf(0,100.0-float(h.state.boss_damage)/maximum*100.0)
	bar.show_percentage = true
	h.screen.add_child(bar)
	_title("%s / %s HP" % [h.game._number(int(maximum-float(h.state.boss_damage))),h.game._number(int(maximum))],618,19)
	_row(686,"Dano acumulado", "%s de dano mantido entre tentativas" % h.game._number(int(h.state.boss_damage)),15,"Evoluir equipe",func(): h._route("Evolução"))
	_row(824,"Recompensas por desempenho","Ouro e essência pelo dano. Vitória concede 150 diamantes.",2,"Ver inventário",func(): h._route("Bag"))
	_title("Maior dano em uma tentativa: %s" % h.game._number(int(h.state.boss_best)),969,17)
	h._plate("ENFRENTAR GUARDIÃO",Rect2(112,1030,496,64),h.screen,func(): launch("Batalha de Chefes"),true,24).disabled = attempts>=3

func boss_max_hp() -> float:
	return float(800 + int(h.state.boss_level)*170)*6.0

func _clan() -> void:
	var name: String = h.state.clan_name
	var level := 1 + int(h.state.clan_xp)/100
	_banner(2,"SEDE LOCAL · SEM SERVIDOR DE CLÃS ONLINE",name if not name.is_empty() else "Seu esquadrão, sua bandeira","Clã nível %d · 1 integrante" % level if not name.is_empty() else "Funde uma sede para os seus cavaleiros")
	if name.is_empty():
		_title("Dê um nome ao seu clã",554)
		var input := LineEdit.new()
		input.name = "ClanName"
		input.position = Vector2(89,632)
		input.size = Vector2(542,60)
		input.max_length = 18
		input.placeholder_text = "Nome do clã"
		input.alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.screen.add_child(input)
		_title("Fundação: 1.000 ouro",747,21)
		h._plate("FUNDAR CLÃ",Rect2(112,882,496,64),h.screen,func(): create_clan(input.text),true,25)
		_title("Esta sede é local. Não envia convites para jogadores reais.",1000,15)
		return
	var member = h._panel(Rect2(34,531,652,139),h.screen)
	var avatar = h._image(h._avatar_texture(int(h.state.avatar)),Rect2(18,18,94,94),member)
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h._text(str(h.state.name),Rect2(137,23,480,36),member,25,h.GOLD,true)
	h._text("Capitão · Nível da conta %d" % h.game.get_player_level(),Rect2(138,75,480,29),member,20,h.WHITE)
	var donated: bool = h.state.clan_donation_date == h._today()
	_row(698,"Contribuição diária","500 ouro → 50 XP do clã + 20 essência",16,"Já contribuído" if donated else "Contribuir",donate_clan,not donated)
	var claimed: bool = int(h.state.clan_claimed_level)>=level
	_row(841,"Tesouro da sede","Nível %d · recompensa de 100 diamantes" % level,2,"Recebido" if claimed else "Coletar tesouro",claim_clan,not claimed)
	_title("Experiência do clã: %d / %d" % [h.state.clan_xp,level*100],1005,20)

func create_clan(value: String) -> void:
	var name := value.strip_edges()
	if not str(h.state.clan_name).is_empty(): return
	if name.length()<2: h._notice("Nome muito curto","Escolha um nome com pelo menos 2 letras."); return
	if h.game.gold<1000: h._notice("Ouro insuficiente","A fundação custa 1.000 ouro."); return
	h.game.gold-=1000
	h.state.clan_name=name
	_save()
	_refresh()

func donate_clan() -> void:
	if str(h.state.clan_name).is_empty() or h.state.clan_donation_date==h._today(): return
	if h.game.gold<500: h._notice("Ouro insuficiente","A contribuição custa 500 ouro."); return
	h.game.gold-=500
	h.game.essence+=20
	h.state.clan_xp=int(h.state.clan_xp)+50
	h.state.clan_donation_date=h._today()
	_save()
	_refresh()

func claim_clan() -> void:
	var level := 1+int(h.state.clan_xp)/100
	if str(h.state.clan_name).is_empty() or int(h.state.clan_claimed_level)>=level: return
	h.state.clan_claimed_level=level
	h.game.gems+=100
	_save()
	_refresh()

func launch(mode: String) -> void:
	if h.game.fighting: return
	if mode=="Arena":
		if _daily("arena")>=5: h._notice("Duelos concluídos","Você utilizou os 5 duelos de hoje."); return
		h.state.arena_attempts=int(h.state.arena_attempts)+1
	if mode=="Batalha de Chefes":
		if _daily("boss")>=3: h._notice("Desafios concluídos","Você utilizou as 3 tentativas de hoje."); return
		h.state.boss_attempts=int(h.state.boss_attempts)+1
	h.active_activity=mode
	h.auto_battle=false
	h.game.battle_kind="activity"
	h.game.activity_rank = int(h.state.tower_floor) if mode=="Torre Infinita" else int(h.state.boss_level) if mode=="Batalha de Chefes" else 1+opponent*2+maxi(0,(int(h.state.arena_rating)-1000)/200)
	_save()
	h._start_battle()

func spawn_opponents() -> bool:
	if h.active_activity in ["Campanha", "Torre Infinita"]:
		var rank: int = h.game.stage if h.active_activity == "Campanha" else int(h.state.tower_floor)
		encounters.spawn(h.game, h.active_activity, rank)
		return true
	var mode: String = h.active_activity
	if mode=="Batalha de Chefes":
		var boss = h.game._spawn(3,Vector2(970,570) if h.game.field.get_meta("expanded",false) else Vector2(937,420),true,310,true)
		boss.body.texture=load("res://assets/screens/boss-dragon.png")
		boss.body.scale=Vector2.ONE*310.0/boss.body.texture.get_height()
		boss.body.offset.y=-boss.body.texture.get_height()*0.4805
		boss.body.flip_h=false
		boss.custom_skill="Guardião das Chamas · Sopro Infernal"
		boss.max_hp=boss_max_hp()
		boss.hp=maxf(1,boss.max_hp-float(h.state.boss_damage))
		boss.attack_modifier=2.0
		last_boss_hp=boss.hp
		return true
	var slots := preload("res://scripts/visuals/battle_formation.gd").slots(true,bool(h.game.field.get_meta("expanded",false)))
	var seed: int = int(h.state.tower_floor) if mode=="Torre Infinita" else opponent+2
	for i in range(5): h.game._spawn((seed+i)%6,slots[i],true,preload("res://scripts/visuals/battle_formation.gd").height_for(i,true,false,bool(h.game.field.get_meta("expanded",false))),true)
	return true

func finish(won: bool) -> bool:
	if h.active_activity=="Campanha": return false
	var mode: String = h.active_activity
	var gold := 0
	var gems := 0
	var essence := 0
	var summary := "Evolua seus cavaleiros e tente novamente."
	if mode=="Torre Infinita" and won:
		gold=400+int(h.state.tower_floor)*120
		gems=80 if encounters.is_boss(mode,int(h.state.tower_floor)) else 40
		essence=30
		h.state.tower_floor=int(h.state.tower_floor)+1
		summary="Próximo andar desbloqueado!"
	elif mode=="Arena":
		gold=300 if won else 100
		gems=15 if won else 0
		h.state.arena_rating=maxi(800,int(h.state.arena_rating)+(25 if won else -15))
		h.state.arena_best=maxi(int(h.state.arena_best),int(h.state.arena_rating))
		summary="Pontuação de treino: %d" % h.state.arena_rating
	elif mode=="Batalha de Chefes":
		var damage := mini(int(last_boss_hp),int(h.game.total_damage))
		h.state.boss_best=maxi(int(h.state.boss_best),damage)
		h.state.boss_damage=minf(boss_max_hp(),float(h.state.boss_damage)+damage)
		gold=mini(3000,int(damage*0.15))
		essence=mini(150,int(damage/100))
		if won:
			gems=150
			h.state.boss_level=int(h.state.boss_level)+1
			h.state.boss_damage=0.0
		summary="Dano causado: %s" % h.game._number(damage)
	h.game.gold+=gold
	h.game.gems+=gems
	h.game.essence+=essence
	if won: h.game.player_xp+=25
	_save()
	var p = h._open("VITÓRIA!" if won else "DESAFIO ENCERRADO",480)
	h._text(mode+"\n"+summary,Rect2(25,105,572,75),p,22,h.GOLD,false,true)
	h._text("+%d ouro\n+%d diamantes\n+%d essência" % [gold,gems,essence],Rect2(30,213,562,120),p,25,h.WHITE,false,true)
	h._plate("Voltar à atividade",Rect2(124,388,374,58),p,func(): h._route(mode),true,23)
	return true

func _events() -> void:
	_banner(2,"CENTRAL DE ATIVIDADES","Eventos do Reino","Recompensas da sua jornada, sem ofertas fictícias")
	_row(527,"Presente de boas-vindas","500 ouro + 300 diamantes",1,"Recebido" if h.state.welcome else "Receber presente",claim_welcome,not h.state.welcome).name="WelcomeClaim"
	_row(677,"Passe de Jornada","Avance na Campanha e colete a trilha gratuita",6,"Abrir passe",func(): h._route("Passe de Jornada"))
	_row(827,"Desafio do Guardião","3 tentativas diárias · recompensas pelo dano",15,"Ver chefe",func(): h._route("Batalha de Chefes"))
	_title("Seus próximos objetivos estão em Missões e Conquistas.",1002,17)

func claim_welcome() -> void:
	if h.state.welcome: return
	h.state.welcome=true
	h.state.mail_read=true
	h.game.gold+=500
	h.game.gems+=300
	_save()
	_refresh()

func _rewards() -> void:
	_banner(2,"TESOURO DOS CAVALEIROS","Recompensas AFK","Os recursos continuam acumulando por até 8 horas")
	var amount := int(h.game.idle_gold)
	var mana := int(amount/12)
	for i in range(2):
		var p = h._panel(Rect2(47+i*326,554,298,197),h.screen)
		h._art(16 if i==0 else 18,Rect2(104,15,90,90),p)
		h._text(h.game._number(amount if i==0 else mana),Rect2(14,115,270,40),p,31,h.GOLD,true,true)
		h._text("Ouro" if i==0 else "Essência mágica",Rect2(10,162,278,28),p,20,h.WHITE,false,true)
	_title("Produção: %d ouro por minuto" % (120+h.game.stage*10),805,22)
	_title("Ganhos aumentam ao avançar na Campanha.",862,18)
	h._plate("COLETAR TESOURO",Rect2(112,985,496,69),h.screen,collect_afk,true,25).name="ClaimAFK"

func collect_afk() -> void:
	var amount := int(h.game.idle_gold)
	if amount<1: h._notice("Tesouro em formação","Seus cavaleiros já estão reunindo novos recursos."); return
	h.game.gold+=amount
	h.game.essence+=int(amount/12)
	h.game.idle_gold-=amount
	_save()
	_refresh()

func _checkin() -> void:
	var claimed: bool = h.state.checkin==h._today()
	var day := int(h.state.checkin_days)%7
	_banner(0,"PRESENTE DIÁRIO","Check-in dos Cavaleiros","Dia %d do ciclo · uma recompensa por dia" % (day+1))
	for i in range(7):
		var rect := Rect2(48+(i%4)*161,537+(i/4)*172,144,149)
		var p = h._panel(rect,h.screen,Color("594133") if i==day else Color("292133"))
		h._text("DIA %d" % (i+1),Rect2(6,9,132,25),p,17,h.GOLD,true,true)
		h._art(17,Rect2(44,43,56,56),p)
		h._text("500" if i==6 else "200",Rect2(5,110,134,29),p,24,h.WHITE,false,true)
	_title("Ouro diário: 1.000 · Bônus do dia 7: 500 diamantes",917,18)
	h._plate("JÁ RECEBIDO HOJE" if claimed else "RECEBER PRESENTE",Rect2(112,1001,496,66),h.screen,claim_checkin,not claimed,23).name="ClaimCheckin"

func claim_checkin() -> void:
	if h.state.checkin==h._today(): return
	var day := int(h.state.checkin_days)%7
	h.state.checkin=h._today()
	h.state.checkin_days=int(h.state.checkin_days)+1
	h.game.gold+=1000
	h.game.gems+=500 if day==6 else 200
	_save()
	_refresh()

func _pass() -> void:
	_banner(0,"TRILHA GRATUITA · SEM COMPRA","Passe de Jornada","Conquiste fases da Campanha e receba cada marco uma vez")
	for i in range(5):
		var threshold := (i+1)*2
		var claimed: bool = threshold in h.state.pass_claims
		var eligible: bool = h.game.stage>threshold
		_row(519+i*117,"Marco %d · Fase 1–%d" % [i+1,threshold],"%d ouro + %d diamantes" % [300+threshold*100,80+threshold*10],6,"Recebido" if claimed else "Receber" if eligible else "Em progresso",func(): claim_pass(threshold),eligible and not claimed)

func claim_pass(threshold: int) -> void:
	if threshold not in [2,4,6,8,10] or threshold in h.state.pass_claims or h.game.stage<=threshold: return
	h.state.pass_claims.append(threshold)
	h.game.gold+=300+threshold*100
	h.game.gems+=80+threshold*10
	_save()
	_refresh()

func _mail() -> void:
	_banner(2,"CORREIO DO REINO","Mensagens dos Cavaleiros","Anúncios e presentes do sistema local")
	_row(537,"Bem-vindo aos Touros Negros","Seu presente inicial: 500 ouro + 300 diamantes",4,"Presente recebido" if h.state.welcome else "Receber presente",claim_welcome,not h.state.welcome)
	var p = h._panel(Rect2(34,703,652,232),h.screen)
	h._text("Sua próxima aventura",Rect2(25,20,602,37),p,27,h.GOLD,true,true)
	h._text("Convoque cavaleiros, monte sua formação e\nexplore a Torre Infinita e os desafios do Reino.\n\nSeu progresso é salvo neste aparelho.",Rect2(28,79,596,135),p,21,h.WHITE,false,true)
	h.state.mail_read=true
	h._save_home()

func _settings() -> void:
	_banner(2,"PREFERÊNCIAS DO APARELHO","Configurações","Android e Telegram · perfil e progresso locais")
	_row(530,"Efeitos de ambiente","Partículas, portais e reflexos no Reino",11,"Ativos" if h.state.effects_enabled else "Reduzidos",func(): h.state.effects_enabled=not h.state.effects_enabled; _save(); _refresh())
	_row(676,"Velocidade de batalha","Padrão aplicado aos combates automáticos",15,"Velocidade %dx" % h.game.speed,func(): h.game.speed=2 if h.game.speed==1 else 1; _save(); _refresh())
	_row(822,"Perfil do cavaleiro","Nome, avatar, nível da conta e VIP",0,"Editar perfil",h._profile)
	h._plate("SALVAR PROGRESSO",Rect2(112,1004,496,64),h.screen,func(): _save(); h._notice("Progresso salvo","Sua jornada foi salva neste aparelho."),true,23)

func _evolution() -> void:
	var id: int = h.selected
	h._image(scenes[0],Rect2(34,242,652,433),h.screen)
	var portrait: Texture2D = h.game.hero_catalog.texture(id,h.game.atlas)
	var image = h._image(portrait,Rect2(171,255,378,378),h.screen)
	image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_title(DB.NAMES[id]+" · Nível %d" % h.game.levels[id],632,29)
	for i in range(int(id/6)*6,mini(int(id/6)*6+6,h.game.hero_catalog.count())):
		var hero := i
		var b = h._frame(Rect2(43+(i%6)*108,703,94,80),h.screen,func(): h.selected=hero; _refresh(),1,id==i)
		var face = h._image(h._avatar_texture(i),Rect2(14,7,66,66),b)
		face.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if not h.game.owned[i]: b.modulate=Color(0.45,0.45,0.5)
	h._plate("COLECAO COMPLETA",Rect2(217,789,286,29),h.screen,func(): h._route("Her\u00f3is"),false,15)
	var cost := int(h.game.levels[id])*100
	_title("Evoluir 1 nível: %d ouro + %d essência" % [cost,int(h.game.levels[id])*5],821,19)
	_title("Vida +%d - Ataque +%d - Defesa +9 por nivel" % [int(130*float(h.game.hero_catalog.info(id).hp)),int(27*float(h.game.hero_catalog.info(id).attack))],873,18)
	h._plate("EVOLUIR 1 NÍVEL",Rect2(43,962,306,65),h.screen,h._evolve,true,22)
	h._plate("EVOLUIR 5 NÍVEIS",Rect2(371,962,306,65),h.screen,func(): evolve_many(5),false,21)

func evolve_many(count: int) -> void:
	var id: int = h.selected
	if not h.game.owned[id]: h._route("Invocação"); return
	var gain := mini(count,100-int(h.game.levels[id]))
	if gain<=0: return
	var gold := 0
	var mana := 0
	for offset in range(gain):
		gold+=(int(h.game.levels[id])+offset)*100
		mana+=(int(h.game.levels[id])+offset)*5
	if h.game.gold<gold or h.game.essence<mana: h._notice("Recursos insuficientes","Os %d níveis custam %d ouro e %d essência." % [gain,gold,mana]); return
	h.game.gold-=gold
	h.game.essence-=mana
	h.game.levels[id]=int(h.game.levels[id])+gain
	_save()
	_refresh()

func equipment() -> void:
	var id: int = h.selected
	_banner(2,"ARSENAL DOS CAVALEIROS",DB.NAMES[id]+" · Grimório",DB.ELEMENTS[id]+" · equipamento individual")
	var p = h._panel(Rect2(34,539,652,306),h.screen)
	var book := AtlasTexture.new()
	book.atlas=h.game.atlas
	book.region=Rect2(880,100,140,220)
	var book_image = h._image(book,Rect2(242,24,168,168),p)
	book_image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h._text("Grimório aprimorado" if h.game.equipped[id] else "Grimório de aprendiz",Rect2(20,212,612,33),p,26,h.GOLD,true,true)
	h._text("+20% de dano · +100 de poder" if h.game.equipped[id] else "Aprimore para fortalecer seu cavaleiro.",Rect2(20,260,612,27),p,19,h.WHITE,false,true)
	h._plate("EQUIPAMENTO APRIMORADO" if h.game.equipped[id] else "APRIMORAR · 1.000 OURO",Rect2(69,960,582,66),h.screen,h._equip,true,23).disabled = h.game.equipped[id] or not h.game.owned[id]
