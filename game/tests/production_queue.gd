extends SceneTree
const Production=preload("res://scripts/production_queue.gd")
const Sim=preload("res://scripts/simulation.gd")
const Session=preload("res://scripts/local_session.gd")
const Inventory=preload("res://scripts/inventory_model.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func prepared(sim,id=1):
	var p=sim.add_player(id,"제작자");p.gold=100000;p.potions=0
	for key in ["seed","ore","essence"]:Inventory.add_stack(p,key,500)
	Inventory.initialize(p);return p
func start(sim,p,recipe,mode="count",number=1):
	var facility=Production.recipes()[recipe].facility;p.pos=Production.World.FACILITIES[facility].pos
	return sim.action(p.id,"facility",JSON.stringify({"facility":facility,"operation":"production_start","recipe":recipe,"mode":mode,"quantity":number}))
func cancel(sim,p,id,facility="alchemy"):
	p.pos=Production.World.FACILITIES[facility].pos
	return sim.action(p.id,"facility",JSON.stringify({"facility":facility,"operation":"production_cancel","order":id}))
func run():
	check(Production.valid({}) and Production.valid(Production.empty()),"old saves start without production")
	for malformed in [null,[],{"next_id":0,"queue":[]},{"next_id":1,"queue":[],"extra":true},{"next_id":2,"queue":[{}]}]:check(not Production.valid(malformed),"malformed queue rejected")
	for recipe in Production.recipes():
		var sim=Sim.new(711,"town");var p=prepared(sim);var peer=prepared(sim,2);var definition=Production.recipes()[recipe]
		p.level=100
		for material in definition.materials:
			if not p.materials.has(material):Inventory.add_stack(p,material,Inventory.stack_limit(material))
		check(preload("res://scripts/icon_library.gd").has_key(definition.icon),"existing semantic recipe icon")
		if not definition.research.is_empty():
			check(not start(sim,p,recipe),"locked research recipe cannot enqueue")
			p.town_research.completed=Production.Research.DEFINITIONS.keys()
		var peer_before=sim.persistent(2).duplicate(true);var before=sim.persistent(1).duplicate(true)
		var request={"facility":definition.facility,"operation":"production_start","recipe":recipe,"mode":"count","quantity":2}
		var quote=Production.stage(p,request)
		check(quote.reason.is_empty() and sim.persistent(1)==before,"preview does not reserve resources")
		check(start(sim,p,recipe,"count",2),"real facility queues work")
		check(p.gold==before.gold-definition.gold and p.production.queue.size()==1,"only first batch reserved")
		for key in definition.outputs:check(Production.amount(p,key)==Production.amount(before,key),"no instant production")
		Production.tick(sim,definition.seconds/2.)
		check(p.production.queue[0].elapsed==definition.seconds/2. and Production.valid(p.production),"partial work valid")
		var saved=sim.persistent(1);var resumed=Sim.new(712,"cave",12);var restored=resumed.add_player(1,"제작자",saved)
		check(restored.production==saved.production,"reserved batch and elapsed survive floor transition")
		Production.tick(resumed,definition.seconds*2.)
		check(restored.production.queue.is_empty() and restored.gold==before.gold-definition.gold*2,"two batches complete and charge exactly twice")
		for key in definition.outputs:check(Production.amount(restored,key)==Production.amount(before,key)+int(definition.outputs[key])*2,"exact produced quantities")
		check(not sim.snapshot(2).players[1].has("production"),"queue private in peer snapshots")
		check(sim.persistent(2)==peer_before,"other player property untouched")
		var first=int(p.production.queue[0].id)
		check(cancel(sim,p,first,definition.facility),"cancel unfinished work at own facility")
		for key in ["gold","materials","potions","consumables","bag_positions"]:check(p[key]==before[key],"reserved resources fully refunded "+key)
		var refunded=sim.persistent(1).duplicate(true)
		check(not cancel(sim,p,first,definition.facility) and sim.persistent(1)==refunded,"duplicate cancellation never refunds twice")
	var sim=Sim.new(1,"town");var p=prepared(sim)
	check(start(sim,p,"alchemy:potion","target",8),"target stock order accepted")
	Production.tick(sim,30.)
	check(p.potions==9 and p.production.queue.is_empty(),"target stock stops at complete batch 9 without endless production")
	check(not start(sim,p,"alchemy:potion","target",8),"already satisfied target rejected")
	p.potions=Inventory.MAX_POTIONS-1
	check(not start(sim,p,"alchemy:potion","target",Inventory.MAX_POTIONS),"target rejects batch above stack cap")
	p.potions=0;p.gold=10
	check(start(sim,p,"alchemy:potion","count",2),"reserve affordable first batch")
	Production.tick(sim,20.)
	check(p.potions==3 and p.gold==0 and p.production.queue.size()==1 and not p.production.queue[0].reserved,"insufficient later cost waits without consumption")
	var order=p.production.queue[0];check(Production.waiting_reason(p,order)=="금화 부족","waiting reason identifies missing resource")
	p.gold=10;Production.tick(sim,10.)
	check(p.potions==6 and p.gold==0 and p.production.queue.is_empty(),"work resumes after funding")
	p.gold=1000;p.potions=0
	check(start(sim,p,"alchemy:potion","repeat") and start(sim,p,"alchemy:ore"),"repeat and one-off queue together")
	Production.tick(sim,12.)
	check(p.potions==3 and p.production.queue.size()==1 and p.production.queue[0].mode=="repeat","repeat rotates so next order gets its turn")
	check(cancel(sim,p,p.production.queue[0].id),"stop repeat removes future work")
	check(start(sim,p,"alchemy:potion"),"full bag fixture queued")
	p.potions=Inventory.MAX_POTIONS;var spent=p.gold;Production.tick(sim,10.)
	check(p.production.queue[0].elapsed==6. and p.production.queue[0].reserved and p.potions==Inventory.MAX_POTIONS and p.gold==spent,"full output waits at completion retaining reservation")
	var blocked=sim.persistent(1).duplicate(true);Production.tick(sim,1.)
	check(sim.persistent(1)==blocked,"retry full bag cannot consume twice")
	p.potions=Inventory.MAX_POTIONS-3;Production.tick(sim,1.)
	check(p.potions==Inventory.MAX_POTIONS and p.production.queue.is_empty(),"space frees and exact pending output delivered")
	check(start(sim,p,"alchemy:essence"),"refund overflow fixture")
	p.materials.seed=Inventory.MAX_MATERIALS;blocked=sim.persistent(1).duplicate(true)
	check(not cancel(sim,p,p.production.queue[0].id) and sim.persistent(1)==blocked,"refund overflow preserves reserved resources and progress")
	p.materials.seed=500;check(cancel(sim,p,p.production.queue[0].id),"refund succeeds after room restored")
	p.potions=0;check(start(sim,p,"alchemy:potion","target",3),"external target fulfillment fixture")
	var money=p.gold;p.potions=3;Production.tick(sim,1.)
	check(p.production.queue.is_empty() and p.gold==money+10 and p.potions==3,"externally reached target refunds reserved batch")
	for value in [0,-1,100,1.5,"2"]:check(not start(sim,p,"alchemy:potion","count",value),"invalid count request rejected")
	check(start(sim,p,"alchemy:potion"),"priority fixture first")
	check(start(sim,p,"alchemy:ore") and start(sim,p,"alchemy:essence"),"three work slots")
	check(not start(sim,p,"alchemy:potion"),"fourth work slot rejected")
	var priority=int(p.production.queue[2].id)
	check(sim.action(1,"facility",JSON.stringify({"facility":"alchemy","operation":"production_priority","order":priority})) and p.production.queue[0].id==priority,"player can reprioritize blocked queue")
	var departure=sim.persistent(1).duplicate(true);p.network_leaving=true;Production.tick(sim,100.)
	check(sim.persistent(1)==departure and not cancel(sim,p,priority),"departing owner cannot advance or transact")
	var journey_sim=Sim.new(7,"town");var journey=prepared(journey_sim)
	check(journey_sim.action(1,"select_goal",JSON.stringify({"id":"research:field_tools","floor":1})),"research preparation selected")
	journey.town_research.completed=["field_tools"]
	check(start(journey_sim,journey,"research:field_tools"),"research product queued")
	check(journey.expedition_goal.stage==0,"enqueue alone never completes first crafting journey")
	check(journey_sim.persistent(1).schema_version==8,"reserved production uses save envelope rejected by old clients")
	Production.tick(journey_sim,8.)
	check(journey.expedition_goal.stage==3,"delivered research product completes actual first crafting journey")
	check(journey_sim.persistent(1).schema_version==8,"new saves retain the new generation after queue completion")
	var session=Session.new();session.save_directory=ProjectSettings.globalize_path("res://../runtime/production-model/"+str(Time.get_ticks_usec()));session.sim=Sim.new(5,"town");var owner=prepared(session.sim);session.connected=true
	check(start(session.sim,owner,"alchemy:potion"),"paused menu production fixture")
	session.paused=true;var clock=session.sim.clock;session._physics_process(3.)
	check(owner.production.queue[0].elapsed==3. and session.sim.clock==clock,"personal menu progresses crafting without combat")
	check(session.save_game(),"production save written")
	var restored=session.parse_save(session.save_path())
	check(restored!=null and restored.production==owner.production,"real disk save preserves work order")
	var tampered=restored.duplicate(true);tampered.production.queue[0].elapsed=INF
	check(session.validate_save(tampered)==null,"nonfinite work progress rejected on save load")
	session.connected=false;session.free()
	print("PRODUCTION_QUEUE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
