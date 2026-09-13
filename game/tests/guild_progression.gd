extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Guild=preload("res://scripts/guild_progression.gd")
const Session=preload("res://scripts/local_session.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func act(sim,p,operation,extra={}):
	p.pos=Guild.World.FACILITIES.guild.pos
	var request=extra.duplicate();request.merge({"facility":"guild","operation":operation})
	return sim.action(p.id,"facility",JSON.stringify(request))
func run():
	var sim=Sim.new(7919,"town");var p=sim.add_player(1,"길드 검사");p.tutorial_done=true;p.gold=1000
	var peer=sim.add_player(2,"다른 선택");peer.tutorial_done=true
	check(Guild.rank(p)==0 and not act(sim,p,"accept",{"contract_kind":"elite","zone":"forest"}),"rank locks real contract request")
	for invalid in [null,"0",-1,1.5,INF,NAN,1000001,{},[]]:check(not Guild.valid_reputation(invalid),"invalid reputation rejected")
	for amount in [0,49,50,149,150,1000000]:
		p.guild_reputation=amount;check(Guild.rank(p)==(0 if amount<50 else 1 if amount<150 else 2),"exact rank threshold")
	p.guild_reputation=0
	check(act(sim,p,"accept",{"zone":"forest"}),"legacy hunt acceptance")
	check(Guild.valid_contract(p.guild_contract) and not p.guild_contract.has("kind"),"three field legacy contract kept")
	Guild.progress(p,"cave",{"elite":true});check(p.guild_contract.progress==0,"wrong zone cannot progress")
	for i in range(10):Guild.progress(p,"forest",{})
	check(p.guild_contract.progress==10,"hunt actual recipient progress")
	var before=sim.persistent(1).duplicate(true);var preview=Guild.quote(p,"claim",{"reward":"reputation"})
	check(sim.persistent(1)==before and preview.cost==0 and preview.result.contains("25"),"preview pure and exact reputation")
	check(preview.result.contains("정예까지 평판 25") and preview.result.contains("정예 사냥") and preview.result.contains("탐사 보급"),"choice explains next concrete unlock")
	check(not act(sim,p,"claim",{"reward":"both"}) and sim.persistent(1)==before,"invalid reward rolls back")
	check(act(sim,p,"claim",{"reward":"reputation"}) and p.gold==1000 and p.guild_reputation==25 and p.materials.essence==1,"choose reputation without gold")
	check(not act(sim,p,"claim",{"reward":"gold"}) and p.gold==1000,"other reward cannot be claimed after settlement")
	check(peer.guild_reputation==0 and not sim.snapshot(2).players[1].has("guild_reputation") and not sim.snapshot(2).players[1].has("guild_contract"),"peer progression private and independent")
	check(act(sim,peer,"accept",{"zone":"forest"}),"peer contract remains available")
	for i in range(10):Guild.progress(peer,"forest",{})
	var gold=peer.gold
	check(act(sim,peer,"claim") and peer.gold==gold+180 and peer.guild_reputation==0,"omitted reward retains gold default")
	check(act(sim,p,"accept",{"zone":"forest"}),"second contract")
	for i in range(10):Guild.progress(p,"forest",{})
	check(act(sim,p,"claim",{"reward":"reputation"}) and Guild.rank(p)==1,"reputation settlement unlocks rank")
	check(act(sim,p,"accept",{"zone":"forest","contract_kind":"elite"}),"unlocked elite contract accepted")
	Guild.progress(p,"forest",{});check(p.guild_contract.progress==0,"ordinary kill does not satisfy elite contract")
	for i in range(3):Guild.progress(p,"forest",{"elite":true})
	var saved=sim.persistent(1);saved.world_seed=7919
	var session=Session.new();root.add_child(session);var path=ProjectSettings.globalize_path("res://../runtime/guild-"+str(Time.get_ticks_usec())+".json")
	check(session.write_save(saved,path) and session.parse_save(path)!=null,"actual file saves advanced contract and reputation")
	var forged=saved.duplicate(true);forged.guild_reputation=0
	check(session.write_save(forged,path) and session.parse_save(path)==null,"advanced contract cannot load below required rank")
	var legacy=saved.duplicate(true);legacy.erase("guild_reputation");legacy.guild_contract={"zone":"forest","progress":2,"target":10}
	check(session.write_save(legacy,path) and session.parse_save(path)!=null,"legacy v7 without reputation still valid")
	for kind in Guild.CONTRACTS:
		var contract={"zone":"forest","kind":kind,"progress":0,"target":Guild.CONTRACTS[kind].target}
		check(Guild.valid_contract(JSON.parse_string(JSON.stringify(contract))),"contract JSON number roundtrip")
		contract.target+=1;check(not Guild.valid_contract(contract),"forged target rejected")
	p.materials.essence=Guild.Inventory.MAX_MATERIALS
	before=sim.persistent(1).duplicate(true)
	check(not act(sim,p,"claim",{"reward":"reputation"}) and sim.persistent(1)==before,"material cap prevents reputation and contract loss")
	p.materials.essence=0
	check(act(sim,p,"claim",{"reward":"reputation"}) and p.guild_reputation==100,"elite reward applies once")
	p.guild_reputation=150
	check(act(sim,p,"accept",{"zone":"forest","contract_kind":"guardian"}),"rank two guardian contract")
	Guild.progress(p,"forest",{"elite":true});check(p.guild_contract.progress==0,"elite not guardian")
	Guild.progress(p,"forest",{"guardian":true});check(p.guild_contract.progress==1,"actual guardian role advances")
	check(act(sim,p,"claim",{"reward":"gold"}),"guardian claim")
	for key in Guild.SERVICES:
		p.guild_reputation=0;check(not act(sim,p,key),"locked supply cannot be obtained")
		p.guild_reputation=150;p.materials.seed=100;p.materials.ore=100
		var quote=Guild.stage(p,key)
		check(quote.quote.reason.is_empty() and act(sim,p,key),"unlocked real guild supply")
		for field in ["gold","materials","potions","consumables"]:check(p[field]==quote.player[field],"supply exact staged output "+field)
	for capped in ["power_potion","fire_bottle"]:
		p.consumables={capped:Guild.Inventory.stack_limit(capped)};Guild.Inventory.initialize(p)
		before=sim.persistent(1).duplicate(true)
		check(not act(sim,p,"raid_supply") and sim.persistent(1)==before,"later output cap rolls back all earlier supply outputs and costs "+capped)
	p.network_leaving=true;check(not act(sim,p,"accept",{"zone":"forest"}),"leaving player cannot transact")
	var battle=Sim.new(129,"forest",1);var fighter=battle.add_player(1,"정예 의뢰");fighter.guild_reputation=150;fighter.tutorial_done=true
	fighter.guild_contract={"zone":"forest","kind":"elite","target":3,"progress":0}
	var ordinary=battle.enemies.values().filter(func(enemy):return not enemy.elite and not enemy.get("guardian",false))[0]
	battle.kill(1,ordinary);check(fighter.guild_contract.progress==0,"actual ordinary kill does not advance elite quest")
	var elite=battle.enemies.values().filter(func(enemy):return enemy.elite and not enemy.get("guardian",false))[0]
	battle.kill(1,elite);check(fighter.guild_contract.progress==1,"actual elite kill advances integrated quest")
	fighter.guild_contract={"zone":"forest","kind":"guardian","target":1,"progress":0}
	var guardian=battle.enemies.values().filter(func(enemy):return enemy.get("guardian",false))[0]
	battle.kill(1,guardian);check(fighter.guild_contract.progress==1,"actual guardian kill advances integrated quest")
	session.queue_free();print("GUILD_PROGRESSION checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
