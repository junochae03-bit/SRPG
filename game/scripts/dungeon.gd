extends RefCounted

const SIZE = 80
const EXPLORATION_SCALE = 1.6
const RAID_SIZE = 50
const Regions=preload("res://scripts/dungeon_regions.gd")
var seed_value: int
var floor_cells: Dictionary = {}
var rooms: Array[Vector2i] = []
var spawn = Vector2.ZERO
var zone="forest"
var floor_number=0
var exit_position=Vector2.ZERO
var path_cells:Dictionary={}
var facility_cells:Dictionary={}
var layout_id="tutorial"
var layout_rotation=0
var connections:Array=[]
var route_cells:Dictionary={}
var encounters:Array=[]
var room_styles:Array=[]
var room_radii:Array=[]
var raid_arena=false
var arena_radius=0.0
var exploration_sites:Array=[]
var hidden_regions:Array=[]
var revealed_regions={}
var opened_regions={}
var revision=0
var region_profile={}

# Anchors are encounter areas, not tiles in a fixed grid. The entrance is
# always first and the guardian is last; raid approaches use only three areas.
const LAYOUTS={
	"branching":{"name":"맞물린 곁굴","points":[[7,7],[23,8],[40,7],[42,23],[29,24],[10,22],[7,40],[22,42],[40,40]],"radii":[5,6,4,5,7,5,4,5,7],"links":[[0,1],[0,5],[1,2],[1,4],[2,3],[3,4],[4,5],[5,6],[6,7],[4,7],[7,8],[3,8]]},
	"circuit":{"name":"고리 협곡","points":[[8,9],[23,6],[40,10],[43,26],[36,41],[21,43],[7,36],[6,22],[25,25]],"radii":[5,5,6,4,5,4,6,4,7],"links":[[0,1],[1,2],[2,3],[3,4],[4,5],[5,6],[6,7],[7,0],[1,8],[3,8],[5,8],[7,8]]},
	"great_cavern":{"name":"겹친 대공동","points":[[8,7],[23,9],[41,7],[41,23],[25,25],[8,23],[8,41],[26,41],[42,41]],"radii":[5,6,4,6,8,5,4,6,6],"links":[[0,1],[0,5],[1,2],[1,4],[2,3],[3,4],[4,5],[5,6],[6,7],[4,7],[7,8],[3,8]]},
	"side_hollows":{"name":"휘감긴 지하수로","points":[[8,7],[25,6],[41,13],[34,27],[20,18],[7,23],[9,40],[24,41],[42,41]],"radii":[5,4,6,5,4,7,5,4,7],"links":[[0,1],[0,5],[1,2],[1,4],[2,3],[3,4],[4,5],[5,6],[6,7],[4,7],[7,8],[3,8]]},
	"split_bridges":{"name":"쌍둥이 균열","points":[[7,12],[19,6],[34,7],[18,24],[33,24],[43,18],[8,40],[28,42],[43,37]],"radii":[5,6,4,4,7,5,6,4,7],"links":[[0,1],[0,6],[1,3],[3,6],[1,2],[3,4],[6,7],[2,5],[5,8],[8,7],[7,4],[4,2]]}
}
const RAID_LAYOUTS={
	"raid_caldera":{"name":"심연 원형 전장","arena_style":0},
	"raid_gallery":{"name":"왕좌의 대회랑","arena_style":1},
	"raid_crucible":{"name":"마력 십자 성소","arena_style":2}
}
const RAID_POINTS=[[25,7],[25,17],[25,36]]
const RAID_LINKS=[[0,1],[1,2]]

func _init(value: int = 20260908,zone_name:String="forest",depth:int=0):
	seed_value = value
	zone=zone_name;floor_number=clampi(depth,0,100)
	if zone=="town":
		generate_town()
		return
	if floor_number>0:
		generate_floor()
		return
	var rng = RandomNumberGenerator.new()
	rng.seed = value
	for row in range(3):
		for n in range(3):
			var col = n if row % 2 == 0 else 2 - n
			var center = Vector2i(6 + col * 12 + rng.randi_range(-1, 1), 6 + row * 12 + rng.randi_range(-1, 1))
			rooms.append(center)
			for x in range(center.x - 3, center.x + 4):
				for y in range(center.y - 3, center.y + 4):
					if zone=="ruins" or Vector2(x-center.x,y-center.y).length_squared() <= (17.5 if zone=="cave" else 12.5):
						floor_cells[Vector2i(x, y)] = true
			if rooms.size() > 1:
				var cursor = rooms[-2]
				while cursor != center:
					if cursor.x != center.x:
						cursor.x += signi(center.x - cursor.x)
					else:
						cursor.y += signi(center.y - cursor.y)
					for offset in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
						floor_cells[cursor + offset] = true
	spawn = Vector2(rooms[0])
	if zone=="ruins":
		for i in [0,3]:
			var cursor=rooms[i];var end=rooms[i+5]
			while cursor!=end:
				if cursor.y!=end.y:cursor.y+=signi(end.y-cursor.y)
				else:cursor.x+=signi(end.x-cursor.x)
				floor_cells[cursor]=true;floor_cells[cursor+Vector2i.RIGHT]=true
	exit_position=Vector2(rooms.back())
	path_cells=floor_cells

