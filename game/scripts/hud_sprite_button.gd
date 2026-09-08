extends Button
var picture:Texture2D
var game
var hotkey=""
func setup(owner_game,texture:Texture2D,title:String,key:String,callback:Callable):
	game=owner_game;picture=texture;hotkey=key;tooltip_text=title+" ("+key+")"
	size=Vector2(68,68);custom_minimum_size=size;focus_mode=Control.FOCUS_NONE
	for state in ["normal","hover","pressed","focus"]:add_theme_stylebox_override(state,StyleBoxEmpty.new())
	pressed.connect(callback)
	mouse_entered.connect(queue_redraw);mouse_exited.connect(queue_redraw)
func _draw():
	var dimensions=picture.get_size();dimensions*=54/maxf(dimensions.x,dimensions.y)
	var tint=Color(1.2,1.2,1.2) if is_hovered() else Color.WHITE
	if is_pressed():tint=Color(.8,.9,.9)
	draw_texture_rect(picture,Rect2((size-dimensions)*.5,dimensions),false,tint)
	draw_circle(Vector2(55,57),10,Color("21444cbf"))
	draw_string(game.bold_font,Vector2(51,62),hotkey,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("fff2c9"))
