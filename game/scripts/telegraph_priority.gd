extends RefCounted
## Presentation only: collision and damage remain in MonsterAttacks.
const Attacks=preload("res://scripts/monster_attacks.gd")
const World=preload("res://scripts/world_catalog.gd")
const FILL_LIMIT=4
const WARNING_LIMIT=4
const DIRECTION_SECTORS=8
static func dangerous(area:Dictionary,player:Dictionary,map)->bool:
	return not player.is_empty() and player.get("hp",0)>0 and not player.get("network_leaving",false) and Attacks.contains(area,player.pos) and map.line_clear(area.from,player.pos)
static func geometry_key(area:Dictionary)->String:
	return var_to_str([area.shape,area.from if area.shape in ["line","cone"] else Vector2.ZERO,area.pos,area.radius,area.get("angle",.8) if area.shape=="cone" else 0.,area.get("inner",0.) if area.shape=="ring" else 0.])
static func collect(state:Dictionary,map,owner:int)->Array:
	var candidates=[]
	for area in state.get("enemy_attacks",[]):
		var enemy:Dictionary=state.enemies.get(area.get("enemy",0),{})
		if enemy.is_empty() or enemy.hp<=0 or enemy.get("stun_time",0)>0 or enemy.get("stagger",{}).get("state","") in ["check","down"]:continue
		candidates.append({"area":area,"time":maxf(0,float(area.get("timer",area.get("delay",0)))),"source":area.from})
	for enemy in state.get("enemies",{}).values():
		if enemy.hp<=0 or enemy.get("windup",0)<=0 or enemy.get("stun_time",0)>0 or enemy.get("stagger",{}).get("state","") in ["check","down"]:continue
		var areas:Array=enemy.get("attack_areas",[])
		if enemy.get("boss",false) and not enemy.get("raid",false):
			var config=World.ENEMIES[enemy.kind]
			areas=[Attacks.area("circle",enemy.pos,enemy.attack_pos,.9 if config.ai in ["ranged","healer"] else config.range)]
		for area in areas:candidates.append({"area":area,"time":float(enemy.windup)+maxf(0,float(area.get("delay",0))),"source":area.from})
	var player:Dictionary=state.get("players",{}).get(owner,{})
	var merged={}
	for entry in candidates:
		entry["priority"]=2 if dangerous(entry.area,player,map) else 0
		if entry.priority==0:
			for other in state.get("players",{}).values():
				if dangerous(entry.area,other,map):entry.priority=1;break
		entry["count"]=1
		var threat={"source":entry.source,"priority":entry.priority,"time":entry.time,"count":1}
		var key=geometry_key(entry.area)
		if merged.has(key):
			merged[key].count+=1;merged[key].threats.append(threat)
			if entry.priority>merged[key].priority:merged[key].priority=entry.priority;merged[key].time=entry.time
			elif entry.priority==merged[key].priority:merged[key].time=minf(merged[key].time,entry.time)
		else:entry["threats"]=[threat];merged[key]=entry
	var records=merged.values()
	records.sort_custom(func(a,b):return a.priority<b.priority if a.priority!=b.priority else a.time>b.time)
	for entry in records:entry["fill"]=false
	return records
static func rectangle(rect:Rect2)->PackedVector2Array:
	return PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
static func polygon_bounds(points:PackedVector2Array)->Rect2:
	var bounds=Rect2(points[0],Vector2.ZERO)
	for point in points:bounds=bounds.expand(point)
	return bounds
static func view_context(vision,project:Callable,viewport:Rect2)->Dictionary:
	var origin:Vector2=project.call(Vector2.ZERO)
	var transform=Transform2D(project.call(Vector2.RIGHT)-origin,project.call(Vector2.DOWN)-origin,origin)
	var tiles=[]
	if vision.active:
		for cell in vision.visible_cells:
			var tile=PackedVector2Array()
			for offset in [Vector2(-.5,-.5),Vector2(.5,-.5),Vector2(.5,.5),Vector2(-.5,.5)]:tile.append(transform*(Vector2(cell)+offset))
			var bounds=polygon_bounds(tile)
			if viewport.intersects(bounds):tiles.append({"polygon":tile,"bounds":bounds})
	return {"transform":transform,"tiles":tiles,"screen":rectangle(viewport)}
