extends RefCounted

const Dungeon=preload("res://scripts/dungeon.gd")
const Art=preload("res://scripts/environment_art.gd")
const FloorTiles=preload("res://scripts/floor_tile_art_v04.gd")
const MASK_SIZE=64
const MASK_OFFSET=12
var game:Node2D
var terrain:ColorRect
var material:ShaderMaterial
var props:Array=[]
var map
var ground_profile:Dictionary={}
var ground_draws=0

func _init(owner_node:Node2D):
	game=owner_node
	material=ShaderMaterial.new();material.shader=load("res://shaders/forest_ground.gdshader")
	terrain=ColorRect.new();terrain.position=Vector2(-800,-450);terrain.size=Vector2(3200,1800);terrain.mouse_filter=Control.MOUSE_FILTER_IGNORE
	material.set_shader_parameter("terrain_extent",terrain.size);material.set_shader_parameter("terrain_origin",terrain.position)
	terrain.z_index=-10;terrain.material=material;game.add_child(terrain)
	terrain.draw.connect(func():
		if terrain.visible and map!=null:ground_draws+=1)

func rebuild(dungeon):
	map=dungeon
	var mask=Image.create(MASK_SIZE,MASK_SIZE,false,Image.FORMAT_R8);mask.fill(Color.BLACK)
	for cell in map.path_cells:mask.set_pixel(cell.x+MASK_OFFSET,cell.y+MASK_OFFSET,Color.WHITE)
	material.set_shader_parameter("walk_mask",ImageTexture.create_from_image(mask))
	material.set_shader_parameter("camp",map.spawn)
	ground_profile=FloorTiles.apply(material,map.zone,map.floor_number)
	ground_draws=0;terrain.queue_redraw()
	props.clear()
	var ids=Art.ids(map.zone,map.floor_number);var rng=RandomNumberGenerator.new();rng.seed=map.seed_value+419
	# Stable art IDs replace old hard-coded forest-sheet slots. Every decorative
	# origin remains outside walkable cells, with wider entrance/exit clearings.
	for x in range(-10,Dungeon.SIZE+12,3):
		for y in range(-10,Dungeon.SIZE+12,3):
			var pos=Vector2(x,y)
			if not clear_for_prop(pos):continue
			var art_id=ids[props.size()%ids.size()]
			var size_value=Art.height(art_id)*rng.randf_range(.92,1.08)
			props.append({"pos":pos,"art_id":art_id,"size":size_value,"flip":rng.randf()<.5,"render_id":props.size(),"alpha":1.0})
	# No decorative shelter/sign is inserted on the spawn or first passage.

func ground_evidence()->Dictionary:
	var atlas_texture=material.get_shader_parameter("material_atlas")
	var ground_panel:Vector2=material.get_shader_parameter("ground_panel")
	var path_panel:Vector2=material.get_shader_parameter("path_panel")
	return {"profile":ground_profile.get("id",""),"ground_id":ground_profile.get("ground",""),"path_id":ground_profile.get("path",""),
		"atlas":atlas_texture.resource_path if atlas_texture!=null else "","shader":material.shader.resource_path,"draws":ground_draws,
		"ground_panel":[ground_panel.x,ground_panel.y],"path_panel":[path_panel.x,path_panel.y],"sampling":"world-anchored mirrored","fallback":false}

func clear_for_prop(pos:Vector2)->bool:
	if pos.distance_to(map.spawn)<6.0 or pos.distance_to(map.exit_position)<4.0:return false
	var cell=Vector2i(roundi(pos.x),roundi(pos.y))
	for dx in range(-2,3):
		for dy in range(-2,3):
			if map.walkable(Vector2(cell+Vector2i(dx,dy))):return false
	return true

static func actor_before(a:Dictionary,b:Dictionary)->bool:
	var first=a.data.pos.x+a.data.pos.y
	var second=b.data.pos.x+b.data.pos.y
	if first!=second:return first<second
	if a.type!=b.type:return a.type<b.type
	return int(a.data.get("render_id",a.data.get("id",0)))<int(b.data.get("render_id",b.data.get("id",0)))

static func approach_alpha(current:float,target:float,delta:float)->float:
	return lerpf(current,target,1.0-exp(-8.0*delta))

func update_camera(delta:float=0.0167):
	terrain.visible=game.session.connected
	material.set_shader_parameter("camera",game.camera_pos)
	material.set_shader_parameter("screen_anchor",game.screen_center())
	if not game.session.state.players.has(game.session.local_id):return
	var player=game.session.state.players[game.session.local_id]
	var body=game.world_point(player.pos)-Vector2(0,52)
	for prop in props:
		var data=Art.frame(prop.art_id);var scale=prop.size/data.height
		var rect=Rect2(game.world_point(prop.pos)-data.foot*scale,data.texture.get_size()*scale)
		var covered=prop.pos.x+prop.pos.y>player.pos.x+player.pos.y-1.0 and rect.has_point(body)
		prop.alpha=approach_alpha(prop.alpha,.25 if covered else 1.,delta)

func visible_props()->Array:
	var result=[]
	var viewport=game.get_viewport()
	var view=(viewport.canvas_transform.affine_inverse()*viewport.get_visible_rect()).grow(300.0)
	for prop in props:
		var point=game.world_point(prop.pos)
		if view.has_point(point):result.append({"type":"scenery","data":prop})
	return result

func draw_prop(prop:Dictionary):
	var point=game.world_point(prop.pos);var data=Art.frame(prop.art_id);var scale=prop.size/data.height
	var alpha=prop.get("alpha",1.)
	game.draw_set_transform(point,0,Vector2(1,.44))
	game.draw_circle(Vector2.ZERO,prop.size*.19,Color(.17,.25,.10,.15*alpha))
	game.draw_set_transform(point,0,Vector2(-1 if prop.flip else 1,1))
	game.draw_texture_rect(data.texture,Rect2(-data.foot*scale,data.texture.get_size()*scale),false,Color(1,1,1,alpha))
	if game.has_method("record_art_usage"):game.record_art_usage("environment",prop.art_id)
	game.draw_set_transform(Vector2.ZERO)
