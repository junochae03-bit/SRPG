extends RefCounted

const Dungeon=preload("res://scripts/dungeon.gd")
const Art=preload("res://scripts/environment_art.gd")
const FloorTiles=preload("res://scripts/floor_tile_art_v04.gd")
const MASK_OFFSET=12
const MASK_SIZE=Dungeon.SIZE+MASK_OFFSET*2
const DECORATION_KEEP_RATIO=.55
var game:Node2D
var terrain:ColorRect
var material:ShaderMaterial
var props:Array=[]
# Decoration geometry is immutable for the lifetime of a generated map. Keep
# it separate from the public prop records, whose alpha changes during play.
var _geometry:Array=[]
var map
var map_revision=-1
var ground_profile:Dictionary={}
var ground_draws=0
var material_regions:Dictionary={}
var accent_material=""
const ACCENT_MATERIALS={"forest":"forest","cave":"sky","flood":"dungeon","spore":"forest","lava":"desert","snow":"dungeon","machine":"sky","autumn":"forest","nebula":"dungeon","core":"lava"}

func _init(owner_node:Node2D):
	game=owner_node
	material=ShaderMaterial.new();material.shader=load("res://shaders/forest_ground.gdshader")
	terrain=ColorRect.new();terrain.position=Vector2(-800,-450);terrain.size=Vector2(3200,1800);terrain.mouse_filter=Control.MOUSE_FILTER_IGNORE
	material.set_shader_parameter("terrain_extent",terrain.size);material.set_shader_parameter("terrain_origin",terrain.position)
	material.set_shader_parameter("mask_size",float(MASK_SIZE));material.set_shader_parameter("mask_offset",float(MASK_OFFSET))
	terrain.z_index=-10;terrain.material=material;game.add_child(terrain)
	terrain.draw.connect(func():
		if terrain.visible and map!=null:ground_draws+=1)

func rebuild(dungeon):
	map=dungeon
	map_revision=map.revision
	var mask=Image.create(MASK_SIZE,MASK_SIZE,false,Image.FORMAT_R8);mask.fill(Color.BLACK)
	for cell in map.path_cells:mask.set_pixel(cell.x+MASK_OFFSET,cell.y+MASK_OFFSET,Color.WHITE)
	material.set_shader_parameter("walk_mask",ImageTexture.create_from_image(mask))
	material.set_shader_parameter("camp",map.spawn)
	material.set_shader_parameter("void_shade",.78 if map.floor_number>0 else 1.0)
	ground_profile=FloorTiles.apply(material,map.zone,map.floor_number)
	build_material_regions()
	ground_draws=0;terrain.queue_redraw()
	props.clear();_geometry.clear()
	var ids=Art.available_ids(map.zone,map.floor_number);var allowed=Art.ids(map.zone,map.floor_number)
	var candidate_index=0;var rng=RandomNumberGenerator.new();rng.seed=map.seed_value+419
	# Stable art IDs replace old hard-coded forest-sheet slots. Every decorative
	# origin remains outside walkable cells, with wider entrance/exit clearings.
	for x in range(-10,Dungeon.SIZE+12,3):
		for y in range(-10,Dungeon.SIZE+12,3):
			var pos=Vector2(x,y)
			if not clear_for_prop(pos):continue
			var art_id=ids[candidate_index%ids.size()];candidate_index+=1
			var size_value=Art.height(art_id)*rng.randf_range(.92,1.08)
			var flipped=rng.randf()<.5
			# Leave rejected scenery positions empty. Replacing furniture with more
			# trees would increase canopy density and defeat the requested cleanup.
			if art_id not in allowed:continue
			props.append({"pos":pos,"art_id":art_id,"size":size_value,"flip":flipped,"render_id":props.size(),"alpha":1.0})
	thin_props()
	var frames:Dictionary={}
	for prop in props:
		if not frames.has(prop.art_id):frames[prop.art_id]=Art.frame(prop.art_id)
		var data:Dictionary=frames[prop.art_id]
		var scale=prop.size/data.height
		var point=Dungeon.iso(prop.pos)
		var local_rect=Rect2(-data.foot*scale,data.texture.get_size()*scale)
		_geometry.append({"point":point,"depth":prop.pos.x+prop.pos.y,"texture":data.texture,"local_rect":local_rect,
			"bounds":Rect2(point+local_rect.position,local_rect.size),"shadow_radius":prop.size*.19})
	# No decorative shelter/sign is inserted on the spawn or first passage.

