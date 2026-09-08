extends RefCounted

const SIZE = 38
var seed_value: int
var floor_cells: Dictionary = {}
var rooms: Array[Vector2i] = []
var spawn = Vector2.ZERO
var zone="forest"
var path_cells:Dictionary={}
var facility_cells:Dictionary={}

func _init(value: int = 20260908,zone_name:String="forest"):
	seed_value = value
	zone=zone_name
	if zone=="town":
		spawn=Vector2(19,23)
		for x in range(5,34):
			for y in range(5,34):floor_cells[Vector2i(x,y)]=true
		rooms.append(Vector2i(spawn))
		for facility in preload("res://scripts/world_catalog.gd").FACILITIES.values():
			var cursor=Vector2i(spawn);var end=Vector2i(facility.pos)
			while cursor!=end:
				if cursor.x!=end.x:cursor.x+=signi(end.x-cursor.x)
				else:cursor.y+=signi(end.y-cursor.y)
				for off in [Vector2i.ZERO,Vector2i.ONE,Vector2i.RIGHT,Vector2i.DOWN]:path_cells[cursor+off]=true
			for dx in range(1,4 if facility.art!=5 else 2):
				for dy in range(1,4 if facility.art!=5 else 2):facility_cells[end-Vector2i(dx,dy)]=true
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
	path_cells=floor_cells

func walkable(pos: Vector2) -> bool:
	var cell=Vector2i(roundi(pos.x),roundi(pos.y))
	return pos.is_finite() and floor_cells.has(cell) and not facility_cells.has(cell)

func in_town(pos: Vector2) -> bool:
	return zone=="town" or pos.distance_to(spawn) < 3.7

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
