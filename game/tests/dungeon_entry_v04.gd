extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Abyss=preload("res://scripts/abyss_catalog.gd")
const Dungeon=preload("res://scripts/dungeon.gd")
const Forest=preload("res://scripts/forest_environment.gd")
var checks=0
var failures=[]
var steps_walked=0
func _initialize():run.call_deferred()
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures.append(message);push_error(message)
func route(map,goal:Vector2)->Array:
	var first=Vector2i(map.spawn);var destination=Vector2i(goal);var previous={first:first};var pending=[first];var cursor=0
	while cursor<pending.size() and not previous.has(destination):
		var cell=pending[cursor];cursor+=1
		for delta in [Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]:
			var next=cell+delta
			if map.walkable(Vector2(next)) and not previous.has(next):previous[next]=cell;pending.append(next)
	if not previous.has(destination):return []
	var result=[destination]
	while result.back()!=first:result.append(previous[result.back()])
	result.reverse();return result
func walk(sim,p:Dictionary,points:Array)->bool:
	for point in points:
		var target=Vector2(point);var attempts=0
		while p.pos.distance_to(target)>.04 and attempts<40:
			var displacement=target-p.pos
			# Real input -> simulation -> player movement, with a short last step.
			sim.set_input(p.id,displacement.normalized(),Vector2.RIGHT)
			sim.tick(minf(.03,displacement.length()/sim.balance.player.speed))
			attempts+=1;steps_walked+=1
		if p.pos.distance_to(target)>.04:return false
	return true
func run():
	var host=Node2D.new();root.add_child(host);var forest=Forest.new(host)
	for floor_number in range(1,101):
		var config=Abyss.config(floor_number)
		for seed_value in [20260908+137+7919*2+floor_number*7919,112+floor_number,177]:
			var sim=Sim.new(seed_value,config.terrain,floor_number);sim.enemies.clear();var p=sim.add_player(1,"입구 검사")
			var label="B%d seed%d"%[floor_number,seed_value]
			check(p.pos==sim.map.spawn and sim.map.walkable(p.pos),"valid exact entry "+label)
			for screen_direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
				p.pos=sim.map.spawn;sim.set_input(1,Dungeon.from_iso(screen_direction).normalized(),Vector2.RIGHT);sim.tick(.1)
				check(p.pos.distance_to(sim.map.spawn)>.2,"entry has room for keyboard movement "+label+str(screen_direction))
			var first_room=route(sim.map,Vector2(sim.map.rooms[1]));var exit_route=route(sim.map,sim.map.exit_position)
			check(not first_room.is_empty() and not exit_route.is_empty(),"entry connected to next room and exit "+label)
			if seed_value==177:
				var original_floor=sim.map.floor_cells.duplicate();forest.rebuild(sim.map)
				check(forest.props.all(func(prop):return prop.pos.distance_to(sim.map.spawn)>=6. and prop.pos.distance_to(sim.map.exit_position)>=4. and not sim.map.walkable(prop.pos)),"rendered props leave entrance and exit clear "+label)
				var corridor_clear=true
				for prop in forest.props:
					for cell in first_room:
						if prop.pos.distance_to(Vector2(cell))<2.5:corridor_clear=false
				check(corridor_clear,"rendered foliage stays away from first passage "+label)
				var mask=forest.material.get_shader_parameter("walk_mask").get_image();var visible_path=true
				for cell in exit_route:
					if mask.get_pixel(cell.x+Forest.MASK_OFFSET,cell.y+Forest.MASK_OFFSET).r<.99:visible_path=false
				check(visible_path and original_floor==sim.map.floor_cells,"ground mask follows actual walkable path without changing collision "+label)
			p.pos=sim.map.spawn
			check(walk(sim,p,exit_route) and p.pos.distance_to(sim.map.exit_position)<.05,"actual player walks spawn to exit "+label)
	print("DUNGEON_ENTRY_V04 ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures.size()," movement_steps=",steps_walked)
	host.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
