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
	for event in game.effects:
		if event.type=="monster_attack":Attacks.draw_area(self,event.area,Color(1,.73,.35,event.life/event.max_life))
	for entry in records:
		var opacity=(.18 if entry.priority==2 else .12) if entry.fill else 0.
		Attacks.draw_area(self,entry.area,Priority.tint(entry),opacity,3. if entry.priority==2 else 1.5)
