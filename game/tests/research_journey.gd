extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Goals=preload("res://scripts/expedition_goals.gd")
const Journey=preload("res://scripts/research_journey.gd")
const Research=preload("res://scripts/town_research.gd")
const Inventory=preload("res://scripts/inventory_model.gd")
const Session=preload("res://scripts/local_session.gd")
var checks=0
var failures=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func select(sim,p,key):return sim.action(p.id,"select_goal",JSON.stringify({"id":key,"floor":int(p.highest_floor)}))
func work(sim,p,key,operation):
	p.pos=Research.World.FACILITIES[Research.DEFINITIONS[key].facility].pos
	return sim.action(p.id,"facility",JSON.stringify({"facility":Research.DEFINITIONS[key].facility,"operation":operation,"research":key}))
func run():
	var sim=Sim.new(7919,"town");var p=sim.add_player(1,"연구 탐사");p.tutorial_done=true;p.gold=1000
	var other=sim.add_player(2,"개인 목표");other.tutorial_done=true
	check(select(sim,p,"research:field_tools"),"select concrete research goal")
	check(Goals.valid(p.expedition_goal),"strict saved goal contract")
	check(Journey.need(p,"field_tools",1)=={"material":"seed","target":12,"floor":1,"refine":true},"early ore uses actual three-ore recipe in two batches plus research seed")
	check(not Goals.describe(p).ready and Goals.describe(p).detail.contains("12"),"HUD shows missing refinement inputs")
	check(other.expedition_goal.is_empty() and not sim.snapshot(2).players[1].has("expedition_goal"),"goal private to owner")
	check(not select(sim,other,"research:snare_engineering"),"missing prerequisite cannot be selected")
	check(not select(sim,other,"research:unknown"),"unknown research rejected")
	Inventory.add_stack(p,"seed",12)
	check(Goals.work_status(p).ready and Goals.describe(p).facility=="alchemy","prepared seeds route to actual refinery")
	p.pos=Research.World.FACILITIES.alchemy.pos
	for i in range(2):check(sim.action(1,"facility",JSON.stringify({"facility":"alchemy","operation":"ore"})),"real ore conversion")
	check(p.materials.ore==6 and p.materials.seed==2 and p.expedition_goal.item=="field_tools" and p.expedition_goal.stage==0,"conversion retains final research target")
	check(Goals.work_status(p).operation=="research_start" and Goals.describe(p).facility=="smith","after refinement goes back to study")
	check(work(sim,p,"field_tools","research_start") and p.expedition_goal.stage==0,"enqueue not mistaken for finished craft")
	check(not Goals.work_status(p).ready and Goals.describe(p).detail.contains("진행"),"research wait has explicit current step")
	Research.tick(sim,30)
	check(Goals.work_status(p).ready and Goals.work_status(p).operation=="research_craft","completed research now quotes actual recipe")
	var session=Session.new();root.add_child(session);var path=ProjectSettings.globalize_path("res://../runtime/journey-"+str(Time.get_ticks_usec())+".json")
	var save=sim.persistent(1);save.world_seed=7919
	check(Goals.valid(JSON.parse_string(JSON.stringify(save.expedition_goal))),"goal accepts integral JSON floats")
	check(session.write_save(save,path) and session.parse_save(path)!=null,"actual save validates research target and unlock")
	if session.parse_save(path)==null:quit(1);return
	var material_save=save.duplicate(true);material_save.expedition_goal=Goals.material_offer(p,1).goal
	check(session.write_save(material_save,path) and session.parse_save(path)!=null,"existing material goal also survives integral JSON stage")
	check(session.write_save(save,path),"restore research checkpoint for next phase")
	var restored=Sim.new(888,"town");var loaded=restored.add_player(1,p.name,session.parse_save(path))
	check(Goals.work_status(loaded).operation=="research_craft","restored first-craft step")
	check(work(sim,p,"field_tools","research_craft") and p.materials.tool==1 and p.expedition_goal.stage==3,"only real matching craft completes chain")
	check(Goals.describe(p).detail.contains("다음 도전"),"completed craft points to next challenge")
	check(preload("res://scripts/expedition_journal.gd").recommendations(p)[0].facility=="portal","return recommendations prioritize next expedition")
	check(select(sim,p,"advance") and p.expedition_goal.kind=="advance","explicit next expedition selection")
	p.highest_floor=12;p.cleared_floor=11;p.materials.seed=0;p.materials.ore=0;p.town_research=Research.empty()
	check(select(sim,p,"research:lure_mixture"),"select mixed research inputs")
	var first_floor=Goals.describe(p).floor
	p.materials.seed=6
	check(Goals.describe(p).floor in [11,12] and first_floor<10 and p.expedition_goal.item=="lure_mixture","current shortage changes forest recommendation to nearest mine without losing research target")
	p.town_research.completed=["lure_mixture"];p.materials.seed=0;p.materials.ore=2
	check(Goals.describe(p).floor!=12 and Goals.describe(p).detail.contains("1"),"after research live recipe seed need changes destination again")
	for depth in range(1,101):
		p.highest_floor=depth;p.cleared_floor=depth-1
		for key in Research.DEFINITIONS:
			p.town_research.completed=Research.DEFINITIONS.keys();p.town_research.queue=[]
			var offer=Journey.offer(p,key,depth)
			check(Goals.valid(offer.goal) and offer.goal.floor<=depth and int(offer.goal.floor)%10!=0,"research offer reachable at each unlocked depth")
			check(not offer.has("pos") and not offer.has("hidden_regions"),"clue never reveals hidden coordinates")
	var candidate=Journey.offer(p,"field_tools",12).goal
	for field in ["item","facility","operation","material","target","requirements","stage"]:
		var corrupt=candidate.duplicate(true)
		corrupt[field]={"item":"bad","facility":"portal","operation":"upgrade","material":"essence","target":999999,"requirements":{"ore":1},"stage":2}[field]
		check(not Goals.valid(corrupt),"forged research goal field rejected "+field)
	p.expedition_goal=candidate;p.gold=0;p.materials.ore=0
	check(not work(sim,p,"field_tools","research_craft") and p.expedition_goal.stage==0,"failed craft cannot complete goal")
	check(not select(Sim.new(991,"forest",1),p,"research:field_tools"),"no dungeon goal rewrite")
	session.queue_free()
	print("RESEARCH_JOURNEY checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
