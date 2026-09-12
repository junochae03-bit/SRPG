extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Dungeon=preload("res://scripts/dungeon.gd")
const Rooms=preload("res://scripts/exploration_rooms.gd")
const Inventory=preload("res://scripts/inventory_model.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func clear(sim):
	for e in sim.enemies.values():e.hp=0
func use_site(sim,p,site,choice):
	p.pos=site.pos
	return sim.action(p.id,"explore",site.generation+":"+site.id+":"+choice)
func run():
	for floor_number in range(1,101):
		var map=Dungeon.new(571+floor_number*7919,"cave",floor_number)
		var repeat=Dungeon.new(571+floor_number*7919,"cave",floor_number)
		check(map.exploration_sites==repeat.exploration_sites,"deterministic room purpose B%d"%floor_number)
		check(map.raid_arena or map.connections.size()-map.rooms.size()+1>=3,"multiple independent loops B%d"%floor_number)
		check(map.raid_arena==(floor_number%10==0),"dedicated raid cadence B%d"%floor_number)
		check(map.layout_id!="crossed_halls","removed cross-hall never generated")
		if not map.raid_arena:
			var bounds=Rect2(Vector2(map.rooms[0]),Vector2.ZERO)
			for room in map.rooms:bounds=bounds.expand(Vector2(room))
			check(bounds.size.x>=48 and bounds.size.y>=48,"wide exploration footprint B%d"%floor_number)
			check(map.floor_cells.size()>=1800,"substantial traversable area B%d"%floor_number)
		check(map.room_radii.max()-map.room_radii.min()>=2,"different sized regions B%d"%floor_number)
		check(map.exploration_sites.size()==(1 if map.raid_arena else 3),"exploration purposes or raid preparation B%d"%floor_number)
		for site in map.exploration_sites:check(map.walkable(site.pos) and site.pos.distance_to(map.spawn)>5,"walkable site away from entry")
		if map.raid_arena:
			for dx in range(-6,7):
				for dy in range(-6,7):check(map.walkable(map.exit_position+Vector2(dx,dy)),"unobstructed raid fighting space")
			check(map.encounters.all(func(e):return e.role=="guardian" or e.pos.distance_to(map.exit_position)>=13),"no commons in boss arena")
	var sim=Sim.new(73,"cave",12);var p=sim.add_player(1,"탐사 검사");var guest=sim.add_player(2,"동료")
	var gather=sim.map.exploration_sites[0];var camp=sim.map.exploration_sites[1];var shrine=sim.map.exploration_sites[2]
	check(not use_site(sim,p,gather,"gather") and p.materials.get("ore",0)==0,"living guards block collection")
	clear(sim);p.pos=sim.map.spawn
	check(not sim.action(1,"explore",gather.generation+":"+gather.id+":gather"),"remote interaction rejected")
	check(use_site(sim,p,gather,"gather") and p.materials.ore==4,"exact collection reward")
	check(not use_site(sim,p,gather,"gather") and p.materials.ore==4,"repeated request cannot duplicate")
	check(sim.snapshot(1).exploration_sites[0].claimed and not sim.snapshot(2).exploration_sites[0].claimed,"personal claims snapshot")
	check(use_site(sim,guest,gather,"gather") and guest.materials.ore==4,"second human collects independently")
	p.hp=p.max_hp-12;p.stamina=0
	check(use_site(sim,p,camp,"rest") and p.hp==p.max_hp and p.stamina==p.max_stamina,"mid-floor camp restores")
	p.hp-=8
	check(not use_site(sim,p,camp,"rest") and p.hp==p.max_hp-8,"camp cannot be spammed")
	p.potions=0
	var before=sim.persistent(1).duplicate(true)
	check(not use_site(sim,p,shrine,"offering") and sim.persistent(1)==before,"no potion no cost or claim")
	p.potions=1;p.materials.essence=Inventory.MAX_MATERIALS
	before=sim.persistent(1).duplicate(true)
	check(not use_site(sim,p,shrine,"offering") and sim.persistent(1)==before,"full stack rolls back potion cost")
	p.materials.essence=0
	check(use_site(sim,p,shrine,"offering") and p.potions==0 and p.materials.essence==3,"offering cost and reward atomic")
	check(not use_site(sim,p,shrine,"recover"),"choice excludes alternative")
	guest.hp=1
	check(use_site(sim,guest,shrine,"recover") and guest.hp==1+roundi(guest.max_hp*.35),"guest can choose different reward")
	check(not sim.snapshot(2).players[1].has("materials"),"claims do not expose inventory")
	var next=Sim.new(74,"cave",13);next.add_player(1,p.name,sim.persistent(1))
	check(next.exploration_claims.is_empty() and next.players[1].materials.essence==3,"new floor resets sites and preserves loot")
	clear(next);var new_site=next.map.exploration_sites[2];var next_player=next.players[1];next_player.pos=new_site.pos;next_player.hp=1;next_player.potions=5
	before=next.persistent(1).duplicate(true)
	check(not next.action(1,"explore",shrine.generation+":"+new_site.id+":offering") and before==next.persistent(1) and next.exploration_claims.is_empty(),"stale generation rejected even with valid current room cost and range")
	var threat=sim.spawn_enemy(sim.enemies[1].kind,camp.pos,1)
	check(Rooms.threats(sim,camp)>0,"roaming enemy blocks safe use")
	threat.hp=0
	guest.pos=camp.pos;guest.network_leaving=true
	check(not sim.action(2,"explore",camp.generation+":"+camp.id+":rest"),"departing peer cannot mutate checkpoint")
	check(Dungeon.new(1,"town").exploration_sites.is_empty() and Dungeon.new(1,"forest").exploration_sites.is_empty(),"town and tutorial preserved")
	var raid=Sim.new(117,"forest",10);var fighter=raid.add_player(1,"전장 추적")
	var boss=raid.enemies.values()[0];fighter.pos=boss.home+Vector2(9,0)
	var old_distance=boss.pos.distance_to(fighter.pos);raid.tick(.1)
	check(raid.map.walkable(fighter.pos) and boss.pos.distance_to(fighter.pos)<old_distance,"boss pursues beyond old eight-cell leash inside new arena")
	print("EXPLORATION_ROOMS checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
