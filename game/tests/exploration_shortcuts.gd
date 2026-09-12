extends SceneTree
const Dungeon=preload("res://scripts/dungeon.gd")
const Shortcuts=preload("res://scripts/exploration_shortcuts.gd")
const Hidden=preload("res://scripts/hidden_rooms.gd")
const Sim=preload("res://scripts/simulation.gd")
const Vision=preload("res://scripts/dungeon_vision.gd")
var checks=0
var failures=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func run():
	var samples=0;var largest=0;var timings=[];var fixture={};var saved_min=INF
	for depth in range(1,101):
		if depth%10==0:continue
		for seed_value in [77,884,2026]:
			var started=Time.get_ticks_usec();var seed=seed_value+depth*7919
			var map=Dungeon.new(seed,"cave",depth);timings.append(Time.get_ticks_usec()-started)
			var shortcuts=map.hidden_regions.filter(func(site):return site.get("shortcut",false))
			check(shortcuts.size()<=1 and map.hidden_regions.size()<=2,"at most one shortcut replaces a pocket")
			check(map.hidden_regions==Dungeon.new(seed,"cave",depth).hidden_regions,"same seed reproduces both mouths and hidden geometry")
			if shortcuts.is_empty():continue
			samples+=1;var site=shortcuts[0];var baseline=map.floor_cells.duplicate();var graph=Shortcuts.navigation(map)
			var before=Shortcuts.distance(graph,Vector2i(site.pos),Vector2i(site.forward_exit))
			var to_goal=Shortcuts.distance(graph,Vector2i(site.pos),Vector2i(map.exit_position))
			check(not map.walkable(site.center) and not map.line_clear(site.pos,site.center),"sealed passage is not already traversable")
			check(Shortcuts.distance(graph,Vector2i(site.forward_exit),Vector2i(map.exit_position))<=to_goal-6.,"far mouth genuinely progresses toward guardian")
			check(Hidden.open(map,site.id),"open shared shortcut")
			var added=map.floor_cells.size()-baseline.size();largest=maxi(largest,added)
			check(added==site.new_cells and added<=Shortcuts.MAX_NEW_CELLS,"opened footprint has bounded verified size")
			check(baseline.keys().all(func(cell):return map.floor_cells.has(cell)),"normal map and all previous routes preserved")
			var after_graph=Shortcuts.navigation(map)
			var after=Shortcuts.distance(after_graph,Vector2i(site.pos),Vector2i(site.forward_exit));saved_min=minf(saved_min,before-after)
			check(before-after>=Shortcuts.MIN_SAVING and after<=before*Shortcuts.MAX_ROUTE_RATIO,"real eight-direction travel is shorter after discovery")
			check(Shortcuts.distance(after_graph,Vector2i(site.pos),Vector2i(map.exit_position))<to_goal,"passage also shortens the route to the guardian")
			for cell in Shortcuts.cells(site):
				check(map.walkable(cell) and Vector2(cell).distance_to(map.spawn)>=8. and Vector2(cell).distance_to(map.exit_position)>=10.,"passage avoids arrival and guardian interior")
			var revision=map.revision;var opened_cells=map.floor_cells.duplicate()
			check(not Hidden.open(map,site.id) and map.revision==revision and map.floor_cells==opened_cells,"duplicate opening does not rebuild terrain")
			var mirror=Dungeon.new(seed,"cave",depth);Hidden.synchronize(mirror,map.opened_regions.keys(),map.revealed_regions.keys())
			check(mirror.floor_cells==map.floor_cells and mirror.revision==map.revision,"guest's generated opening exactly matches host")
			Hidden.open(map,map.hidden_regions[0].id);var reversed=Dungeon.new(seed,"cave",depth)
			Hidden.open(reversed,reversed.hidden_regions[0].id);Hidden.open(reversed,site.id)
			check(reversed.floor_cells==map.floor_cells,"pocket and passage opening order has identical geometry")
			if fixture.is_empty():fixture={"seed":seed,"floor":depth}
	check(samples>=5,"multiple biomes contain useful shortcut discoveries")
	check(Dungeon.new(77,"cave",10).hidden_regions.is_empty(),"raid arena gains no shortcut")
	var sim=Sim.new(fixture.seed,"cave",fixture.floor);var p=sim.add_player(1,"길잡이");var friend=sim.add_player(2,"동료")
	var site=sim.map.hidden_regions.filter(func(value):return value.get("shortcut",false))[0];var key=site.generation+":"+site.id
	for enemy in sim.enemies.values():enemy.hp=0
	var vision=Vision.new();p.pos=sim.map.spawn;friend.pos=p.pos;vision.update(sim.map,sim.players,0.)
	check(Hidden.snapshots(sim,1).is_empty() and not vision.discovered(site.center),"undiscovered shortcut is absent from UI and fog memory")
	p.pos=site.pos;friend.pos=sim.map.spawn;Hidden.discover(sim);vision.update(sim.map,sim.players,1.)
	var sealed=Hidden.snapshots(sim,1).filter(func(value):return value.id==site.id)[0]
	check(sealed.shortcut and not sealed.has("forward_exit") and not sealed.has("previous_distance"),"discovered clue does not disclose far mouth or generator metrics")
	check(not sim.action(1,"explore",key+":open") and not sim.map.opened_regions.has(site.id),"missing tool cannot open terrain")
	p.materials.tool=2
	var old_vision=vision.revision
	check(sim.action(1,"explore",key+":open") and p.materials.tool==1,"one owned tool opens passage")
	check(not sim.action(1,"explore",key+":open") and p.materials.tool==1,"repeated request cannot spend another tool")
	vision.update(sim.map,sim.players,2.)
	check(vision.revision>old_vision and not vision.discovered(sim.map.exit_position),"opening invalidates local visibility without revealing the destination")
	var route=Shortcuts.navigation(sim.map).get_point_path(Vector2i(site.pos),Vector2i(site.forward_exit))
	var walked=site.pos
	for point in route:
		for step in range(16):walked=sim.map.move(walked,(point-walked).limit_length(.12))
	check(walked.distance_to(site.forward_exit)<.2,"actual movement reaches far mouth through opened passage")
	p.pos=site.center;friend.pos=site.center
	check(sim.action(1,"explore",key+":collect") and sim.action(2,"explore",key+":collect"),"both players claim their own reward")
	var after_claim=sim.map.floor_cells.duplicate()
	check(not sim.action(1,"explore",key+":collect") and after_claim==sim.map.floor_cells,"completed reward leaves shared passage permanently usable for this floor")
	timings.sort();print("SHORTCUT_METRICS maps=%d passages=%d max_added_cells=%d min_saved=%.2f median_generation_us=%d p95_generation_us=%d fixture=%s"%[timings.size(),samples,largest,saved_min,timings[int(timings.size()/2)],timings[int(timings.size()*.95)],JSON.stringify(fixture)])
	print("EXPLORATION_SHORTCUTS checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
