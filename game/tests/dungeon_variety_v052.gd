extends SceneTree

const Dungeon=preload("res://scripts/dungeon.gd")
const Abyss=preload("res://scripts/abyss_catalog.gd")
const Sim=preload("res://scripts/simulation.gd")
const Forest=preload("res://scripts/forest_environment.gd")
const Tiles=preload("res://scripts/floor_tile_art_v04.gd")
var checks=0
var failures:Array=[]
var report={"maps":[],"layout_counts":{},"minimum_corridor_width":5,"roster_per_floor":23}

func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)

func reachable(cells:Dictionary,start:Vector2i)->Dictionary:
	var visited={};var queue:Array[Vector2i]=[start];var cursor=0
	if not cells.has(start):return visited
	visited[start]=true
	while cursor<queue.size():
		var cell=queue[cursor];cursor+=1
		for offset in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			var next=cell+offset
			if cells.has(next) and not visited.has(next):visited[next]=true;queue.append(next)
	return visited

func erosion(cells:Dictionary,radius:int)->Dictionary:
	var result={}
	for cell in cells:
		var clear=true
		for dx in range(-radius,radius+1):
			for dy in range(-radius,radius+1):
				if not cells.has(cell+Vector2i(dx,dy)):clear=false;break
			if not clear:break
		if clear:result[cell]=true
	return result

func ascii_map(map)->String:
	var lines:PackedStringArray=[]
	for y in range(Dungeon.SIZE):
		var line=""
		for x in range(Dungeon.SIZE):
			var cell=Vector2i(x,y)
			line+="S" if cell==Vector2i(map.spawn) else "B" if cell==Vector2i(map.exit_position) else "." if map.floor_cells.has(cell) else " "
		lines.append(line)
	return "\n".join(lines)

func inspect_map(map,label:String):
	check(map.rooms.size()==(3 if map.raid_arena else 9) and map.encounters.size()==(1 if map.raid_arena else 23),label+" exploration rooms or dedicated raid approach")
	check(map.floor_cells.size()>400 and map.floor_cells.size()<Dungeon.SIZE*Dungeon.SIZE*.86,label+" broad playable floor with real voids")
	var connected=reachable(map.floor_cells,Vector2i(map.spawn))
	check(connected.size()==map.floor_cells.size(),label+" every tile connected; no isolated pockets")
	var broad=erosion(map.floor_cells,2 if map.raid_arena else 3);var broad_connected=reachable(broad,Vector2i(map.spawn))
	for room in map.rooms:check(broad_connected.has(room),label+" every encounter and boss reachable along a five-cell-wide path")
	check(map.route_cells.keys().all(func(cell):return broad.has(cell)),label+" five-cell width preserved at all corners and bridges")
	for dx in range(-3,4):
		for dy in range(-3,4):check(map.walkable(map.spawn+Vector2(dx,dy)),label+" seven-cell entrance clearing")
	var positions=[];var roles={"normal":0,"elite":0,"guardian":0};var formations={}
	var room_counts={}
	for record in map.encounters:
		roles[record.role]+=1
		check(map.walkable(record.pos),label+" actual receiving feet on floor")
		check(record.pos.distance_to(map.spawn)>=8.,label+" no pack on entry")
		if record.role=="guardian":
			check(record.pos==map.exit_position and record.room==map.rooms.size()-1,label+" guardian protects reachable exit")
		else:
			formations[record.formation]=true
			check(record.pos.distance_to(map.exit_position)>=4.,label+" guard arena clear of overlapping packs")
			for previous in positions:check(previous.distance_to(record.pos)>=1.999,label+" separate monster silhouettes")
			positions.append(record.pos)
			if record.role=="normal":room_counts[record.room]=int(room_counts.get(record.room,0))+1
	check(roles==({"normal":0,"elite":0,"guardian":1} if map.raid_arena else {"normal":21,"elite":1,"guardian":1}),label+" raid has only its boss; ordinary floor preserves roster")
	if not map.raid_arena:
		check(room_counts.values().has(2) and room_counts.values().has(4),label+" different pack sizes instead of repeated three-monster rooms")
		check(formations.size()>=2,label+" varied ring/line/pincer/scattered placements")
	report.layout_counts[map.layout_id]=int(report.layout_counts.get(map.layout_id,0))+1

