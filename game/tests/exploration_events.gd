extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Dungeon=preload("res://scripts/dungeon.gd")
const Events=preload("res://scripts/exploration_events.gd")
const Inventory=preload("res://scripts/inventory_model.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func fixture(event:String)->Dictionary:
	var sim=Sim.new(7996,"forest",1);var p=sim.add_player(1,"탐사자");var friend=sim.add_player(2,"동료")
	for enemy in sim.enemies.values():enemy.hp=0
	var site=sim.map.exploration_sites.filter(func(s):return s.kind==Events.DEFINITIONS[event].kind)[0]
	site["event"]=event;p.pos=site.pos;friend.pos=site.pos
	return {"sim":sim,"p":p,"friend":friend,"site":site,"key":site.generation+":"+site.id+":"}
func run():
	var observed={}
	for depth in range(1,101):
		var map=Dungeon.new(991+depth*7919,"cave",depth)
		var again=Dungeon.new(991+depth*7919,"cave",depth)
		check(map.exploration_sites==again.exploration_sites,"same seed gives same event locations")
		check(map.exploration_sites.size()==(1 if depth%10==0 else 5),"events replace sites without adding rooms")
		for site in map.exploration_sites:
			var event=site.get("event","")
			if event.is_empty():continue
			observed[event]=true
			check(depth%10!=0 and Events.DEFINITIONS[event].kind==site.kind,"event fits existing optional room")
	check(observed.size()==4,"all four discoveries appear in generated floors")
	for event in Events.DEFINITIONS:
		var f=fixture(event);var sim=f.sim;var p=f.p;var friend=f.friend;var site=f.site
		p.hp=int(p.max_hp*.7);p.stamina=70
		Inventory.add_stack(p,"seed",2);Inventory.add_stack(p,"tool",1)
		var options=Events.choices(site);var preview=Events.quote(p,site,options[0]);var before=sim.persistent(1).duplicate(true)
		check(preview.reason.is_empty() and sim.persistent(1)==before,"preview never mutates owned state")
		check(sim.action(1,"explore",f.key+options[0]),"first event choice succeeds")
		for field in ["hp","stamina","potions","materials","bag_positions"]:check(p[field]==preview.staged[field],"actual state equals preview: "+field)
		check(p.hp>0 and p.stamina>=0,"event cost cannot kill or overdraw")
		var after=sim.persistent(1).duplicate(true)
		check(not sim.action(1,"explore",f.key+options[0]) and not sim.action(1,"explore",f.key+options[1]) and sim.persistent(1)==after,"duplicate and alternative cannot claim twice")
		friend.hp=1;friend.stamina=0
		check(sim.action(2,"explore",f.key+options[1]),"another player chooses independently")
		check(sim.persistent(1)==after,"guest choice never changes first player's resources")
		var snapshots=sim.snapshot(2)
		check(not snapshots.players[1].has("materials"),"no other player's private inventory exposed")
		var seen=snapshots.exploration_sites.filter(func(s):return s.id==site.id)[0]
		check(seen.event==event and seen.claimed and not seen.has("staged"),"shared identity personal claim without candidate inventory")
		var next=Sim.new(112,"cave",2);next.add_player(1,p.name,sim.persistent(1))
		check(next.exploration_claims.is_empty() and next.players[1].materials==p.materials,"floor transition preserves loot not event claims")
		var missing=fixture(event);missing.p.hp=1;missing.p.stamina=0
		before=missing.sim.persistent(1).duplicate(true)
		check(not missing.sim.action(1,"explore",missing.key+options[0]) and missing.sim.persistent(1)==before and missing.sim.exploration_claims.is_empty(),"missing cost rejects without mutation or claim")
		var full=fixture(event);full.p.hp=int(full.p.max_hp*.7);full.p.stamina=70
		Inventory.add_stack(full.p,"seed",2);Inventory.add_stack(full.p,"tool",1)
		if event=="herbalist":full.p.potions=Inventory.MAX_POTIONS
		else:full.p.materials.essence=Inventory.MAX_MATERIALS
		before=full.sim.persistent(1).duplicate(true)
		check(not full.sim.action(1,"explore",full.key+options[0]) and full.sim.persistent(1)==before and full.sim.exploration_claims.is_empty(),"full reward stack rolls back all costs")
		var invalid=fixture(event);invalid.p.pos=invalid.sim.map.spawn
		check(not invalid.sim.action(1,"explore",invalid.key+options[1]),"remote event request rejected")
		invalid.p.pos=invalid.site.pos
		check(not invalid.sim.action(1,"explore","old.generation:"+site.id+":"+options[1]),"stale generation rejected")
		check(not invalid.sim.action(1,"explore",invalid.key+"invented"),"unlisted choice rejected")
		invalid.p.network_leaving=true
		check(not invalid.sim.action(1,"explore",invalid.key+options[1]),"departing player cannot claim")
	var herb=fixture("herbalist");herb.p.materials.seed=2;herb.p.potions=0;Inventory.initialize(herb.p)
	check(herb.sim.action(1,"explore",herb.key+"brew") and not herb.p.bag_positions.has("@mat:seed") and herb.p.potions==3,"consuming last ingredient clears its bag position")
	for ingredients in [2,3]:
		var packed=fixture("herbalist");var p=packed.p
		p.inventory=[];p.potions=0;p.materials={"seed":ingredients};p.equipment={};p.equipped="";p.bag_positions={};Inventory.initialize(p)
		for index in range(Inventory.CAPACITY-1):
			check(Inventory.add_gear(p,preload("res://scripts/equipment_catalog.gd").make("head",0,0,"event-bag-%d"%index,"none","warrior")),"fill event bag boundary")
		check(Inventory.bag_items(p).size()==Inventory.CAPACITY,"event bag is full before exchange")
		var before=packed.sim.persistent(1).duplicate(true)
		if ingredients==2:
			check(packed.sim.action(1,"explore",packed.key+"brew") and Inventory.bag_items(p).size()==Inventory.CAPACITY and not p.bag_positions.has("@mat:seed") and p.potions==3,"consumed ingredient frees exactly one slot for output")
		else:
			check(not packed.sim.action(1,"explore",packed.key+"brew") and packed.sim.persistent(1)==before and packed.sim.exploration_claims.is_empty(),"retained ingredient leaves no output space and no partial cost")
	for event in ["blood_altar","echo_shrine"]:
		var f=fixture(event);var alternative=Events.choices(f.site)[1]
		check(not f.sim.action(1,"explore",f.key+alternative) and f.sim.exploration_claims.is_empty(),"full recovery remains available for later need")
	var lethal=fixture("blood_altar");lethal.p.hp=ceili(lethal.p.max_hp*.2)
	check(not lethal.sim.action(1,"explore",lethal.key+"sacrifice") and lethal.p.hp>0,"exact life cost rejected instead of killing")
	print("EXPLORATION_EVENTS checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
