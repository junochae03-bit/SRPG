extends RefCounted

const SIZE = 38
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

# Anchors are encounter areas, not tiles in a fixed grid. Each graph keeps
# the entrance at 0 and the guardian at 8 so old floor progression stays valid.
const LAYOUTS={
	"branching":{"points":[[6,7],[17,8],[28,6],[29,18],[19,19],[7,19],[8,30],[20,29],[30,30]],"links":[[0,1],[1,2],[1,4],[4,3],[4,5],[5,6],[4,7],[7,8]]},
	"circuit":{"points":[[6,7],[17,6],[28,8],[31,19],[29,30],[18,31],[7,29],[6,18],[19,19]],"links":[[0,1],[1,2],[2,3],[3,4],[4,5],[5,6],[6,7],[7,0],[3,8],[6,8]]},
	"great_cavern":{"points":[[6,7],[15,10],[27,6],[29,17],[20,18],[7,20],[10,30],[23,29],[31,29]],"links":[[0,1],[1,2],[1,4],[4,3],[4,5],[5,6],[4,7],[7,8],[3,8],[6,7]]},
	"side_hollows":{"points":[[6,6],[16,8],[28,6],[29,17],[18,18],[7,19],[8,30],[20,29],[31,29]],"links":[[0,1],[1,4],[4,7],[7,8],[1,2],[4,3],[4,5],[5,6]]},
	"split_bridges":{"points":[[6,7],[17,6],[29,7],[7,18],[20,17],[31,18],[8,30],[19,30],[30,30]],"links":[[0,1],[1,2],[0,3],[2,5],[3,4],[4,5],[3,6],[5,8],[6,7],[7,8]]},
	"crossed_halls":{"points":[[6,6],[17,7],[29,6],[7,18],[18,18],[30,18],[6,30],[18,30],[30,30]],"links":[[0,1],[1,2],[1,4],[4,3],[3,6],[4,5],[5,8],[4,7],[7,6],[7,8]]}
}

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
	var types=LAYOUTS.keys()
	# A run advances its seed by 7919 on travel. Keep that travel counter out
	# of the family offset so descending visits all six layouts, not just three.
	layout_id=types[posmod(floor_number-1+posmod(seed_value,7919),types.size())]
	layout_rotation=layout_rng.randi_range(0,7)
	var definition:Dictionary=LAYOUTS[layout_id]
	for index in range(definition.points.size()):
		var point=definition.points[index]
		var anchor=Vector2i(point[0],point[1])+Vector2i(layout_rng.randi_range(-1,1),layout_rng.randi_range(-1,1))
		rooms.append(transform_anchor(anchor))
		room_styles.append(posmod(index+layout_rng.randi_range(0,2),3))
	spawn=Vector2(rooms[0]);exit_position=Vector2(rooms[8])
	for index in range(rooms.size()):
		var radius=6 if index==8 else 5 if index==0 else 4
		if layout_id=="great_cavern" and index in [1,3,4,5,7]:radius=5
		carve_room(rooms[index],radius,int(room_styles[index]))
	# Corridors have a full five-cell safe width, including every turn. This
	# gives the player room to sidestep a monster instead of body-blocking a door.
	for link in definition.links:
		var a=rooms[link[0]];var b=rooms[link[1]]
		connections.append([int(link[0]),int(link[1])])
		var bend=Vector2i(a.x,b.y) if layout_rng.randf()<.5 else Vector2i(b.x,a.y)
		if layout_id in ["circuit","great_cavern","split_bridges"]:
			carve_segment(a,b,2)
		else:
			carve_segment(a,bend,2);carve_segment(bend,b,2)
	if layout_id=="great_cavern":
		# Overlapping lobes form one broad chamber, with several entrances and
		# smaller alcoves at its perimeter, rather than another room/corridor grid.
		carve_room(rooms[4],8,1)
		carve_segment(rooms[4],rooms[7],3)
	path_cells=floor_cells
	build_encounters(layout_rng)

func transform_anchor(point:Vector2i)->Vector2i:
	var result=point
	if layout_rotation>=4:result.x=SIZE-1-result.x
	for turn in range(layout_rotation%4):result=Vector2i(SIZE-1-result.y,result.x)
	return result

func carve_room(center:Vector2i,radius:int,style:int):
	for dx in range(-radius,radius+1):
		for dy in range(-radius,radius+1):
			var inside=dx*dx+dy*dy<=radius*radius+2
			if layout_id=="crossed_halls":inside=absi(dx)<=radius and absi(dy)<=radius-1
			elif style==1:inside=float(dx*dx)/(radius*radius)+float(dy*dy)/((radius-1)*(radius-1))<=1.1
			elif style==2:inside=absi(dx)+absi(dy)<=radius+2 and maxi(absi(dx),absi(dy))<=radius
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
	if pos.distance_to(spawn)<8.0 or pos.distance_to(exit_position)<4.0:return false
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
