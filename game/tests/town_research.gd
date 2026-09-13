extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Research=preload("res://scripts/town_research.gd")
const Inventory=preload("res://scripts/inventory_model.gd")
const Session=preload("res://scripts/local_session.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func prepared(sim,id=1):
	var p=sim.add_player(id,"연구자");p.gold=1000
	for key in ["seed","ore","essence"]:Inventory.add_stack(p,key,100)
	return p
func action(sim,p,key,operation):
	p.pos=Research.World.FACILITIES[Research.DEFINITIONS[key].facility].pos
	return sim.action(p.id,"facility",JSON.stringify({"facility":Research.DEFINITIONS[key].facility,"operation":operation,"research":key}))
func run():
	check(Research.valid({}) and Research.valid(Research.empty()),"old save has empty research")
	for value in [null,[],{"completed":[],"queue":[],"extra":1},{"completed":["invented"],"queue":[]},{"completed":["field_tools","field_tools"],"queue":[]},{"completed":["snare_engineering"],"queue":[]}]:check(not Research.valid(value),"invalid completed data rejected")
	for elapsed in [-1,NAN,INF,30.,"1"]:check(not Research.valid({"completed":[],"queue":[{"id":"field_tools","elapsed":elapsed}]}),"invalid elapsed rejected")
	check(not Research.valid({"completed":[],"queue":[{"id":"snare_engineering","elapsed":0.}]}),"queue cannot bypass prerequisite")
	check(not Research.valid({"completed":[],"queue":[{"id":"field_tools","elapsed":0.},{"id":"lure_mixture","elapsed":1.}]}),"waiting research cannot already progress")
	check(Research.matches("smith","도구")==["field_tools"] and Research.matches("alchemy","화염병")==["fire_distillation"],"search finds research names and products")
	check(Research.matches("inn","공격 강화 물약")==["reserve_pack"],"formal inventory name finds multi-output recipe")
	for key in Research.DEFINITIONS:
		check(preload("res://scripts/icon_library.gd").has_key(Research.DEFINITIONS[key].icon),"research uses a real semantic icon")
		var sim=Sim.new(77,"town");var p=prepared(sim);var peer=prepared(sim,2);var definition=Research.DEFINITIONS[key]
		check(not action(sim,p,key,"research_craft"),"recipe cannot be crafted before unlock")
		if not definition.parent.is_empty():
			check(not action(sim,p,key,"research_start"),"missing parent rejects enqueue")
			check(action(sim,p,definition.parent,"research_start"),"enqueue prerequisite")
		var before=sim.persistent(1).duplicate(true);var quote=Research.stage(p,key,"research_start")
		check(sim.persistent(1)==before and quote.reason.is_empty(),"preview pure")
		check(action(sim,p,key,"research_start") and p.gold==before.gold-definition.gold,"reserve cost on enqueue")
		var reserved=sim.persistent(1).duplicate(true)
		check(not action(sim,p,key,"research_start") and sim.persistent(1)==reserved,"repeat research cannot reserve twice")
		check(not Research.completed(peer,key),"other player progression unaffected")
		Research.tick(sim,10.)
		var save=sim.persistent(1).duplicate(true)
		check(Research.valid(save.town_research) and save.town_research.queue[0].elapsed==10.,"current progress exported")
		var resumed=Sim.new(88,"cave",12);var restored=resumed.add_player(1,"연구자",save)
		check(restored.town_research==save.town_research,"queue progress restored across map transition")
		Research.tick(resumed,120.)
		check(Research.completed(restored,key) and restored.town_research.queue.is_empty(),"work completes queued prerequisites then successor during expedition")
		check(not Research.completed(p,key),"resumed candidate cannot mutate original character")
		Research.tick(sim,120.)
		check(Research.completed(p,key) and p.town_research.queue.is_empty(),"completed research unlocks recipe")
		var craft=Research.stage(p,key,"research_craft")
		check(action(sim,p,key,"research_craft"),"unlocked recipe actually produces items")
		for field in ["gold","materials","potions","consumables","bag_positions"]:check(p[field]==craft.player[field],"recipe exact output "+field)
		check(not sim.snapshot(2).players[1].has("town_research"),"research state private to owner")
	var sim=Sim.new(77,"town");var p=prepared(sim)
	var before=sim.persistent(1).duplicate(true)
	check(action(sim,p,"field_tools","research_start") and action(sim,p,"snare_engineering","research_start") and action(sim,p,"lure_mixture","research_start"),"reserve three studies across facilities")
	check(not action(sim,p,"field_pack","research_start"),"queue capacity enforced")
	Research.tick(sim,5.)
	check(action(sim,p,"field_tools","research_cancel"),"cancel active and dependent study")
	check(p.town_research.queue.size()==1 and p.town_research.queue[0].id=="lure_mixture" and p.town_research.queue[0].elapsed==0.,"unrelated queued study retained")
	check(action(sim,p,"lure_mixture","research_cancel") and sim.persistent(1)==before,"full reserved costs refunded exactly")
	check(not action(sim,p,"lure_mixture","research_cancel"),"duplicate cancel cannot refund again")
	p.gold=0;var empty=sim.persistent(1).duplicate(true)
	check(not action(sim,p,"field_tools","research_start") and sim.persistent(1)==empty,"no partial reserve on missing gold")
	p.gold=1000;p.materials.ore=0;empty=sim.persistent(1).duplicate(true)
	check(not action(sim,p,"field_tools","research_start") and sim.persistent(1)==empty,"no partial reserve on missing materials")
	p.materials.ore=100;check(action(sim,p,"field_tools","research_start"),"refund cap fixture")
	p.materials.ore=Inventory.MAX_MATERIALS;empty=sim.persistent(1).duplicate(true)
	check(not action(sim,p,"field_tools","research_cancel") and sim.persistent(1)==empty,"refund overflow preserves study and every reserved resource")
	p.network_leaving=true;Research.tick(sim,100.)
	check(not Research.completed(p,"field_tools"),"departing player does not advance work")
	check(not action(sim,p,"field_tools","research_cancel"),"departing transaction rejected")
	var overflow=Sim.new(77,"town");var owner=prepared(overflow);owner.town_research.completed=["field_pack"]
	Inventory.add_stack(owner,"tool",Inventory.MAX_MATERIALS)
	var exact=overflow.persistent(1).duplicate(true)
	check(not action(overflow,owner,"field_pack","research_craft") and overflow.persistent(1)==exact,"second recipe output failure rolls back first output and all costs")
	var session=Session.new();session.save_directory=ProjectSettings.globalize_path("res://../runtime/research-model/"+str(Time.get_ticks_usec()));session.sim=Sim.new(5,"town");var player=prepared(session.sim);session.connected=true
	check(action(session.sim,player,"field_tools","research_start"),"paused session fixture")
	session.paused=true;var world_clock=session.sim.clock;session._physics_process(5.)
	check(player.town_research.queue[0].elapsed==5. and session.sim.clock==world_clock,"personal menu advances research while combat remains paused")
	check(session.save_game() and session.parse_save(session.save_path()).town_research.queue[0].elapsed==5.,"actual file save roundtrip preserves queue")
	session.connected=false;session.free()
	print("TOWN_RESEARCH checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
