extends Control
var game
var boss:Dictionary={}
var target_id=-1
var trail=1.0
var lag=0.0
var previous=1.0
func setup(owner_game):
	game=owner_game;mouse_filter=Control.MOUSE_FILTER_IGNORE;material=preload("res://scripts/gat_art.gd").material()
func _process(delta:float):
	boss={}
	if not game.session.connected:hide();return
	var p=game.session.state.players.get(game.session.local_id,{})
	if p.is_empty():hide();return
	var best=8.5
	for enemy in game.session.state.enemies.values():
		var distance=p.pos.distance_to(enemy.pos)
		if enemy.get("boss",false) and enemy.hp>0 and distance<best:boss=enemy;best=distance
	visible=not boss.is_empty() and not game.bag.visible and not game.skill_tree.visible and not game.help_panel.visible
	if boss.is_empty():target_id=-1;return
	var ratio=clampf(float(boss.hp)/boss.max_hp,0,1)
	if target_id!=boss.id:target_id=boss.id;trail=ratio;previous=ratio;lag=0
	if ratio<previous:lag=.32
	previous=ratio;lag=maxf(0,lag-delta)
	if lag<=0:trail=move_toward(trail,ratio,delta*.5)
	trail=maxf(trail,ratio);queue_redraw()
func _draw():
	if boss.is_empty():return
	var index=["warden","golem","sentinel"].find(boss.kind)
	var data=preload("res://scripts/world_art.gd").frame("boss_bars",index)
	var scale=590.0/data.texture.get_width();var origin=Vector2(426,38)
	draw_texture_rect(data.texture,Rect2(origin,data.texture.get_size()*scale),false)
	var track=data.track;var rect=Rect2(origin+Vector2(track[0],track[1])*scale,Vector2(track[2],track[3])*scale)
	draw_rect(Rect2(rect.position,Vector2(rect.size.x*trail,rect.size.y)),Color("f6d69a"))
	var ratio=clampf(float(boss.hp)/boss.max_hp,0,1)
	draw_rect(Rect2(rect.position,Vector2(rect.size.x*ratio,rect.size.y)),Color("d63248"))
	draw_rect(Rect2(rect.position,Vector2(rect.size.x*ratio,rect.size.y*.28)),Color("ff787e"))
	var title="LV.%d  ·  %s" % [boss.get("level",1),boss.name]
	if boss.get("phase",1)==2:title+="  ·  격노"
	text_center(title,Vector2(721,27),20,Color("fff2ca"))
	text_center("%d / %d" % [maxi(0,boss.hp),boss.max_hp],Vector2(721,rect.end.y+16),13,Color("fff1d5"))
func text_center(value:String,at:Vector2,font_size:int,color:Color):
	var font=game.bold_font;at.x-=font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x*.5
	font.draw_string_outline(get_canvas_item(),at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,4,Color("2e292bd9"))
	draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
