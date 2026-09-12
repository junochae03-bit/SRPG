extends Node2D
const Attacks=preload("res://scripts/monster_attacks.gd")
var game
var mask_material:ShaderMaterial
func setup(owner_game):
	game=owner_game;z_index=-1
	mask_material=ShaderMaterial.new();mask_material.shader=preload("res://shaders/visible_ground.gdshader");material=mask_material
func world_point(pos:Vector2)->Vector2:return game.world_point(pos)
func _process(_delta):
	visible=game!=null and game.session!=null and game.session.connected
	if not visible:return
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
	for area in game.session.state.get("enemy_attacks",[]):Attacks.draw_area(self,area,Color("ed8268"))
	for enemy in game.session.state.enemies.values():
		if enemy.hp<=0 or enemy.get("windup",0)<=0:continue
		if enemy.get("boss",false) and not enemy.get("raid",false):
			var config=preload("res://scripts/world_catalog.gd").ENEMIES[enemy.kind]
			var radius=.9 if config.ai in ["ranged","healer"] else config.range
			Attacks.draw_area(self,Attacks.area("circle",enemy.pos,enemy.attack_pos,radius),Color("ed8268"))
		for area in enemy.get("attack_areas",[]):Attacks.draw_area(self,area,Color("ed8268"))
	for event in game.effects:
		if event.type=="monster_attack":Attacks.draw_area(self,event.area,Color(1,.73,.35,event.life/event.max_life))
