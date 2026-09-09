extends Button
var picture:Texture2D
var game
var hotkey=""
var caption=""
func setup(owner_game,texture:Texture2D,title:String,key:String,callback:Callable):
	material=preload("res://scripts/gat_art.gd").material()
	game=owner_game;picture=texture;hotkey=key;caption=title;tooltip_text=title+" ("+key+")"
	size=Vector2(90,108);custom_minimum_size=size;focus_mode=Control.FOCUS_NONE;mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","focus"]:add_theme_stylebox_override(state,StyleBoxEmpty.new())
	pressed.connect(callback)
	mouse_entered.connect(queue_redraw);mouse_exited.connect(queue_redraw)
func _draw():
	var dimensions=picture.get_size();dimensions*=78/maxf(dimensions.x,dimensions.y)
	var tint=Color(1.2,1.2,1.2) if is_hovered() else Color.WHITE
	if is_pressed():tint=Color(.8,.9,.9)
	draw_texture_rect(picture,Rect2(Vector2(size.x*.5,42)-dimensions*.5,dimensions),false,tint)
	write(Vector2(13,23),hotkey,19,true)
	write(Vector2(size.x*.5,103),caption,16)
func write(at:Vector2,value:String,pixels:int,bold=false):
	var font=game.bold_font if bold else game.fonts;at.x-=font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x*.5
	draw_string_outline(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,4,Color("263931"))
	draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,Color("fff3cf"))
