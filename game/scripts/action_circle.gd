extends Button
var game
var kind=""
var caption=""
var hotkey=""
var picture:Texture2D
var cooldown=0.0
var max_cooldown=1.0
var count=""
var rank_text=""
var locked=false
var tint=Color("64c9be")
func setup(owner_game,action:String,title:String,key:String):
	material=preload("res://scripts/gat_art.gd").material()
	game=owner_game;kind=action;caption=title;hotkey=key
	tooltip_text=caption+" ("+hotkey+")"
	for state in ["normal","hover","pressed","focus","disabled"]:add_theme_stylebox_override(state,StyleBoxEmpty.new())
	focus_mode=Control.FOCUS_NONE
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	mouse_entered.connect(queue_redraw);mouse_exited.connect(queue_redraw)
func _has_point(point:Vector2)->bool:return Rect2(Vector2.ZERO,size).has_point(point)
func cooldown_text()->String:return str(ceili(cooldown)) if cooldown>=1 else "%.1f"%cooldown
func caption_text()->String:
	var value=caption;var width=size.x+16
	if game.fonts.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x<=width:return value
	while value.length()>1 and game.fonts.get_string_size(value+"…",HORIZONTAL_ALIGNMENT_LEFT,-1,15).x>width:value=value.left(value.length()-1)
	return value+"…"
func picture_rect()->Rect2:
	if picture==null:return Rect2()
	var dimensions=picture.get_size();dimensions*=minf((size.x-8)/dimensions.x,(size.y-8)/dimensions.y)
	return Rect2((size-dimensions)*.5,dimensions)
func hotkey_layout()->Dictionary:
	var pixels=19
	while pixels>11 and game.bold_font.get_string_size(hotkey,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x>size.x-12:pixels-=1
	var dimensions=game.bold_font.get_string_size(hotkey,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels)
	var baseline=Vector2(maxf(13,dimensions.x*.5+6),maxf(20,game.bold_font.get_ascent(pixels)+4))
	return {"at":baseline,"pixels":pixels,"rect":Rect2(baseline-Vector2(dimensions.x*.5+2,game.bold_font.get_ascent(pixels)+2),Vector2(dimensions.x+4,game.bold_font.get_height(pixels)+4))}
func _draw():
	var center=size*0.5;var radius=size.x*0.5-5
	if picture:
		draw_texture_rect(picture,picture_rect(),false,Color(.65,.65,.62,.78) if locked else Color(.80,.80,.76) if is_pressed() else Color.WHITE)
	if is_hovered():draw_arc(center,radius+1,0,TAU,64,Color("ffedb8"),2,true)
	if cooldown>0:
		draw_circle(center,radius-2,Color("34251dcc"))
		draw_arc(center,radius,-PI*0.5,-PI*0.5+TAU*clampf(cooldown/maxf(max_cooldown,0.01),0,1),64,Color("ffe7b9"),4,true)
		write_text(center+Vector2(0,10),cooldown_text(),30 if size.x>=90 else 24,true)
	if not count.is_empty():write_text(Vector2(size.x-15,size.y-5),count,19,true)
	var key=hotkey_layout();write_text(key.at,hotkey,key.pixels,true)
	write_text(Vector2(size.x*0.5,size.y+21),caption_text(),15)
	if not rank_text.is_empty() and cooldown<=0:write_text(Vector2(20,size.y-3),rank_text,12)
func write_text(at:Vector2,value:String,font_size:int,bold=false):
	var font=game.bold_font if bold else game.fonts
	at.x-=font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x*0.5
	draw_string_outline(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,4,Color("263931"))
	draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("fff5db"))
