extends RefCounted

const Dungeon = preload("res://scripts/dungeon.gd")
const MASK_SIZE = 64
const MASK_OFFSET = 12
var game: Node2D
var terrain: ColorRect
var material: ShaderMaterial
var sprites: Array[AtlasTexture] = []
var props: Array = []
var map

func _init(owner_node: Node2D):
	game=owner_node
	var sheet: Texture2D=load("res://assets/environment/forest_props.png")
	var regions=JSON.parse_string(FileAccess.get_file_as_string("res://assets/environment/atlas_regions.json"))
	for entry in regions:
		var sprite=AtlasTexture.new()
		sprite.atlas=sheet
		var r=entry.rect
		sprite.region=Rect2(r[0],r[1],r[2],r[3])
		sprite.filter_clip=true
		sprites.append(sprite)
	material=ShaderMaterial.new()
	material.shader=load("res://shaders/forest_ground.gdshader")
	terrain=ColorRect.new()
	terrain.size=Vector2(1440,900)
	terrain.mouse_filter=Control.MOUSE_FILTER_IGNORE
	terrain.z_index=-10
	terrain.material=material
	game.add_child(terrain)

func rebuild(dungeon):
	map=dungeon
	var mask=Image.create(MASK_SIZE,MASK_SIZE,false,Image.FORMAT_R8)
	mask.fill(Color.BLACK)
	for cell in map.path_cells:
		mask.set_pixel(cell.x+MASK_OFFSET,cell.y+MASK_OFFSET,Color.WHITE)
	material.set_shader_parameter("walk_mask",ImageTexture.create_from_image(mask))
	material.set_shader_parameter("camp",map.spawn)
	material.set_shader_parameter("theme",1 if map.zone=="cave" else 2 if map.zone=="ruins" else 0)
	material.set_shader_parameter("town",map.zone=="town")
	material.set_shader_parameter("biome",int((map.floor_number-1)/10) if map.floor_number>0 else -1)
	props.clear()
	var rng=RandomNumberGenerator.new()
	rng.seed=map.seed_value+419
	# Trunks and rocks occupy the blocked meadow, leaving the playable clearing open.
	for x in range(-10,Dungeon.SIZE+12,2):
		for y in range(-10,Dungeon.SIZE+12,2):
			var pos=Vector2(x,y)+Vector2(rng.randf_range(-0.35,0.35),rng.randf_range(-0.35,0.35))
			if map.walkable(pos) or rng.randf()<0.10: continue
			var near_path=false
			var cell=Vector2i(roundi(pos.x),roundi(pos.y))
			for dx in range(-2,3):
				for dy in range(-2,3):
					var nearby=cell+Vector2i(dx,dy)
					if map.floor_cells.has(nearby) and pos.distance_squared_to(Vector2(nearby))<4.0:near_path=true
			var kind=0 if rng.randf()<0.69 else 1
			if near_path:kind=2 if rng.randf()<0.45 else 3
			var size_value=rng.randf_range(185,230) if kind<2 else rng.randf_range(52,78)
			props.append({"pos":pos,"sprite":kind,"size":size_value,"flip":rng.randf()<0.5})
	# Small vegetation follows actual collision edges, replacing decorative dotted borders.
	for cell in map.floor_cells:
		if posmod(cell.x*17+cell.y*29,4)!=0:continue
		for off in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if not map.floor_cells.has(cell+off):
				props.append({"pos":Vector2(cell)+Vector2(off)*0.84,"sprite":3,"size":rng.randf_range(63,83),"flip":false})
	if map.zone!="town":props.append({"pos":map.spawn+Vector2(-0.75,-0.75),"sprite":5,"size":200.0,"flip":false})
	for i in [0,3,6]:
		if i>=map.rooms.size():continue
		var pos=Vector2(map.rooms[i])+Vector2(2.3,0.3)
		props.append({"pos":pos,"sprite":4,"size":88.0,"flip":false})
	for i in range(props.size()):
		if map.zone=="cave":props[i].sprite=2;props[i].size=110 if props[i].size>100 else 65
		elif map.zone=="ruins" and props[i].sprite<2:props[i].sprite=2;props[i].size=125
		props[i]["render_id"]=i
		props[i]["alpha"]=1.0

