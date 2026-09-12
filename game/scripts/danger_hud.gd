extends Control
const Priority=preload("res://scripts/telegraph_priority.gd")
var game
var warnings:Array=[]
func setup(owner_game):
	game=owner_game;mouse_filter=Control.MOUSE_FILTER_IGNORE
func screen_point(pos:Vector2)->Vector2:
	return game.get_global_transform_with_canvas()*game.world_point(pos)
func _process(_delta:float):
	warnings.clear()
	if game==null or game.session==null or not game.session.connected or game.session.paused or not game.hud.visible:hide();return
	var player:Dictionary=game.session.state.players.get(game.session.local_id,{})
	var occupied:Array=game.hud.world_label_regions()
	for property in ["inspection_panel","exploration_panel"]:
		var panel=game.get(property)
		if panel!=null and panel.visible:occupied.append(panel.card.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,panel.card.size))
	warnings=Priority.warnings(game.visible_telegraphs.records,player,game.vision,screen_point,get_viewport().get_visible_rect(),occupied)
	visible=not warnings.is_empty();queue_redraw()
func _draw():
	var inverse=get_global_transform_with_canvas().affine_inverse()
	for warning in warnings:
		var point:Vector2=inverse*warning.point;var direction:Vector2=warning.direction
		var tint=Color("ff8e64") if warning.time>.45 else Color("fff0b5")
		var tip=point+direction*14.;var side=direction.orthogonal()*9.;var base=point-direction*7.
		draw_circle(point,19,Color("251c19ed"))
		draw_colored_polygon(PackedVector2Array([tip,base+side,base-side]),tint)
		draw_arc(point,20,-PI*.5,TAU-PI*.5,28,Color("c95945"),2,true)
		var text="%.1f"%warning.time;var width=game.fonts.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
		var at=point+Vector2(-width*.5,39)
		draw_string_outline(game.fonts,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,16,3,Color("211719"))
		draw_string(game.fonts,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("fff0d6"))
