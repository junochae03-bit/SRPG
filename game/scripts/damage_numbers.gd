extends Node2D
const LIMIT=80
const GRADIENT=preload("res://shaders/damage_gradient.gdshader")
var game
var labels:Array=[]
var materials:Array=[]
var visible_count=0
static func format_amount(amount:int)->String:
	if amount<10000:return str(amount)
	var parts:PackedStringArray=[]
	@warning_ignore("integer_division")
	var billions=amount/100000000
	@warning_ignore("integer_division")
	var thousands=(amount%100000000)/10000
	if billions>0:parts.append(str(billions)+"억")
	if thousands>0:parts.append(str(thousands)+"만")
	if amount%10000>0:parts.append(str(amount%10000))
	return " ".join(parts)
class Number extends Node2D:
	var font:Font
	var text=""
	var pixels=23
	var text_width=0.
	var ascent=0.
	func configure(value:String,font_size:int):
		if text==value and pixels==font_size:return
		text=value;pixels=font_size;text_width=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x;ascent=font.get_ascent(pixels);queue_redraw()
	func _draw():
		var baseline=Vector2(0,ascent)
		draw_string_outline(font,baseline,text,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,5,Color("38261f"))
		draw_string_outline(font,baseline,text,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,2,Color.WHITE)
		draw_string(font,baseline,text,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,Color.WHITE)
func setup(owner_game):
	game=owner_game
	for style in [["fff5b9","e2a445",23],["ff8066","ff2929",30],["ffc0a2","f25a60",23]]:
		var mat=ShaderMaterial.new();mat.shader=GRADIENT;mat.set_shader_parameter("top_color",Color(style[0]));mat.set_shader_parameter("bottom_color",Color(style[1]));mat.set_shader_parameter("glyph_height",game.bold_font.get_height(style[2]));materials.append(mat)
	for i in range(LIMIT):
		var label=Number.new();label.font=game.bold_font;label.hide();add_child(label);labels.append(label)
func refresh():
	visible_count=0
	if game.session.connected and game.preferences.values.damage_numbers:
		var entries=game.effects.filter(func(event):return event.get("type","")=="damage" and event.get("life",0)>0)
		var start=maxi(0,entries.size()-LIMIT)
		for i in range(start,entries.size()):
			var event=entries[i];var label=labels[visible_count];visible_count+=1
			var style=1 if event.get("critical",false) else 0 if event.get("enemy",false) else 2
			label.configure(format_amount(int(event.amount)),30 if style==1 else 23);label.material=materials[style]
			var rise=(float(event.get("max_life",.7))-float(event.life))*65.
			label.position=game.world_point(event.pos)-Vector2(label.text_width*.5,85.+rise+label.ascent)
			label.modulate=Color(1,1,1,clampf(float(event.life)/.15,0,1));label.show()
	for i in range(visible_count,LIMIT):labels[i].hide()
func _process(_delta:float):refresh()
