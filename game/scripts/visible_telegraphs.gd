extends Node2D
const Attacks=preload("res://scripts/monster_attacks.gd")
const Priority=preload("res://scripts/telegraph_priority.gd")
var records:Array=[]
var game
var mask_material:ShaderMaterial
func setup(owner_game):
	game=owner_game;z_index=-1
	mask_material=ShaderMaterial.new();mask_material.shader=preload("res://shaders/visible_ground.gdshader");material=mask_material
func world_point(pos:Vector2)->Vector2:return game.world_point(pos)
func screen_point(pos:Vector2)->Vector2:return game.get_global_transform_with_canvas()*game.world_point(pos)
func _process(_delta):
	visible=game!=null and game.session!=null and game.session.connected
	if not visible:return
	records=Priority.collect(game.session.state,game.dungeon,game.session.local_id)
	Priority.apply_visibility(records,game.vision,screen_point,get_viewport().get_visible_rect())
	mask_material.set_shader_parameter("enabled",game.vision.active)
	if game.vision.active:
		mask_material.set_shader_parameter("sight_mask",game.vision.texture)
		mask_material.set_shader_parameter("mask_size",float(game.vision.extent))
	mask_material.set_shader_parameter("camera",game.camera_pos)
	mask_material.set_shader_parameter("screen_anchor",game.screen_center())
	queue_redraw()
func _draw():
	if game==null or game.session==null or not game.session.connected:return
	# Each pixel is clipped against current sight, not an area's origin or end.
	for tool in game.session.state.get("tactical_tools",[]):draw_tool(tool)
	for event in game.effects:
		if event.type=="monster_attack":Attacks.draw_area(self,event.area,Color(1,.73,.35,event.life/event.max_life))
	for entry in records:
		var opacity=(.18 if entry.priority==2 else .12) if entry.fill else 0.
		Attacks.draw_area(self,entry.area,Priority.tint(entry),opacity,3. if entry.priority==2 else 1.5)

func draw_tool(tool:Dictionary):
	var color=Color("62dac0") if tool.owner==game.session.local_id else Color("75b2d7")
	var area=Attacks.area("circle",tool.pos,tool.pos,tool.radius)
	var spent=tool.state=="spent"
	if spent:color.a=clampf((tool.expires-game.session.state.clock)/.6,0.,1.)
	Attacks.draw_area(self,area,color,.12 if spent else .035,2.)
	var center=world_point(tool.pos)
	var data=preload("res://scripts/consumables.gd").ITEMS[tool.item]
	var point=center
	if tool.state=="arming":
		var progress=clampf((game.session.state.clock-tool.created)/(tool.ready-tool.created),0.,1.)
		draw_arc(center,18,-PI*.5,-PI*.5+TAU*progress,24,color,2.)
		if tool.item!="snare_trap":point=world_point(tool.from).lerp(center,progress)+Vector2(0,-sin(progress*PI)*42.)
	preload("res://scripts/icon_library.gd").draw(self,data.icon,Rect2(point-Vector2(13,13),Vector2(26,26)),Color(1,1,1,color.a))
	if tool.item=="snare_trap" and not spent:
		var owner_name=str(game.session.state.players.get(tool.owner,{}).get("name",""))
		draw_string_outline(game.fonts,center+Vector2(-25,31),owner_name,HORIZONTAL_ALIGNMENT_CENTER,50,12,3,Color("142a30"))
		draw_string(game.fonts,center+Vector2(-25,31),owner_name,HORIZONTAL_ALIGNMENT_CENTER,50,12,color)
