extends Button
var game
var kind=""
var caption=""
var hotkey=""
var picture:Texture2D
var cooldown=0.0
var max_cooldown=1.0
var count=""
var tint=Color("64c9be")
func setup(owner_game,action:String,title:String,key:String):
	game=owner_game;kind=action;caption=title;hotkey=key
	tooltip_text=caption+" ("+hotkey+")"
	for state in ["normal","hover","pressed","focus"]:add_theme_stylebox_override(state,StyleBoxEmpty.new())
	focus_mode=Control.FOCUS_NONE
func _has_point(point:Vector2)->bool:return point.distance_to(size*0.5)<size.x*0.5
func _draw():
	var center=size*0.5;var radius=size.x*0.5-5
	draw_circle(center,radius,Color("193e48c9"))
	draw_arc(center,radius,0,TAU,64,tint,2,true)
	draw_arc(center,radius-4,-PI*0.55,PI*0.25,32,Color("dcf3df94"),1,true)
	if is_hovered():draw_circle(center,radius-3,Color(1,1,1,0.12))
	if picture:
		var dims=picture.get_size();dims*=minf(size.x*0.92/dims.x,size.y*0.92/dims.y)
		draw_texture_rect(picture,Rect2(center-dims*0.5,dims),false)
	if cooldown>0:
		draw_circle(center,radius-3,Color("102b40af"))
		draw_arc(center,radius-1,-PI*0.5,-PI*0.5+TAU*clampf(cooldown/maxf(max_cooldown,0.01),0,1),64,Color("efc674"),4,true)
		write_text(center+Vector2(0,8),"%.1f" % cooldown,21)
	else:write_text(center+Vector2(radius-12,radius-5),count,14)
	write_text(Vector2(size.x*0.5,6),hotkey,12)
	write_text(Vector2(size.x*0.5,size.y+16),caption,15)
func write_text(at:Vector2,value:String,font_size:int):
	at.x-=game.fonts.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x*0.5
	draw_string_outline(game.fonts,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,3,Color("193e48"))
	draw_string(game.fonts,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("f6f7e9"))