func generate_town():
	layout_id="town_plaza";spawn=Vector2(19,23);rooms.append(Vector2i(spawn))
	for x in range(5,34):
		for y in range(5,36):floor_cells[Vector2i(x,y)]=true
	# An additional northern shopping terrace and a broad eastern training
	# green share the town's safe, unobstructed central plaza.
	for x in range(29,45):
		for y in range(24,41):floor_cells[Vector2i(x,y)]=true
	town_disk(Vector2i(9,8),6,false)
	town_disk(Vector2i(19,23),5,true)
	town_disk(Vector2i(37,31),6,true)
	for key in preload("res://scripts/world_catalog.gd").FACILITIES:
		var facility:Dictionary=preload("res://scripts/world_catalog.gd").FACILITIES[key]
		var end=Vector2i(facility.pos)
		if facility.get("footprint",true):
			for dx in range(1,4 if facility.art!=5 else 2):
				for dy in range(1,4 if facility.art!=5 else 2):facility_cells[end-Vector2i(dx,dy)]=true
		if key=="costume":
			town_path(Vector2i(spawn),Vector2i(14,23));town_path(Vector2i(14,23),Vector2i(14,8));town_path(Vector2i(14,8),end)
		elif key=="training":
			town_path(Vector2i(spawn),Vector2i(25,33));town_path(Vector2i(25,33),Vector2i(37,33))
		else:town_path(Vector2i(spawn),end)
	# Buildings occupy their original visible footprint, never an invisible
	# collision pad under the training instructor or the target.
	for cell in facility_cells:path_cells.erase(cell)

func town_disk(center:Vector2i,radius:int,paving:bool):
	for dx in range(-radius,radius+1):
		for dy in range(-radius,radius+1):
			if dx*dx+dy*dy>radius*radius:continue
			var cell=center+Vector2i(dx,dy)
			floor_cells[cell]=true
			if paving:path_cells[cell]=true

func town_path(from:Vector2i,to:Vector2i):
	var cursor=from
	while true:
		for dx in range(-2,3):
			for dy in range(-2,3):
				var cell=cursor+Vector2i(dx,dy);floor_cells[cell]=true;path_cells[cell]=true
		if cursor==to:break
		if cursor.x!=to.x:cursor.x+=signi(to.x-cursor.x)
		else:cursor.y+=signi(to.y-cursor.y)