static func visible_area(area:Dictionary,vision,project:Callable,viewport:Rect2,view:Dictionary={})->bool:
	if view.is_empty():view=view_context(vision,project,viewport)
	var polygon=PackedVector2Array()
	for point in Attacks.outline(area):polygon.append(view.transform*point)
	var bounds=polygon_bounds(polygon)
	if not viewport.intersects(bounds):return false
	var screen:PackedVector2Array=view.screen;var hole=PackedVector2Array()
	if area.shape=="ring":
		for i in range(40):hole.append(view.transform*(area.pos+Vector2.from_angle(TAU*i/40)*area.inner))
	var clipped=Geometry2D.intersect_polygons(polygon,screen)
	for part in clipped:
		if not vision.active:
			if hole.is_empty() or not Array(part).all(func(point):return Geometry2D.is_point_in_polygon(point,hole)):return true
			continue
		# Test the same tessellated shape that is drawn against visible tile
		# polygons. Centers alone miss thin lines and partially visible circles.
		var part_bounds=polygon_bounds(part)
		for tile in view.tiles:
			if not part_bounds.intersects(tile.bounds):continue
			for overlap in Geometry2D.intersect_polygons(part,tile.polygon):
				if hole.is_empty() or not Array(overlap).all(func(point):return Geometry2D.is_point_in_polygon(point,hole)):return true
	return false
static func apply_visibility(records:Array,vision,project:Callable,viewport:Rect2):
	if records.is_empty():return
	var view=view_context(vision,project,viewport)
	var remaining=FILL_LIMIT
	for i in range(records.size()-1,-1,-1):
		records[i].fill=remaining>0 and visible_area(records[i].area,vision,project,viewport,view)
		if records[i].fill:remaining-=1
static func tint(entry:Dictionary)->Color:
	if entry.priority==2:return Color("ff705d") if entry.time>.45 else Color("ffe1ba")
	return Color("edac71") if entry.priority==1 else Color("b98b72")
static func edge_point(origin:Vector2,target:Vector2,bounds:Rect2)->Vector2:
	var direction=(target-origin).normalized()
	if direction==Vector2.ZERO:return bounds.get_center()
	var t=INF
	if direction.x>0:t=minf(t,(bounds.end.x-origin.x)/direction.x)
	elif direction.x<0:t=minf(t,(bounds.position.x-origin.x)/direction.x)
	if direction.y>0:t=minf(t,(bounds.end.y-origin.y)/direction.y)
	elif direction.y<0:t=minf(t,(bounds.position.y-origin.y)/direction.y)
	return (origin+direction*maxf(0,t)).clamp(bounds.position,bounds.end)
static func place(point:Vector2,bounds:Rect2,occupied:Array)->Vector2:
	var vertical=is_equal_approx(point.x,bounds.position.x) or is_equal_approx(point.x,bounds.end.x)
	var axis=Vector2.DOWN if vertical else Vector2.RIGHT
	for step in range(21):
		var distance=ceilf(step/2.)*48.*(1. if step%2 else -1.)
		var candidate=(point+axis*distance).clamp(bounds.position,bounds.end)
		var rect=Rect2(candidate-Vector2(24,24),Vector2(48,70))
		if not occupied.any(func(region):return region.intersects(rect)):return candidate
	return Vector2.INF
static func warnings(records:Array,player:Dictionary,vision,project:Callable,viewport:Rect2,occupied:Array)->Array:
	if player.is_empty() or player.get("hp",0)<=0 or player.get("network_leaving",false):return []
	var origin:Vector2=project.call(player.pos)
	var bounds=viewport.grow(-64.)
	# The play camera keeps the player inside this rectangle. Do not pin a
	# misleading edge direction while entering a map or moving the camera.
	if not bounds.has_point(origin):return []
	var sectors={}
	var threats=[]
	for record in records:threats.append_array(record.get("threats",[record]))
	for entry in threats:
		if entry.priority!=2 or not vision.sees(entry.source):continue
		var source:Vector2=project.call(entry.source)
		if viewport.has_point(source):continue
		var direction=source-origin;var sector=posmod(roundi(direction.angle()/TAU*DIRECTION_SECTORS),DIRECTION_SECTORS)
		if not sectors.has(sector) or entry.time<sectors[sector].time:
			sectors[sector]={"time":entry.time,"direction":direction.normalized(),"source":source,"count":entry.count+int(sectors.get(sector,{}).get("count",0))}
		else:sectors[sector].count+=entry.count
	var result=sectors.values();result.sort_custom(func(a,b):return a.time<b.time)
	var placed=[];var regions=occupied.duplicate()
	for warning in result:
		if placed.size()>=WARNING_LIMIT:break
		var point=place(edge_point(origin,warning.source,bounds),bounds,regions)
		if point==Vector2.INF:continue
		warning["point"]=point;regions.append(Rect2(point-Vector2(25,25),Vector2(50,72)));placed.append(warning)
	return placed
static func configuration()->Dictionary:
	return {"fill_limit":FILL_LIMIT,"fill_scope":"rendered_polygon_intersecting_current_view_and_sight","warning_limit":WARNING_LIMIT,"direction_sectors":DIRECTION_SECTORS,"priority":["other","party","self"],"danger_test":"actual_shape_and_line_of_sight","visibility":"current_party_sight_source_only","merge":"identical_geometry_earliest_impact","input":"display_only"}