static func actor_before(a:Dictionary,b:Dictionary)->bool:
	var first=a.data.pos.x+a.data.pos.y
	var second=b.data.pos.x+b.data.pos.y
	if first!=second:return first<second
	# A total order prevents heapsort from swapping overlapping shrubs at equal depth.
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
		if prop.sprite>=2:continue
		var dimensions=Vector2(float(sprites[prop.sprite].get_width())/sprites[prop.sprite].get_height()*prop.size,prop.size)
		var rect=Rect2(game.world_point(prop.pos)-Vector2(dimensions.x*0.5,dimensions.y*0.97),dimensions).grow(-18)
		var covered=prop.pos.x+prop.pos.y>player.pos.x+player.pos.y-1.0 and rect.has_point(body)
		prop.alpha=approach_alpha(prop.alpha,0.28 if covered else 1.0,delta)

func visible_props() -> Array:
	var result=[]
	for prop in props:
		var point=game.world_point(prop.pos)
		if point.x > -300 and point.x < 1740 and point.y > -40 and point.y < 1250:
			result.append({"type":"scenery","data":prop})
	return result

func draw_prop(prop: Dictionary):
	var point=game.world_point(prop.pos)
	var sprite=sprites[prop.sprite]
	var dimensions=Vector2(float(sprite.get_width())/sprite.get_height()*prop.size,prop.size)
	var alpha=prop.get("alpha",1.0)
	game.draw_set_transform(point,0,Vector2(1,0.44))
	game.draw_circle(Vector2.ZERO,prop.size*(0.20 if prop.sprite<2 else 0.24),Color(0.17,0.25,0.10,0.19*alpha))
	game.draw_set_transform(Vector2.ZERO)
	game.draw_set_transform(point,0,Vector2(-1 if prop.flip else 1,1))
	var tint=Color(.75,.92,1,alpha) if map.zone=="cave" else Color(1,1,1,alpha)
	if map.floor_number>0:
		var biome=int((map.floor_number-1)/10)
		if biome==4:tint=Color(.65,.52,.44,alpha)
		elif biome==5:tint=Color(.68,.88,1.08,alpha)
		elif biome==3:tint=Color(.8,.78,1.,alpha)
		elif biome==7:tint=Color(1.05,.83,.6,alpha)
		elif biome>=8:tint=Color(.85,.78,1.,alpha)
	game.draw_texture_rect(sprites[prop.sprite],Rect2(-Vector2(dimensions.x*0.5,dimensions.y*0.97),dimensions),false,tint)
	game.draw_set_transform(Vector2.ZERO)
	if map.floor_number>0:draw_crystals(prop)

func draw_crystals(prop:Dictionary):
	var biome=int((map.floor_number-1)/10)
	if biome not in [1,5,8,9] or prop.sprite!=2 or int(prop.render_id)%3!=0:return
	var foot=game.world_point(prop.pos);var height=prop.size*.75
	var color=Color("70cad4") if biome==1 else Color("b9e6ef") if biome==5 else Color("bfb0df")
	for i in range(3):
		var x=(i-1)*16.;var top=foot+Vector2(x,-height*(.65+.18*i))
		var left=foot+Vector2(x-12,-12);var right=foot+Vector2(x+12,-8)
		game.draw_colored_polygon(PackedVector2Array([top,left,right]),color.darkened(.25))
		game.draw_colored_polygon(PackedVector2Array([top,foot+Vector2(x,0),right]),color)
		game.draw_line(top,foot+Vector2(x,-2),color.lightened(.28),1.5,true)
