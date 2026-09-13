extends RefCounted
## A few low ground silhouettes at room edges, never passage blockers or loot.
const CATALOG="res://assets/cave_remains_v06/catalog.json"
const MAX_REMAINS=5
const SEPARATION=8.
static var data:Dictionary={}
static var textures:Dictionary={}
static func catalog()->Dictionary:
	if data.is_empty():data=JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	return data
static func texture(key:String)->AtlasTexture:
	if not textures.has(key):
		var entry=catalog();var r=entry.sprites[key].rect
		var atlas=AtlasTexture.new();atlas.atlas=load(entry.sheet)
		atlas.region=Rect2(r[0],r[1],r[2],r[3]);atlas.filter_clip=true;textures[key]=atlas
	return textures[key]
static func suitable(map,pos:Vector2,placed:Array)->bool:
	if not map.walkable(pos) or pos.distance_to(map.spawn)<8. or pos.distance_to(map.exit_position)<8.:return false
	# Keep a full walking tile around the cluster; select an edge, not a doorway.
	for offset in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		if not map.walkable(pos+offset):return false
	var edge=false
	for offset in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		if not map.walkable(pos+offset*3.):edge=true
	if not edge:return false
	for site in map.exploration_sites:
		if pos.distance_to(site.pos)<5.:return false
	for region in map.hidden_regions:
		for key in ["pos","center","forward_exit"]:
			if region.has(key) and pos.distance_to(region[key])<5.:return false
	for cue in map.exploration_cues:
		for mark in cue.marks:
			if pos.distance_to(mark.pos)<4.5:return false
	for row in placed:
		if pos.distance_to(row.pos)<SEPARATION:return false
	return true
static func generate(map)->Array:
	if map.floor_number<=0 or map.raid_arena:return []
	var rng=RandomNumberGenerator.new();rng.seed=map.seed_value+120531
	var result=[];var rooms=[]
	for index in range(1,map.rooms.size()-1):rooms.append({"index":index,"rank":rng.randf()})
	rooms.sort_custom(func(a,b):return a.rank<b.rank)
	var keys=["skull","ribcage","lizard","carapace"]
	var theme=preload("res://scripts/environment_art.gd").theme(map.zone,map.floor_number)
	if theme in ["lava","machine","core"]:keys=["skull","ribcage","carapace"]
	for room in rooms:
		if result.size()>=MAX_REMAINS:break
		if rng.randf()<.25:continue
		var center=Vector2(map.rooms[room.index]);var radius=float(map.room_radii[room.index])
		for attempt in range(32):
			var pos=(center+Vector2.from_angle(rng.randf()*TAU)*radius*rng.randf_range(.65,1.)).round()
			if not suitable(map,pos,result):continue
			var kind=keys[rng.randi_range(0,keys.size()-1)];var widths=catalog().sprites[kind].width_pixels
			var row={"pos":pos,"kind":kind,"width":rng.randf_range(widths[0],widths[1]),"rotation":rng.randf_range(-.45,.45),"room":room.index}
			if not footprint(map,row).all(func(point):return map.walkable(point) and map.line_clear(pos,point)):continue
			result.append(row)
			break
	return result
static func footprint(map,row:Dictionary)->Array:
	var r=catalog().sprites[row.kind].rect
	var half=Vector2(row.width,row.width*float(r[3])/float(r[2]))*.5
	var points=[]
	for unit in [Vector2(-1,-1),Vector2(0,-1),Vector2(1,-1),Vector2(-1,0),Vector2.ZERO,Vector2(1,0),Vector2(-1,1),Vector2(0,1),Vector2(1,1)]:
		points.append(row.pos+map.from_iso((unit*half).rotated(row.rotation)))
	return points
static func visible(game,rows:Array)->Array:
	return rows.filter(func(row):return game.vision.sees(row.pos) and game.world_point(row.pos).distance_to(game.screen_center())<1100.)
static func draw(game,rows:Array):
	for row in visible(game,rows):
		var art=texture(row.kind);var size=art.get_size()*(float(row.width)/art.get_width())
		game.draw_set_transform(game.world_point(row.pos),row.rotation)
		game.draw_texture_rect(art,Rect2(-size*.5,size),false,Color(.87,.86,.82,.9))
		game.draw_set_transform(Vector2.ZERO)
static func configuration()->Dictionary:
	return {"maximum_per_floor":MAX_REMAINS,"minimum_separation_tiles":SEPARATION,"placement":"room_edges_with_clear_walking_ring","visibility":"current_sight_only","collision":false,"loot":false,"tutorial_and_raid":false,"art_catalog":CATALOG,"size_policy":"catalog_per_species_width","footprint":"rotated_region_corners_and_edges_on_walkable_floor","site_clearance_tiles":5.,"trace_clearance_tiles":4.5}
