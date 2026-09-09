extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const C=preload("res://scripts/content.gd")
const E=preload("res://scripts/equipment_catalog.gd")
const I=preload("res://scripts/inventory_model.gd")
const B=preload("res://scripts/job_balance.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run():
	C.initialize_jobs();var sim=Sim.new(31,"town");var p=sim.add_player(1,"장비 검사");p.level=100
	for owner in C.CLASSES:
		for wearer in C.CLASSES:
			p.class_id=wearer
			var weapon=E.make("sword",3,2,"weapon","focus",owner);var armor=E.make("chest",3,2,"armor","focus",owner)
			check(E.reason(p,weapon).is_empty()==(owner==wearer),owner+" weapon to "+wearer)
			check(E.reason(p,armor).is_empty()==(C.base_class(owner)==C.base_class(wearer)),owner+" armor to "+wearer)
	p.class_id="swordsman";sim.combat.jobs.reset(p)
	var legacy=E.make("sword",0,1,"legacy","focus","swordsman");legacy.affix="none";legacy.upgrade=2
	E.normalize(legacy,p);check(legacy.affix=="focus","legacy rare empty option receives a working stat")
	p.inventory=[legacy];p.equipment={"weapon":"legacy"};check(E.stat_values(p).get("strength",0)==3,"legacy unlocked option applies actual stat")
	for grade in range(5):
		p.inventory=[];p.equipment={};p.equipped="";p.bag_positions={};I.initialize(p)
		var gear=E.make("sword",5,grade,"gear","focus",p.class_id);I.add_gear(p,gear);check(I.equip(p,gear.id),"equip grade "+str(grade))
		for enhance in range(6):
			gear.upgrade=enhance;sim.recalculate(p)
			check(E.active(gear)==(grade>0 and enhance>=E.UNLOCK[grade]),"option lock boundary")
			if grade in [1,2]:check(p.gear_stats.get("strength",0)==(3*grade+10 if enhance>=E.UNLOCK[grade] else 0),"stat option real contribution")
			if grade>=3:check(E.skill_modifiers(p).values().any(func(v):return v>0)==(enhance>=E.UNLOCK[grade]),"skill option real contribution")
		if grade>=3:
			var capped=preload("res://scripts/service_quote.gd").quote(p,"smith","upgrade",{"item":"gear"})
			check(capped.cost==0 and capped.materials.is_empty() and not "+6" in capped.result,"maximum enhancement preview never offers +6 or charges")
			gear.resonance="force";gear.upgrade=0
			var n=C.SKILLS.swordsman.filter(func(x):return x.effect=="active")[0];var locked=B.profile(p,n,3,100,1000)
			gear.upgrade=E.UNLOCK[grade];var unlocked=B.profile(p,n,3,100,1000)
			check(unlocked.power>locked.power,"epic/legend skill damage unlocked")
	p.inventory=[];p.equipment={};p.equipped="";I.initialize(p)
	var wrong=E.make("sword",0,2,"wrong","focus","thief");I.add_gear(p,wrong);check(not I.equip(p,"wrong"),"runtime rejects thief sword on swordsman")
	var own=E.make("sword",0,2,"own","focus","swordsman");I.add_gear(p,own);I.equip(p,"own")
	check(sim.action(1,"class","tank") and p.equipped=="" and p.bag_positions.has("own"),"class change returns incompatible weapon to bag")
	p.class_id="thief";p.pos=preload("res://scripts/world_catalog.gd").FACILITIES.smith.pos;p.gold=10000;p.materials={"ore":100,"essence":10}
	var rare=E.make("sword",0,1,"rare","focus","thief");I.add_gear(p,rare);I.equip(p,"rare")
	var service=preload("res://scripts/town_services.gd")
	check(service.transact(sim,p,{"facility":"smith","operation":"upgrade","item":"rare"}),"upgrade +1")
	check(not E.active(I.find_item(p,"rare")),"+1 remains locked")
	check(service.transact(sim,p,{"facility":"smith","operation":"upgrade","item":"rare"}) and p.gear_stats.strength==3,"+2 unlock applies stat")
	var local=preload("res://scripts/local_session.gd").new();root.add_child(local);local.sim=sim;local.connected=true;local.slot=3;local.save_directory=ProjectSettings.globalize_path("res://../runtime/equipment-v02");local.save_game()
	var saved=local.parse_save(local.save_path());check(saved!=null and saved.schema_version==7,"new gear save parsed")
	if saved!=null:
		var restored=Sim.new(31,"town");var r=restored.add_player(1,"",saved);check(r.gear_stats.strength==3 and r.equipped=="rare","gear options persist")
	local.connected=false;local.queue_free()
	print("EQUIPMENT_V02_TESTS checks=",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
