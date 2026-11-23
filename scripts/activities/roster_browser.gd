extends RefCounted
## Shared touch-friendly filters and pagination for every roster screen.
var h
var rarity := -1
var element := -1
var pages: Dictionary = {}

func _init(host) -> void: h = host

func ids(owned_only := false) -> Array[int]:
	var result: Array[int] = []
	for id in range(h.game.hero_catalog.count()):
		var entry: Dictionary = h.game.hero_catalog.info(id)
		if owned_only and not h.game.owned[id]: continue
		if rarity >= 0 and entry.rarity != h.game.hero_catalog.data.rarities[rarity]: continue
		if element >= 0 and int(entry.element_id) != element: continue
		result.append(id)
	return result

func _filter(rect: Rect2, choices: Array, value: int, callback: Callable) -> void:
	var b := OptionButton.new()
	b.position = rect.position
	b.size = rect.size
	b.add_theme_font_size_override("font_size",17)
	for choice in choices: b.add_item(str(choice))
	b.selected = value + 1
	b.item_selected.connect(callback)
	h.screen.add_child(b)

func render(rect: Rect2, context: String, choose: Callable, owned_only := false) -> void:
	var rare_choices: Array = ["Todas as raridades"]
	rare_choices.append_array(h.game.hero_catalog.data.rarities)
	var element_choices: Array = ["Todos os elementos"]
	element_choices.append_array(h.game.hero_catalog.data.elements)
	_filter(Rect2(rect.position,Vector2(rect.size.x*.48,42)),rare_choices,rarity,func(i): rarity=i-1; pages.clear(); h._route(h.current_page))
	_filter(Rect2(rect.position+Vector2(rect.size.x*.51,0),Vector2(rect.size.x*.49,42)),element_choices,element,func(i): element=i-1; pages.clear(); h._route(h.current_page))
	var list := ids(owned_only)
	var page_count := maxi(1,ceili(list.size()/6.0))
	var page_index := clampi(int(pages.get(context,0)),0,page_count-1)
	pages[context]=page_index
	var card_size := Vector2((rect.size.x-24)/3,(rect.size.y-104)/2)
	for i in range(6):
		var offset := page_index*6+i
		if offset >= list.size(): break
		var id: int=list[offset]
		var pos := rect.position+Vector2((i%3)*(card_size.x+12),52+int(i/3)*(card_size.y+6))
		var button = h._hero_card(id,Rect2(pos,card_size),func(): choose.call(id),h.screen)
		button.name="RosterHero%d" % id
	var y := rect.end.y-40
	var previous = h._plate("Anterior",Rect2(rect.position.x,y,155,38),h.screen,func(): pages[context]=page_index-1; h._route(h.current_page),false,16)
	previous.disabled = page_index==0
	h._text("%d / %d · %d heróis" % [page_index+1,page_count,list.size()],Rect2(rect.position.x+162,y,rect.size.x-324,38),h.screen,16,h.GOLD,false,true)
	var next = h._plate("Próxima",Rect2(rect.end.x-155,y,155,38),h.screen,func(): pages[context]=page_index+1; h._route(h.current_page),false,16)
	next.disabled=page_index>=page_count-1
	if list.is_empty(): h._text("Nenhum herói neste filtro.",Rect2(rect.position+Vector2(0,80),Vector2(rect.size.x,50)),h.screen,20,h.MUTED,false,true)