func build_material_regions():
	material_regions.clear();accent_material=""
	var mask=Image.create(MASK_SIZE,MASK_SIZE,false,Image.FORMAT_R8);mask.fill(Color.BLACK)
	if map.floor_number>0:
		accent_material=ACCENT_MATERIALS[ground_profile.id]
		for room_index in range(1,map.rooms.size()):
			var final_room=room_index==map.rooms.size()-1
			if posmod(room_index+map.floor_number,3)!=0 and not final_room:continue
			var center:Vector2i=map.rooms[room_index]
			var radius=9.5 if map.raid_arena and final_room else 4.5 if final_room else 3.5
			for dx in range(-10,11):
				for dy in range(-10,11):
					var cell=center+Vector2i(dx,dy)
					var distance=Vector2(dx,dy).length()
					if not map.floor_cells.has(cell) or distance>=radius:continue
					material_regions[cell]=accent_material
					mask.set_pixel(cell.x+MASK_OFFSET,cell.y+MASK_OFFSET,Color(clampf(radius-distance,0.,1.),0,0))
	material.set_shader_parameter("accent_mask",ImageTexture.create_from_image(mask))
	material.set_shader_parameter("accent_panel",FloorTiles.panel(accent_material) if accent_material!="" else Vector2.ZERO)
	material.set_shader_parameter("accent_strength",.62 if accent_material!="" else 0.)

func thin_props():
	# An independent seed preserves each retained prop's original art, size and
	# flip. Sample across the whole map instead of deleting a band near one edge.
	var rng=RandomNumberGenerator.new();rng.seed=map.seed_value+8189
	var ranked:Array=[]
	for i in range(props.size()):ranked.append({"index":i,"score":rng.randf()})
	ranked.sort_custom(func(a,b):return a.score<b.score if a.score!=b.score else a.index<b.index)
	var selected:Dictionary={};var art_ids:Dictionary={}
	for item in ranked:
		var art_id=props[item.index].art_id
		if not art_ids.has(art_id):selected[item.index]=true;art_ids[art_id]=true
	var target=maxi(selected.size(),ceili(props.size()*DECORATION_KEEP_RATIO))
	for item in ranked:
		if selected.size()>=target:break
		selected[item.index]=true
	var retained:Array=[]
	for i in range(props.size()):
		if selected.has(i):
			props[i].render_id=retained.size();retained.append(props[i])
	props=retained

func ground_evidence()->Dictionary:
	var atlas_texture=material.get_shader_parameter("material_atlas")
	var ground_panel:Vector2=material.get_shader_parameter("ground_panel")
	var path_panel:Vector2=material.get_shader_parameter("path_panel")
	return {"profile":ground_profile.get("id",""),"ground_id":ground_profile.get("ground",""),"path_id":ground_profile.get("path",""),
		"atlas":atlas_texture.resource_path if atlas_texture!=null else "","shader":material.shader.resource_path,"draws":ground_draws,
		"ground_panel":[ground_panel.x,ground_panel.y],"path_panel":[path_panel.x,path_panel.y],"sampling":"world-anchored mirrored","fallback":false,
		"layout":map.layout_id,"accent_material":accent_material,"accent_cells":material_regions.size()}

func clear_for_prop(pos:Vector2)->bool:
	if map.raid_arena and pos.distance_to(map.exit_position)<14.0:return false
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
	# Camera/anchor translation cancels between the body and the decoration.
	# Preserve the original unflipped coverage bounds and offscreen fade updates.
	var body=Dungeon.iso(player.pos)-Vector2(0,52)
	var player_depth=player.pos.x+player.pos.y-1.0
	for i in range(props.size()):
		var prop:Dictionary=props[i];var geometry:Dictionary=_geometry[i]
		var covered=geometry.depth>player_depth and geometry.bounds.has_point(body)
		prop.alpha=approach_alpha(prop.alpha,.25 if covered else 1.,delta)

func visible_props()->Array:
	var result=[]
	var viewport=game.get_viewport()
	var view=(viewport.canvas_transform.affine_inverse()*viewport.get_visible_rect()).grow(300.0)
	var camera:Vector2=game.camera_pos;var anchor:Vector2=game.screen_center()
	for i in range(props.size()):
		if view.has_point(_geometry[i].point-camera+anchor):result.append({"type":"scenery","data":props[i]})
	return result

func draw_prop(prop:Dictionary):
	var geometry:Dictionary=_geometry[int(prop.render_id)]
	var point:Vector2=geometry.point-game.camera_pos+game.screen_center()
	var alpha=prop.get("alpha",1.)
	game.draw_set_transform(point,0,Vector2(1,.44))
	game.draw_circle(Vector2.ZERO,geometry.shadow_radius,Color(.17,.25,.10,.15*alpha))
	game.draw_set_transform(point,0,Vector2(-1 if prop.flip else 1,1))
	game.draw_texture_rect(geometry.texture,geometry.local_rect,false,Color(1,1,1,alpha))
	if game.has_method("record_art_usage"):game.record_art_usage("environment",prop.art_id)
	game.draw_set_transform(Vector2.ZERO)