func generate_floor():
	var layout_rng=RandomNumberGenerator.new();layout_rng.seed=seed_value+floor_number*4099
	region_profile=Regions.profile(floor_number)
	layout_id=Regions.choose_layout(region_profile,layout_rng)
	layout_rotation=layout_rng.randi_range(0,7)
	var definition:Dictionary=LAYOUTS[layout_id]
	raid_arena=floor_number%10==0
	if raid_arena:
		layout_id=RAID_LAYOUTS.keys()[posmod(int(floor_number/10)-1,RAID_LAYOUTS.size())]
		definition={"points":RAID_POINTS,"links":RAID_LINKS,"radii":[5,5,10]}
		arena_radius=10.
	for index in range(definition.points.size()):
		var point=definition.points[index]
		var anchor=Vector2i(point[0],point[1])+Vector2i(layout_rng.randi_range(-2,2),layout_rng.randi_range(-2,2))
		if not raid_arena:anchor=Vector2i((Vector2(anchor)*EXPLORATION_SCALE).round())
		rooms.append(transform_anchor(anchor))
		room_styles.append(posmod(index+layout_rng.randi_range(0,2),3) if raid_arena else Regions.room_style(region_profile,layout_rng))
		var late_bonus=1 if not raid_arena and floor_number%10>=6 and index>0 and index<8 else 0
		room_radii.append(int(definition.radii[index])+(0 if raid_arena else 2)+late_bonus)
	spawn=Vector2(rooms[0]);exit_position=Vector2(rooms.back())
	for index in range(rooms.size()):
		if raid_arena and index==rooms.size()-1:continue
		var radius=int(room_radii[index])
		carve_room(rooms[index],radius,int(room_styles[index]))
		# Offset lobes give large caverns an irregular shoreline, while small
		# alcoves stay visibly smaller. This does not add collision props.
		if index>0 and index<8 and radius>=6 and (raid_arena or region_profile.lobes):
			carve_room(rooms[index]+Vector2i(2,-1),radius-2,0)
	if raid_arena:carve_arena()
	# Corridors have a full seven-cell safe width, including every turn. This
	# gives the player room to sidestep a monster instead of body-blocking a door.
	for link in definition.links:
		var a=rooms[link[0]];var b=rooms[link[1]]
		connections.append([int(link[0]),int(link[1])])
		if raid_arena:
			carve_segment(a,b,3)
		else:
			# Bowed routes avoid a repeated horizontal/vertical lattice. Wide
			# interleaved segments keep every turn traversable by the whole party.
			var perpendicular=Vector2(b-a).normalized().orthogonal()*layout_rng.randf_range(-region_profile.bend,region_profile.bend)
			var waypoint=Vector2i((Vector2(a+b)*.5+perpendicular).round())
			var half_width=int(region_profile.width)
			waypoint=waypoint.clamp(Vector2i.ONE*(half_width+1),Vector2i.ONE*(SIZE-half_width-2))
			carve_segment(a,waypoint,half_width);carve_segment(waypoint,b,half_width)
	if layout_id=="great_cavern":
		# Overlapping lobes form one broad chamber, with several entrances and
		# smaller alcoves at its perimeter, rather than another room/corridor grid.
		carve_room(rooms[4],10,1)
		carve_segment(rooms[4],rooms[7],3)
	path_cells=floor_cells
	build_encounters(layout_rng)
	exploration_sites=preload("res://scripts/exploration_rooms.gd").generate(self)
	hidden_regions=preload("res://scripts/hidden_rooms.gd").generate(self)

func carve_arena():
	var style=int(RAID_LAYOUTS[layout_id].arena_style)
	for dx in range(-12,13):
		for dy in range(-11,12):
			var inside=dx*dx+dy*dy<=100
			if style==1:inside=absi(dx)<=11 and absi(dy)<=8
			elif style==2:inside=(absi(dx)<=10 and absi(dy)<=7) or (absi(dx)<=7 and absi(dy)<=10)
			if inside:carve_cell(rooms.back()+Vector2i(dx,dy))

func transform_anchor(point:Vector2i)->Vector2i:
	var result=point
	var extent=RAID_SIZE if raid_arena else SIZE
	if layout_rotation>=4:result.x=extent-1-result.x
	for turn in range(layout_rotation%4):result=Vector2i(extent-1-result.y,result.x)
	return result

func carve_room(center:Vector2i,radius:int,style:int):
	for dx in range(-radius,radius+1):
		for dy in range(-radius,radius+1):
			var inside=dx*dx+dy*dy<=radius*radius+2
			if style==1:inside=float(dx*dx)/(radius*radius)+float(dy*dy)/((radius-1)*(radius-1))<=1.1
			elif style==2:inside=absi(dx)+absi(dy)<=radius+2 and maxi(absi(dx),absi(dy))<=radius
			elif style==3:inside=maxi(absi(dx),absi(dy))<=radius and absi(dx)+absi(dy)<=radius*2-2
			if inside:carve_cell(center+Vector2i(dx,dy))

func carve_cell(cell:Vector2i):
	if cell.x>=1 and cell.y>=1 and cell.x<SIZE-1 and cell.y<SIZE-1:floor_cells[cell]=true

func carve_segment(a:Vector2i,b:Vector2i,half_width:int):
	var cursor=a
	while true:
		route_cells[cursor]=true
		for dx in range(-half_width,half_width+1):
			for dy in range(-half_width,half_width+1):carve_cell(cursor+Vector2i(dx,dy))
		if cursor==b:break
		# Interleave axes for a connected, gently diagonal bridge. A cardinal
		# centerline plus the square brush also leaves a five-wide route at bends.
		var remaining=b-cursor
		if absi(remaining.x)>=absi(remaining.y) and remaining.x!=0:cursor.x+=signi(remaining.x)
		else:cursor.y+=signi(remaining.y)

