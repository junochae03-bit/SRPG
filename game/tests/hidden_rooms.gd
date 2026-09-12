extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Hidden=preload("res://scripts/hidden_rooms.gd")
const Dungeon=preload("res://scripts/dungeon.gd")
const Inv=preload("res://scripts/inventory_model.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run():
	var generated=0
	for seed_value in range(1,61):
		var map=Dungeon.new(seed_value*7919,"cave",1+seed_value%9)
		check(map.hidden_regions==Dungeon.new(seed_value*7919,"cave",map.floor_number).hidden_regions,"deterministic pockets")
		check(map.hidden_regions.size() in [1,2],"one or two pockets fit without changing primary routes seed %d"%seed_value)
		var original=map.floor_cells.duplicate()
		for site in map.hidden_regions:
			check(map.walkable(site.pos) and not map.walkable(site.center),"clue reachable and pocket initially hidden")
			check(Hidden.open(map,site.id),"open optional region")
			check(map.walkable(site.center) and map.floor_cells.size()>original.size(),"actual walkable room grows")
			check(original.keys().all(func(cell):return map.floor_cells.has(cell)),"primary exploration never removed")
		generated+=map.hidden_regions.size()
	check(Dungeon.new(1,"cave",10).hidden_regions.is_empty(),"raid untouched")
	var sim=Sim.new(123,"cave",12);var p=sim.add_player(1,"탐색자");var other=sim.add_player(2,"동료")
	for enemy in sim.enemies.values():enemy.hp=0
	check(Hidden.snapshots(sim,1).is_empty(),"undiscovered clues absent from snapshot")
	var site=sim.map.hidden_regions[0];p.pos=site.pos;Hidden.discover(sim)
	check(Hidden.snapshots(sim,2).size()>=1,"nearby discovery shared with party")
	var key=site.generation+":"+site.id
	check(sim.action(1,"explore",key+":open"),"free clue opens without any tool")
	var mirror=Dungeon.new(123,"cave",12);var packet=sim.snapshot(2)
	Hidden.synchronize(mirror,packet.opened_regions,packet.revealed_regions)
	check(mirror.floor_cells==sim.map.floor_cells and mirror.revision==sim.map.revision,"guest mirror geometry matches host")
	Hidden.synchronize(mirror,packet.opened_regions,packet.revealed_regions);check(mirror.revision==1,"repeated snapshot does not rebuild geometry")
	p.pos=site.center;p.materials.essence=Inv.MAX_MATERIALS
	var before=sim.persistent(1).duplicate(true)
	check(not sim.action(1,"explore",key+":collect") and sim.persistent(1)==before,"full reward stack costs nothing and retains claim")
	p.materials.essence=0
	check(sim.action(1,"explore",key+":collect") and p.materials.essence==4,"personal reward")
	before=sim.persistent(1).duplicate(true)
	check(not sim.action(1,"explore",key+":collect") and before==sim.persistent(1),"no duplicate reward")
	other.pos=site.center;check(sim.action(2,"explore",key+":collect") and other.materials.essence==4,"other member retains own reward")
	var gate=sim.map.hidden_regions[1];p.pos=gate.pos;Hidden.discover(sim);var gate_key=gate.generation+":"+gate.id
	check(not sim.action(1,"explore",gate_key+":open") and not sim.map.opened_regions.has(gate.id),"missing tool preserves closed optional gate")
	p.materials.tool=2
	check(sim.action(1,"explore",gate_key+":open") and p.materials.tool==1,"one tool opens shared gate")
	check(not sim.action(1,"explore",gate_key+":open") and p.materials.tool==1,"duplicate opening cannot consume tool")
	p.pos=gate.center;before=sim.persistent(1).duplicate(true)
	check(not sim.action(1,"explore","999.cave.12:"+gate.id+":collect") and before==sim.persistent(1),"stale generation rejected")
	var shop=Sim.new(77,"town");var buyer=shop.add_player(1,"도구 구매");buyer.gold=200;buyer.pos=preload("res://scripts/world_catalog.gd").FACILITIES.shop.pos
	check(shop.action(1,"facility",JSON.stringify({"facility":"shop","operation":"tool","quantity":5})) and buyer.gold==75 and buyer.materials.tool==5,"actual shop transaction provides tools")
	var saved=shop.persistent(1);saved.world_seed=77
	var session=preload("res://scripts/local_session.gd").new();root.add_child(session)
	check(session.validate_save(JSON.parse_string(JSON.stringify(saved)))!=null,"tool inventory preserves save compatibility")
	session.queue_free()
	print("HIDDEN_ROOMS checks=%d failures=%d regions=%d"%[checks,failures.size(),generated]);quit(0 if failures.is_empty() else 1)
