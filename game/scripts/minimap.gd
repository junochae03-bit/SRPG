extends Node2D
var game
func _draw():
	if game==null or not game.session.connected or game.bag.visible or game.help_panel.visible or game.skill_tree.visible or game.town_panel.visible or game.codex.visible:return
	var center=Vector2(1324,106)
	draw_circle(center,78,Color("1d5146d9"))
	draw_arc(center,78,0,TAU,64,Color("b9d4b8"),2,true)
	var origin=center-Vector2(19,19)*3.0
	for cell in game.dungeon.floor_cells:
		var at=origin+Vector2(cell)*3.0
		if at.distance_to(center)<73:draw_rect(Rect2(at,Vector2(3,3)),Color("a5b999"))
	draw_circle(origin+game.dungeon.spawn*3.0,4,Color("f3ce72"))
	if game.dungeon.zone=="town":
		for facility in preload("res://scripts/world_catalog.gd").FACILITIES.values():draw_circle(origin+facility.pos*3.0,3.2,Color("fff0ba"))
	for e in game.session.state.enemies.values():
		if e.hp>0:draw_circle(origin+e.pos*3.0,3 if e.kind=="warden" else 1.6,Color("dc8c8b"))
	for p in game.session.state.players.values():
		var at=origin+p.pos*3.0
		draw_circle(at,5,Color("faf5d9"));draw_circle(at,2.5,Color("2f9d8f"))
	draw_string(game.fonts,center+Vector2(-5,-60),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("eaf1da"))