func build_encounters(layout_rng:RandomNumberGenerator):
	if raid_arena:
		encounters.append({"role":"guardian","pos":exit_position,"room":rooms.size()-1,"mob_index":0,"formation":-1})
		return
	var counts=[[2,4,2,3,4,2,4],[4,2,3,2,4,4,2],[2,3,4,4,2,3,3]][layout_rng.randi_range(0,2)]
	var used:Array[Vector2]=[]
	var sequence=0
	for room in range(1,8):
		var formation=posmod(room+layout_rng.randi_range(0,3),4)
		var positions=formation_positions(rooms[room],int(counts[room-1]),formation,layout_rng)
		for candidate in positions:
			var position=find_encounter_position(candidate,rooms[room],used)
			used.append(position)
			encounters.append({"role":"normal","pos":position,"room":room,"mob_index":sequence+floor_number%5,"formation":formation})
			sequence+=1
	var elite_room=3 if layout_id in ["side_hollows","branching"] else 6
	var elite=find_encounter_position(Vector2(rooms[elite_room])+Vector2(0,2.7),rooms[elite_room],used)
	encounters.append({"role":"elite","pos":elite,"room":elite_room,"mob_index":0,"formation":-1})
	encounters.append({"role":"guardian","pos":exit_position,"room":8,"mob_index":0,"formation":-1})

func formation_positions(center:Vector2i,count:int,formation:int,layout_rng:RandomNumberGenerator)->Array:
	var result:Array=[];var angle=layout_rng.randf_range(-PI,PI)
	for index in range(count):
		var offset=Vector2.ZERO
		match formation:
			0:offset=Vector2(cos(index*TAU/count),sin(index*TAU/count))*2.5
			1:offset=Vector2((index-(count-1)*.5)*2.2,(index%2)*1.4-.7)
			2:offset=Vector2(-2.2 if index%2==0 else 2.2,-1.7 if index<2 else 1.7)
			_:offset=Vector2(-2.8+index*1.8,1.8 if index%2==0 else -1.8)
		result.append(Vector2(center)+offset.rotated(angle))
	return result

func find_encounter_position(preferred:Vector2,center:Vector2i,used:Array[Vector2])->Vector2:
	if valid_encounter_position(preferred,used):return preferred
	var best=Vector2(center);var score=INF
	for dx in range(-5,6):
		for dy in range(-5,6):
			var candidate=Vector2(center+Vector2i(dx,dy))
			if not valid_encounter_position(candidate,used):continue
			var distance=candidate.distance_squared_to(preferred)
			if distance<score:best=candidate;score=distance
	assert(score<INF,"A generated encounter must have a clear, separated spawn")
	return best

func valid_encounter_position(pos:Vector2,used:Array[Vector2])->bool:
	if pos.distance_to(spawn)<8.0 or pos.distance_to(exit_position)<(13.0 if raid_arena else 5.0):return false
	# Receiving volumes may be larger than movement collision; give even the
	# large commons a cell of floor around their feet and don't stack silhouettes.
	for off in [Vector2.ZERO,Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
		if not walkable(pos+off):return false
	for previous in used:
		if previous.distance_to(pos)<2.0:return false
	return true

func walkable(pos: Vector2) -> bool:
	var cell=Vector2i(roundi(pos.x),roundi(pos.y))
	return pos.is_finite() and floor_cells.has(cell) and not facility_cells.has(cell)

func in_town(pos: Vector2) -> bool:
	if zone=="town":return not preload("res://scripts/training_ground.gd").contains(pos)
	return pos.distance_to(spawn) < 3.7

func move(pos: Vector2, delta: Vector2) -> Vector2:
	var candidate = pos + Vector2(delta.x, 0)
	if walkable(candidate + Vector2(signf(delta.x) * 0.18, 0)):
		pos.x = candidate.x
	candidate = pos + Vector2(0, delta.y)
	if walkable(candidate + Vector2(0, signf(delta.y) * 0.18)):
		pos.y = candidate.y
	return pos

func line_clear(a: Vector2, b: Vector2) -> bool:
	var steps = maxi(1, ceili(a.distance_to(b) * 5))
	for i in range(steps + 1):
		if not walkable(a.lerp(b, float(i) / steps)):
			return false
	return true

static func iso(pos: Vector2) -> Vector2:
	return Vector2((pos.x - pos.y) * 48, (pos.x + pos.y) * 24)

static func from_iso(pos: Vector2) -> Vector2:
	return Vector2(pos.x / 96 + pos.y / 48, pos.y / 48 - pos.x / 96)
