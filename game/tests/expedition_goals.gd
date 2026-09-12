extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Goals=preload("res://scripts/expedition_goals.gd")
const Hidden=preload("res://scripts/hidden_rooms.gd")
const Equipment=preload("res://scripts/equipment_catalog.gd")
const Inventory=preload("res://scripts/inventory_model.gd")
const Session=preload("res://scripts/local_session.gd")
var checks=0
var failures=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func choose(sim,p,kind,depth):return sim.action(p.id,"select_goal",JSON.stringify({"id":kind,"floor":depth}))
func _initialize():run.call_deferred()
func run():
	var town=Sim.new(84,"town");var p=town.add_player(1,"목표 검사");p.tutorial_done=true
	var offers=Goals.offers(p,1)
	check(offers.size()==4 and offers.all(func(row):return Goals.valid(row.goal)),"four concrete offers have valid persistent payloads")
	check(choose(town,p,"secret",1),"choose rumor in town")
	check(not choose(town,p,"secret",1),"duplicate selection cannot reset discovery")
	check(choose(town,p,"clear",1) and p.expedition_goal.is_empty(),"personal goal can be removed without changing progress")
	check(choose(town,p,"secret",1),"choose rumor after clearing")
	check(not choose(town,p,"secret",2) and not town.action(1,"select_goal",'{"id":"secret","floor":1.5}'),"locked or fractional destination rejected")
	check(not town.action(1,"select_goal",'{"id":"secret","floor":1,"stage":3}'),"client cannot submit progress or additional data")
	var guest=town.add_player(2,"다른 목표");guest.tutorial_done=true
	check(choose(town,guest,"advance",1) and p.expedition_goal.kind=="secret","humans choose independent objectives")
	check(not town.snapshot(1).players[2].has("expedition_goal"),"private goal not sent to another player")
	var dungeon=Sim.new(7919,"forest",1);var explorer=dungeon.add_player(1,p.name,town.persistent(1));var other=dungeon.add_player(2,guest.name,town.persistent(2))
	check(not choose(dungeon,explorer,"challenge",1),"cannot rewrite expedition goal in the dungeon")
	var region=dungeon.map.hidden_regions[0]
	for enemy in dungeon.enemies.values():enemy.hp=0
	other.pos=region.pos;Hidden.discover(dungeon);Goals.observe(dungeon)
	check(explorer.expedition_goal.stage==1 and other.expedition_goal.kind=="advance","shared discovery advances only relevant personal rumor")
	explorer.pos=region.pos
	check(dungeon.action(1,"explore",region.generation+":"+region.id+":open") and explorer.expedition_goal.stage==2,"opening real clue advances personal objective")
	explorer.pos=region.center
	check(dungeon.action(1,"explore",region.generation+":"+region.id+":collect") and explorer.expedition_goal.stage==3,"actual personal reward completes rumor")
	check(Goals.describe(explorer).ready,"completed rumor status")
	for kind in ["secret","challenge"]:
		for stage in [1,2]:
			var saved=dungeon.persistent(1).duplicate(true);saved.expedition_goal=Goals.goal(kind,1);saved.expedition_goal.stage=stage
			var return_sim=Sim.new(991,"town");var returning=return_sim.add_player(1,p.name,saved)
			check(returning.expedition_goal.stage==0,"return discards incomplete map-specific progress")
			var revisit=Sim.new(999,"forest",1);var repeat=revisit.add_player(1,p.name,saved)
			check(repeat.expedition_goal.stage==0,"same-floor fresh expedition starts rumor discovery again")
	var loaded=Sim.new(998,"town");var resumed=loaded.add_player(1,p.name,dungeon.persistent(1))
	check(resumed.expedition_goal==explorer.expedition_goal,"return/reload keeps discovered objective")
	var data=loaded.persistent(1);data.world_seed=998
	var session=Session.new();root.add_child(session)
	var path=ProjectSettings.globalize_path("res://../runtime/goals-test-"+str(Time.get_ticks_usec())+".json")
	check(session.write_save(data,path) and session.parse_save(path)!=null,"new goal survives actual save validator")
	var legacy=data.duplicate(true);legacy.erase("expedition_goal")
	check(session.write_save(legacy,path) and session.parse_save(path)!=null,"older v7 save without optional objective remains valid")
	for bad in [null,[],"goal",{"kind":"secret"}]:
		var corrupted=data.duplicate(true);corrupted.expedition_goal=bad
		check(session.write_save(corrupted,path) and session.parse_save(path)==null,"malformed objective rejected")
	for field in ["floor","target","stage"]:
		var corrupted=data.duplicate(true);corrupted.expedition_goal[field]=1.5
		check(not Goals.valid(corrupted.expedition_goal),"fractional objective field rejected")
	session.queue_free()
	material_goals()
	for depth in range(1,101):
		p.highest_floor=depth;p.cleared_floor=depth-1
		for offer in Goals.offers(p,depth):
			check(Goals.valid(offer.goal) and offer.goal.floor<=depth,"offers stay inside unlocked floors")
			check(not offer.has("pos") and not offer.has("seed") and not offer.has("hidden_regions"),"rumor provides clue rather than secret coordinates")
	print("EXPEDITION_GOALS checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
func material_goals():
	var sim=Sim.new(912,"town");var p=sim.add_player(1,"강화 준비");p.tutorial_done=true
	var sword=Equipment.make("sword",0,1,"goal-sword","none","warrior");Inventory.add_gear(p,sword);Inventory.equip(p,sword.id)
	var early=Goals.material_offer(p,1)
	check(early.goal.material=="seed" and early.goal.operation=="ore" and early.goal.target==5,"early ore shortage routes through real seed refinement recipe")
	p.highest_floor=12;p.cleared_floor=11;p.level=20;sword.upgrade=2
	var item=Inventory.find_item(p,sword.id);item.upgrade=2
	var offer=Goals.material_offer(p,12)
	check(offer.goal.material=="ore" and offer.goal.target==3 and offer.goal.floor==12,"equipment upgrade need comes from actual current quote")
	check(choose(sim,p,"materials",12),"register actual material goal")
	p.materials.ore=2
	check(not Goals.describe(p).ready,"insufficient material is not ready")
	p.materials.ore=3
	check(Goals.describe(p).ready,"exact required materials become ready")
	p.gold=0
	check(not Goals.work_status(p).ready and Goals.work_status(p).reason.contains("금화"),"materials secured is distinct from affordable work")
	p.gold=150
	check(Goals.work_status(p).ready,"actual quote permits funded upgrade")
	Goals.service_completed(p,{"facility":"smith","operation":"upgrade","item":"another-item"})
	check(p.expedition_goal.stage==0,"another equipment operation cannot complete goal")
	Goals.service_completed(p,{"facility":"smith","operation":"upgrade","item":sword.id})
	p.materials.ore=0
	check(Goals.describe(p).ready and p.expedition_goal.stage==3,"using materials for intended work remains completed")
	p.equipment.weapon="";p.equipped="";p.materials.clear();p.potions=5
	var recipe=Goals.material_offer(p,12);p.expedition_goal=recipe.goal
	p.materials[recipe.goal.material]=recipe.goal.target
	check(not Goals.describe(p).ready,"multi-ingredient recipe does not claim readiness after only one ingredient")
	var malformed=recipe.goal.duplicate(true);malformed.facility="smith";malformed.operation="potion"
	check(not Goals.valid(malformed),"impossible facility and operation combination rejected")
