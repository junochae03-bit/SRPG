extends Node2D
const Icons=preload("res://scripts/icon_library.gd")
const CENTER=Vector2(1324,106)
const ORIGIN=CENTER-Vector2(19,19)*3.0
var game
func _draw():
	if game==null or not game.session.connected or game.bag.visible or game.help_panel.visible or game.skill_tree.visible or game.town_panel.visible or game.codex.visible or game.npc_dialogue.visible:return
	var center=CENTER
	draw_circle(center,78,Color("1d5146d9"))
	draw_arc(center,78,0,TAU,64,Color("b9d4b8"),2,true)
	var origin=ORIGIN
	for cell in game.dungeon.floor_cells:
		var at=origin+Vector2(cell)*3.0
		if at.distance_to(center)<73:draw_rect(Rect2(at,Vector2(3,3)),Color("a5b999"))
	marker(game.dungeon.spawn,"town",12,Color.WHITE,true)
	if game.dungeon.zone=="town":
		for key in preload("res://scripts/world_catalog.gd").FACILITIES:
			var facility=preload("res://scripts/world_catalog.gd").FACILITIES[key]
			marker(facility.pos,key,13)
	elif game.dungeon.floor_number>0:
		var sealed=game.session.state.enemies.values().any(func(e):return e.get("guardian",false) and e.hp>0)
		marker(game.dungeon.exit_position,"locked" if sealed else "stairs",15,Color.WHITE,true)
	for e in game.session.state.enemies.values():
		if e.hp<=0:continue
		if e.get("boss",false) or e.get("guardian",false):marker(e.pos,"boss",13)
		elif e.get("elite",false):marker(e.pos,"elite",10)
		else:
			var at=origin+e.pos*3.0
			if at.distance_to(center)<71:draw_circle(at,1.6,Color("dc8c8b"))
	for p in game.session.state.players.values():
		marker(p.pos,"class_"+p.class_id,16,Color.WHITE,true)
	draw_string(game.fonts,center+Vector2(-5,-60),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("eaf1da"))

func marker(world:Vector2,key:String,pixels:float,tint:Color=Color.WHITE,clamp_to_edge:bool=false):
	var at=ORIGIN+world*3.0;var limit=73-pixels*.5
	if at.distance_to(CENTER)>limit:
		if not clamp_to_edge:return
		at=CENTER+(at-CENTER).limit_length(limit)
	Icons.draw(self,key,Rect2(at-Vector2.ONE*pixels*.5,Vector2.ONE*pixels),tint)
