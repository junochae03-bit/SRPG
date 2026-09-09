extends Control
const Icons=preload("res://scripts/icon_library.gd")
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
	visible=not boss.is_empty() and not game.bag.visible and not game.skill_tree.visible and not game.help_panel.visible and not game.town_panel.visible and not game.codex.visible and not game.npc_dialogue.visible
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
	var scale=520.0/data.texture.get_width();var origin=Vector2(461,32)
	draw_texture_rect(data.texture,Rect2(origin,data.texture.get_size()*scale),false)
	var track=data.track;var rect=Rect2(origin+Vector2(track[0],track[1])*scale,Vector2(track[2],track[3])*scale)
	draw_rect(Rect2(rect.position,Vector2(rect.size.x*trail,rect.size.y)),Color("f6d69a"))
	var ratio=clampf(float(boss.hp)/boss.max_hp,0,1)
	draw_rect(Rect2(rect.position,Vector2(rect.size.x*ratio,rect.size.y)),Color("d63248"))
	draw_rect(Rect2(rect.position,Vector2(rect.size.x*ratio,rect.size.y*.28)),Color("ff787e"))
	var title="LV.%d  ·  %s" % [boss.get("level",1),boss.name]
	if boss.get("phase",1)==2:title+="  ·  격노"
	text_center(title,Vector2(721,27),20,Color("fff2ca"),"enrage" if boss.get("phase",1)==2 else "boss")
	draw_stagger(146)

func draw_stagger(top:float):
	var s=boss.get("stagger",{})
	if s.is_empty():return
	var state=str(s.state)
	var progress=clampf(float(s.check_value)/s.check_max if state=="check" else float(s.value)/s.max_value,0,1)
	var color=Color("edc55f")
	var caption="무력화 축적  %d / %d" % [roundi(s.value),roundi(s.max_value)]
	if state=="check":
		color=Color("79d5e5");caption="무력화 집중!  %d / %d  ·  %.1f초" % [roundi(s.check_value),roundi(s.check_max),s.time_left]
	elif state=="down":
		color=Color("98e6b1");progress=float(s.time_left)/s.time_max;caption="무력화 성공 · 받는 피해 +20%%  ·  %.1f초" % s.time_left
	elif state=="immune":
		color=Color("b6bcca");progress=float(s.time_left)/s.time_max;caption="무력화 면역  ·  %.1f초 후 다시 축적" % s.time_left
	var backdrop=StyleBoxTexture.new();backdrop.texture=preload("res://scripts/ui_art.gd").texture("magic")
	backdrop.texture_margin_left=64;backdrop.texture_margin_right=64;backdrop.texture_margin_top=64;backdrop.texture_margin_bottom=64
	# Match UiArt.decorate's border scale so the ornamental corners fit this narrow meter.
	var border_scale=12./64.
	draw_set_transform(Vector2(481,top),0,Vector2.ONE*border_scale)
	draw_style_box(backdrop,Rect2(Vector2.ZERO,Vector2(480,82)/border_scale))
	draw_set_transform(Vector2.ZERO)
	var meter=Rect2(509,top+18,424,22)
	draw_rect(Rect2(meter.position+Vector2(4,5),Vector2(416,12)),Color("192c34"))
	draw_rect(Rect2(meter.position+Vector2(4,5),Vector2(416*progress,12)),color)
	draw_rect(Rect2(meter.position+Vector2(4,5),Vector2(416*progress,3)),color.lightened(.35))
	for i in range(1,5):draw_line(meter.position+Vector2(4+416*i/5.,5),meter.position+Vector2(4+416*i/5.,17),Color("40342690"),1)
	text_center(caption,Vector2(721,top+60),14,Color("fff2ce"),{"check":"stagger_check","down":"stagger_broken","immune":"stagger_immune"}.get(state,"stagger"))
	if state=="check":
		var remaining=clampf(float(s.time_left)/s.time_max,0,1)
		draw_line(Vector2(549,top+68),Vector2(549+344*remaining,top+68),Color("ff9076") if s.time_left<3 else Color("d8f8ff"),3)
func text_center(value:String,at:Vector2,font_size:int,color:Color,icon_key:String=""):
	var font=game.bold_font;var icon_width=font_size+8 if not icon_key.is_empty() else 0
	at.x-=(font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x+icon_width)*.5
	if not icon_key.is_empty():
		Icons.draw(self,icon_key,Rect2(at+Vector2(0,-font_size-2),Vector2.ONE*(font_size+3)))
		at.x+=icon_width
	font.draw_string_outline(get_canvas_item(),at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,4,Color("2e292bd9"))
	draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