func run():
	var seen={};var orientations={};var signatures={};var sample_floor={}
	for run_seed in [177,20316478,918273]:
		var run_layouts={}
		for floor_number in range(1,101):
			var config=Abyss.config(floor_number)
			var seed_value=run_seed+floor_number*7919
			var map=Dungeon.new(seed_value,config.terrain,floor_number)
			var label="B%d seed%d"%[floor_number,seed_value]
			inspect_map(map,label)
			if not map.raid_arena:run_layouts[map.layout_id]=true
			seen[map.layout_id]=true;orientations[map.layout_rotation]=true
			signatures[hash(JSON.stringify(map.floor_cells))]=true
			if not sample_floor.has(map.layout_id):
				sample_floor[map.layout_id]=floor_number
				report.maps.append({"floor":floor_number,"seed":seed_value,"layout":map.layout_id,"orientation":map.layout_rotation,"cells":map.floor_cells.size(),"links":map.connections,"ascii":ascii_map(map)})
			if floor_number%10==1:
				var repeat=Dungeon.new(seed_value,config.terrain,floor_number)
				check(map.floor_cells==repeat.floor_cells and map.rooms==repeat.rooms and map.encounters==repeat.encounters,label+" deterministic replay")
		check(run_layouts.size()==Dungeon.LAYOUTS.size(),"one descending run includes every retained topology family")
	check(seen.size()==Dungeon.LAYOUTS.size()+Dungeon.RAID_LAYOUTS.size() and orientations.size()==8 and signatures.size()>=285,"exploration and raid topologies vary across runs")
	# These are actual simulation spawns, not only generator metadata. Neither
	# the roster size nor raid cadence, kind IDs or drop-table lookup is changed.
	for floor_number in range(1,101):
		var config=Abyss.config(floor_number);var sim=Sim.new(177+floor_number*7919,config.terrain,floor_number)
		check(sim.enemies.size()==(1 if floor_number%10==0 else 23),"simulation roster B%d"%floor_number)
		var guards=sim.enemies.values().filter(func(e):return e.get("guardian",false))
		check(guards.size()==1 and guards[0].boss==(floor_number%10==0),"exact guardian and ten-floor raid cadence B%d"%floor_number)
		for index in range(sim.map.encounters.size()):
			var record=sim.map.encounters[index];var enemy=sim.enemies[index+1]
			check(enemy.pos==record.pos and enemy.home==record.pos and enemy.get("encounter_room",-1)==record.room,"simulation consumes varied placements B%d enemy%d"%[floor_number,index])
			check(not sim.loot_tables.tables.get(enemy.kind,[]).is_empty(),"existing kind has existing rewards")
	var host=Node2D.new();root.add_child(host);var renderer=Forest.new(host)
	for floor_number in [1,11,21,31,41,51,61,71,81,91]:
		var map=Dungeon.new(177+floor_number*7919,Abyss.config(floor_number).terrain,floor_number)
		renderer.rebuild(map)
		check(renderer.ground_profile.id==Tiles.profile(map.zone,floor_number).id,"original biome retained")
		check(Tiles.catalog().materials.has(renderer.accent_material) and not renderer.material_regions.is_empty(),"secondary existing atlas material creates local clearings")
		check(renderer.material_regions.keys().all(func(cell):return map.floor_cells.has(cell)),"all material accents remain inside walkable floor")
		check(renderer.props.all(func(prop):return renderer.clear_for_prop(prop.pos)),"scenery never blocks entry, routes or exit")
		var regions=renderer.material_regions.duplicate();var mask=renderer.material.get_shader_parameter("accent_mask").get_image().get_data()
		renderer.rebuild(map)
		check(renderer.material_regions==regions and renderer.material.get_shader_parameter("accent_mask").get_image().get_data()==mask,"material regions are cached deterministic geometry, no flicker")
	var tutorial=Dungeon.new(177,"forest",0);var town=Dungeon.new(177,"town",0)
	check(tutorial.layout_id=="tutorial" and tutorial.encounters.is_empty() and tutorial.rooms.size()==9,"tutorial pacing preserved")
	check(town.facility_cells.size()>0 and town.rooms.size()==1,"town service navigation preserved")
	var town_walkable=town.floor_cells.duplicate()
	for cell in town.facility_cells:town_walkable.erase(cell)
	var town_reached=reachable(town_walkable,Vector2i(town.spawn))
	check(town_reached.size()==town_walkable.size(),"renewed plaza, shopping terrace and training green are connected")
	var facilities=preload("res://scripts/world_catalog.gd")
	for key in facilities.FACILITIES:
		check(town_reached.has(Vector2i(facilities.FACILITIES[key].pos)),"plaza reaches facility "+key)
		if facilities.RESIDENTS.has(key):check(town.walkable(facilities.resident_pos(key)),"resident feet clear of building "+key)
	check(town.in_town(facilities.FACILITIES.portal.pos),"dungeon doorway outside practice combat area")
	for x in range(29,44):
		for y in range(24,40):check(town.walkable(Vector2(x,y)),"entire training arena free of foliage/building collision")
	host.queue_free();await process_frame
	report["checks"]=checks;report["failures"]=failures;report["maps_checked"]=300
	FileAccess.open("res://../artifacts/dungeon-variety-v052.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("DUNGEON_VARIETY_V052 checks=",checks," failures=",failures.size()," maps=300 layouts=",seen.size())
	quit(0 if failures.is_empty() else 1)
