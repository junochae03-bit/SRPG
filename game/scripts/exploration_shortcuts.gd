extends RefCounted
## A hidden passage replaces one reward pocket; the normal floor never grows.
const MIN_SAVING=10.0
const MAX_ROUTE_RATIO=.75
const MAX_NEW_CELLS=150
const SEED_OFFSET=23917
const ROOM_RADIUS=2
static func navigation(map)->AStarGrid2D:
	var graph=AStarGrid2D.new();graph.region=Rect2i(0,0,map.SIZE,map.SIZE)
	graph.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	graph.default_compute_heuristic=AStarGrid2D.HEURISTIC_OCTILE
	graph.default_estimate_heuristic=AStarGrid2D.HEURISTIC_OCTILE
	graph.update();graph.fill_solid_region(graph.region,true)
	for cell in map.floor_cells:graph.set_point_solid(cell,false)
	return graph
static func distance(graph:AStarGrid2D,a:Vector2i,b:Vector2i)->float:
	var path=graph.get_point_path(a,b)
	if path.is_empty():return INF
	var total=0.
	for i in range(1,path.size()):total+=path[i-1].distance_to(path[i])
	return total
static func progress(map)->Dictionary:
	var origin=Vector2i(map.spawn);var result={origin:0};var queue=[origin];var index=0
	while index<queue.size():
		var cell=queue[index];index+=1
		for offset in [Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]:
			var next=cell+offset
			if map.floor_cells.has(next) and not result.has(next):result[next]=result[cell]+1;queue.append(next)
	return result
static func mouths(map,center:Vector2i)->Array:
	var sectors={}
	for dx in range(-12,13):
		for dy in range(-12,13):
			var squared=dx*dx+dy*dy
			if squared<=9 or squared>144:continue
			var cell=center+Vector2i(dx,dy)
			if not map.floor_cells.has(cell) or Vector2(cell).distance_to(map.exit_position)<10.:continue
			var sector=posmod(roundi(atan2(dy,dx)/(PI/4.)),8)
			if not sectors.has(sector) or squared<sectors[sector].distance:sectors[sector]={"cell":cell,"distance":squared}
	return sectors.values().map(func(value):return value.cell)
static func segment(result:Dictionary,a:Vector2i,b:Vector2i):
	var cursor=a
	while true:
		for dx in range(-1,2):
			for dy in range(-1,2):result[cursor+Vector2i(dx,dy)]=true
		if cursor==b:break
		var remaining=b-cursor
		if absi(remaining.x)>=absi(remaining.y) and remaining.x!=0:cursor.x+=signi(remaining.x)
		else:cursor.y+=signi(remaining.y)
static func cells(region:Dictionary)->Dictionary:
	var result={};var center=Vector2i(region.center)
	for dx in range(-ROOM_RADIUS,ROOM_RADIUS+1):
		for dy in range(-ROOM_RADIUS,ROOM_RADIUS+1):
			if dx*dx+dy*dy<=ROOM_RADIUS*ROOM_RADIUS+2:result[center+Vector2i(dx,dy)]=true
	segment(result,Vector2i(region.pos),center);segment(result,center,Vector2i(region.forward_exit))
	return result
