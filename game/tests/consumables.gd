extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Items=preload("res://scripts/consumables.gd")
const Inv=preload("res://scripts/inventory_model.gd")
const Ops=preload("res://scripts/town_operations.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(value:bool,label:String):
	checks+=1
	if not value:failures.append(label);push_error(label)
func run():
	var sim=Sim.new(741,"town",1);sim.add_player(1,"물약 검사");var p=sim.players[1]
	p.gold=10000;p.materials={"seed":100,"ore":100,"essence":100};Inv.initialize(p)
	for item in ["mana_potion","power_potion"]:
		check(Inv.add_stack(p,item,5),"stack add "+item)
		check(Inv.find_item(p,Items.bag_id(item)).count==5,"inventory item "+item)
		for bad in [-1,0,1.5,INF,NAN,21]:check(not Inv.add_stack(p,item,bad),"reject bad stack "+item+str(bad))
		var staged=Ops.stage(p,"shop",item,{"quantity":5})
		check(staged.quote.reason.is_empty() and Items.count(staged.player,item)==10 and staged.player.gold==p.gold-Items.ITEMS[item].price*5,"actual purchase quote "+item)
		staged=Ops.stage(p,"alchemy",item,{"target_quantity":10})
		check(staged.quote.reason.is_empty() and Items.count(staged.player,item)==11,"target batches "+item)
		var before=var_to_bytes(p);check(not Ops.stage(p,"shop",item,{"quantity":100}).quote.reason.is_empty() and before==var_to_bytes(p),"rejected quote atomic "+item)
	p.stamina=0;p.potion_cd=0
	check(sim.action(1,"mana_potion") and p.stamina==60 and Items.count(p,"mana_potion")==4,"mana restores actual skill resource")
	check(not sim.action(1,"power_potion") and Items.count(p,"power_potion")==5,"shared potion cooldown")
	p.potion_cd=0;p.stamina=p.max_stamina
	check(not sim.action(1,"mana_potion") and Items.count(p,"mana_potion")==4,"full resource does not waste potion")
	var base=sim.damage_for(p);sim.combat.jobs.buff(p,"attack",.1,60)
	check(sim.action(1,"power_potion"),"power potion used")
	check(sim.combat.jobs.attack_power(p,base)==roundi(base*1.1*1.2),"power stacks independently with class attack")
	check(preload("res://scripts/status_markers.gd").timed_for(p).any(func(x):return x.key=="buff:potion_attack" and x.remaining==30),"timed icon actual buff")
	p.potion_cd=0
	check(not sim.action(1,"power_potion") and Items.count(p,"power_potion")==4,"active effect cannot waste refresh")
	for i in 301:sim.tick(.1)
	check(not p.job_state.buffs.has("potion_attack"),"effect expires in combat clock")
	check(is_equal_approx(sim.combat.jobs.value(p,"attack"),.1),"expiry preserves independent class buff")
	p.hp=0;check(not sim.action(1,"mana_potion") and not sim.action(1,"power_potion"),"dead player cannot consume")
	p.hp=p.max_hp;p.potion_cd=0;p.stamina=0;p.consumables.mana_potion=1
	check(sim.action(1,"mana_potion") and not p.bag_positions.has(Items.bag_id("mana_potion")),"last item frees its cell")
	var session=preload("res://scripts/local_session.gd").new();root.add_child(session)
	var saved=sim.persistent(1);saved.world_seed=741
	var restored=session.validate_save(JSON.parse_string(JSON.stringify(saved)))
	check(restored!=null and restored.consumables==p.consumables,"save validates all new counts")
	for value in [-1,21,1.2,"5",null]:
		var invalid=saved.duplicate(true);invalid.consumables.mana_potion=value
		check(session.validate_save(invalid)==null,"reject malformed saved count "+str(value))
	session.set_physics_process(false);session.save_directory=ProjectSettings.globalize_path("res://../runtime/consumables/"+str(Time.get_ticks_usec()))
	check(session.write_save(saved,session.save_path()),"atomic disk save")
	session.start_game("",1);var actual=session.sim.players[session.local_id]
	check(actual.consumables==p.consumables and not actual.job_state.buffs.has("potion_attack"),"disk reload counts without transient buff")
	actual.stamina=0;Inv.add_stack(actual,"mana_potion",2);session.paused=true
	check(session.act("mana_potion") and actual.consumables.mana_potion==1,"inventory pause supports consuming new item")
	check(session.disconnect_game(),"close saves new count")
	session.start_game("",1);check(session.sim.players[1].consumables.mana_potion==1,"reconnect preserves consumed count");session.disconnect_game()
	var full=p.duplicate(true);full.consumables={};full.inventory=[];full.bag_positions={};full.materials={};full.potions=1
	for i in Inv.CAPACITY-1:full.inventory.append(preload("res://scripts/equipment_catalog.gd").make("head",0,0,"full-"+str(i),"none","warrior"))
	Inv.initialize(full);var full_before=var_to_bytes(full)
	check(not Inv.add_stack(full,"mana_potion",1) and full_before==var_to_bytes(full),"full bag rejects first new potion stack atomically")
	var old=saved.duplicate(true);old.erase("consumables")
	check(session.validate_save(old)!=null,"old saves need no new field")
	var peer=sim.add_player(2,"친구")
	check(not sim.snapshot(2).players[1].has("consumables") and sim.snapshot(1).players[1].consumables==p.consumables,"network personal inventory privacy")
	var frame=preload("res://scripts/portrait_frame.gd")
	for pair in [[1,0],[29,0],[30,1],[59,1],[60,2],[99,2],[100,3]]:check(frame.rank_for(pair[0])==pair[1],"portrait level threshold "+str(pair[0]))
	session.queue_free();await process_frame
	print("CONSUMABLES checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
