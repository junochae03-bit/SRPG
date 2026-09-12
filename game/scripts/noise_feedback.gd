extends Control
const Awareness=preload("res://scripts/enemy_awareness.gd")
const Icons=preload("res://scripts/icon_library.gd")
var game
var label:Label
var context=[]
var cells={}
var edges:Array=[]
var rebuilds=0
func setup(owner_game):
	game=owner_game;mouse_filter=Control.MOUSE_FILTER_IGNORE
	position=Vector2(24,611);size=Vector2(368,36)
	Icons.picture(self,"sound",Vector2(0,4),Vector2(26,26))
	label=game.label(self,"",Vector2(34,0),Vector2(332,36),18)
	label.add_theme_color_override("font_color",Color("ffde9a"));label.add_theme_color_override("font_shadow_color",Color("18212c"));label.add_theme_constant_override("shadow_outline_size",3)
	label.mouse_filter=Control.MOUSE_FILTER_PASS
	label.tooltip_text="소음은 통로를 따라 퍼집니다. 소음으로 유인되는 적은 파티 전체에서 최대 4마리이며, 마지막으로 소리를 들은 뒤 9초 동안 집계됩니다. 시야로 직접 접근한 적은 별도입니다."
	hide()
func _process(_delta:float):
	if game.session==null or not game.session.connected or game.session.paused or not game.hud.visible:hide();return
	var pulse:Dictionary=game.session.state.get("noise",{})
	if pulse.is_empty() or float(pulse.until)<=float(game.session.state.clock):hide();return
	var next=[game.dungeon.get_instance_id(),game.dungeon.revision,pulse.serial]
	if context!=next:
		context=next;rebuilds+=1;edges.clear()
		cells=Awareness.propagation(game.dungeon,pulse.pos,int(pulse.radius)).distances
		for cell in cells:
			for direction in [Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]:
				if cells.has(cell+direction):continue
				var middle=Vector2(cell)+Vector2(direction)*.5;var side=Vector2(-direction.y,direction.x)*.5
				edges.append([Vector2(cell),middle-side,middle+side])
		label.text="소음 %d칸 · 주변 적 경계"%int(pulse.radius)
	show()
func visible_edges()->Array:
	return edges.filter(func(edge):return game.vision.sees(edge[0])) if visible else []
func draw_world():
	if not visible:return
	for edge in visible_edges():game.draw_line(game.world_point(edge[1]),game.world_point(edge[2]),Color("e6b86c88"),1.4,true)