static func select(map,retained:Dictionary)->Dictionary:
	if map.raid_arena or map.floor_number<=0:return {}
	var candidates=[];var rng=RandomNumberGenerator.new();rng.seed=map.seed_value+SEED_OFFSET
	for y in range(8,map.SIZE-7,3):
		for x in range(8,map.SIZE-7,3):candidates.append(Vector2i(x,y))
	for index in range(candidates.size()-1,0,-1):
		var other=rng.randi_range(0,index);var before=candidates[index];candidates[index]=candidates[other];candidates[other]=before
	var steps=progress(map);var graph=navigation(map)
	for center in candidates:
		if Vector2(center).distance_to(retained.center)<13.:continue
		var clear=true
		for dx in range(-ROOM_RADIUS-1,ROOM_RADIUS+2):
			for dy in range(-ROOM_RADIUS-1,ROOM_RADIUS+2):
				if map.floor_cells.has(center+Vector2i(dx,dy)):clear=false;break
			if not clear:break
		if not clear:continue
		var entries=mouths(map,center)
		entries.sort_custom(func(a,b):return steps.get(a,99999)<steps.get(b,99999) if steps.get(a,99999)!=steps.get(b,99999) else a<b)
		if entries.size()<2:continue
		var entry:Vector2i=entries[0]
		if steps.get(entry,0)<12 or Vector2(entry).distance_to(map.spawn)<10.:continue
		var entry_to_goal=distance(graph,entry,Vector2i(map.exit_position))
		for exit_cell in entries.slice(1):
			if steps.get(exit_cell,0)-steps[entry]<8:continue
			if distance(graph,exit_cell,Vector2i(map.exit_position))>entry_to_goal-6.:continue
			var old_length=distance(graph,entry,exit_cell)
			if not is_finite(old_length) or old_length<Vector2(entry).distance_to(Vector2(exit_cell))+MIN_SAVING:continue
			var region={"center":Vector2(center),"pos":Vector2(entry),"forward_exit":Vector2(exit_cell),"shortcut":true,"previous_distance":old_length}
			var added=[];var valid=true
			for cell in cells(region):
				if cell.x<1 or cell.y<1 or cell.x>=map.SIZE-1 or cell.y>=map.SIZE-1 or Vector2(cell).distance_to(retained.center)<6. or Vector2(cell).distance_to(map.exit_position)<10. or Vector2(cell).distance_to(map.spawn)<8.:valid=false;break
				if not map.floor_cells.has(cell):added.append(cell)
			if not valid or added.size()>MAX_NEW_CELLS:continue
			for cell in added:graph.set_point_solid(cell,false)
			var new_length=distance(graph,entry,exit_cell);var new_to_goal=distance(graph,entry,Vector2i(map.exit_position))
			for cell in added:graph.set_point_solid(cell,true)
			if old_length-new_length<MIN_SAVING or new_length>old_length*MAX_ROUTE_RATIO or entry_to_goal-new_to_goal<6.:continue
			region["new_cells"]=added.size();region["passage_distance"]=new_length;region["goal_saved"]=entry_to_goal-new_to_goal
			return region
	return {}
static func configuration()->Dictionary:
	return {"maximum_per_floor":1,"replaces":"second_tool_pocket_when_a_useful_passage_fits","room_radius":ROOM_RADIUS,"passage_half_width":1,"minimum_saved_tiles":MIN_SAVING,"minimum_goal_saved_tiles":6.,"maximum_route_ratio":MAX_ROUTE_RATIO,"maximum_new_cells":MAX_NEW_CELLS,"seed_offset":SEED_OFFSET,"distance":"eight_neighbor_shortest_path_without_corner_cutting","discovery":"local_wall_clue_then_shared_opening","reward_scope":"existing_personal_secret_reward","normal_geometry":"unchanged_until_discovered_and_opened","raid_enabled":false}

static func draw(game):
	var player=game.session.state.players.get(game.session.local_id,{})
	if player.is_empty():return
	for region in game.dungeon.hidden_regions:
		if not region.get("shortcut",false) or not game.dungeon.opened_regions.has(region.id):continue
		for mouth in [region.pos,region.forward_exit]:
			if not game.vision.sees(mouth):continue
			var art=preload("res://scripts/environment_art.gd").frame("ruins_rubble")
			var at=game.world_point(mouth);var scale_value=26./art.height
			game.draw_texture_rect(art.texture,Rect2(at-art.foot*scale_value,art.texture.get_size()*scale_value),false,Color(.8,.85,.82,.8))
			if player.pos.distance_to(mouth)<3.2 and game.dungeon.line_clear(player.pos,mouth):game.text_at(at+Vector2(0,32),"열린 지름길",15,Color("efdfb1"),true)
