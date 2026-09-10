extends SceneTree
const Local=preload("res://scripts/local_session.gd")
const Sim=preload("res://scripts/simulation.gd")
const Creation=preload("res://scripts/character_creation.gd")
const Progression=preload("res://scripts/progression.gd")
const Content=preload("res://scripts/content.gd")
const Inventory=preload("res://scripts/inventory_model.gd")
const Equipment=preload("res://scripts/equipment_catalog.gd")
const Operations=preload("res://scripts/town_operations.gd")
const Quote=preload("res://scripts/service_quote.gd")
const World=preload("res://scripts/world_catalog.gd")
var checks=0
var failures=[]
var folder=""

func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)

func new_session(key:String,cls:String="warrior"):
	var session=Local.new();root.add_child(session);session.set_physics_process(false)
	session.save_directory=folder.path_join(key)
	check(session.create_character({"name":"성장 보상 검증","class_id":cls,"avatar":"auto","costume":"none","stats":Creation.suggested(cls)},1),key+" isolated character created")
	return session

func close_session(session):
	check(session.disconnect_game(),"isolated session saved on close")
	root.remove_child(session);session.free()

func level_notices(events:Array)->int:
	return events.filter(func(e):return str(e.get("text","")).begins_with("LEVEL UP")).size()

func tutorial_arrival():
	for cls in ["warrior","ranger","mage"]:
		var session=new_session("arrival-"+cls,cls);var p=session.sim.players[1]
		for index in range(5):session.sim.kill(1,session.sim.enemies.values()[index])
		check(p.level==1 and p.xp==152 and p.gold==38 and p.tutorial_kills==5,cls+" five ordinary kills retain actual XP and gold")
		var stats=p.stats.duplicate(true);var gear=p.inventory.duplicate(true)
		p.hp=17;p.stamina=3
		var received=[];session.event_received.connect(func(e):received.append(e.duplicate(true)))
		check(session.travel("town"),cls+" first tutorial arrival succeeds")
		p=session.sim.players[1]
		check(p.level==2 and p.xp==0 and p.gold==138 and p.tutorial_done and p.quest_done,cls+" only missing 73 XP and one gold reward granted")
		check(Content.available_points(p)==1 and Progression.available(p)==3 and p.stats==stats,cls+" level budget grants one skill and three unspent stats")
		check(p.inventory==gear and p.skill_ranks.is_empty() and p.constellation_allocations.is_empty(),cls+" no duplicate starter gear or unsolicited allocations")
		check(p.hp==p.max_hp and p.max_hp==148 and p.stamina==3,cls+" normal level-up heals without replenishing stamina")
		check(level_notices(received)==1 and session.state.players[1].level==2,cls+" successful arrival publishes committed level and one notice")
		var saved=session.parse_save(session.save_path())
		check(saved!=null and saved.level==2 and saved.xp==0 and saved.gold==138 and saved.tutorial_done,cls+" granted level is in valid save")
		check(session.sim.action(1,"invest",cls+"_fan") and Content.available_points(p)==0,cls+" earned skill point can learn a root active")
		check(session.act("bind_skill","skill_q:"+cls+"_fan") and session.sim.action(1,"stat","strength"),cls+" normal town binding and stat investment consume earned budget")
		var property=session.sim.persistent(1).duplicate(true)
		check(session.enter_floor(1) and session.travel("town"),cls+" later expedition returns normally")
		check(session.sim.persistent(1)==property and level_notices(received)==1,cls+" later arrival never grants again")
		check(session.disconnect_game(),cls+" disconnect after reward")
		session.start_game("ignored",1);p=session.sim.players[1]
		check(session.travel("town") and session.sim.persistent(1)==property,cls+" reload and repeated town travel preserve allocations without reward")
		close_session(session)

func tutorial_boundaries():
	for entry in [
		{"level":1,"xp":0,"kills":5,"done":false,"after_level":2,"after_xp":0},
		{"level":1,"xp":224,"kills":5,"done":false,"after_level":2,"after_xp":0},
		{"level":2,"xp":73,"kills":5,"done":false,"after_level":2,"after_xp":73},
		{"level":8,"xp":234,"kills":5,"done":false,"after_level":8,"after_xp":234},
		{"level":1,"xp":152,"kills":5,"done":true,"after_level":1,"after_xp":152},
	]:
		var session=new_session("boundary-%d"%checks);var p=session.sim.players[1]
		p.level=entry.level;p.xp=entry.xp;p.tutorial_kills=entry.kills;p.tutorial_done=entry.done
		p.quest_done=true;p.gold=219;session.sim.recalculate(p)
		check(session.travel("town"),"eligible or previously completed arrival")
		p=session.sim.players[1]
		check(p.level==entry.after_level and p.xp==entry.after_xp and p.gold==219,"XP threshold and existing quest reward are preserved "+str(entry))
		close_session(session)
	var locked=new_session("four-kills");var p=locked.sim.players[1]
	p.tutorial_kills=4;p.xp=224
	var previous=locked.sim.persistent(1).duplicate(true)
	check(not locked.travel("town") and locked.sim.persistent(1)==previous,"four kills cannot obtain arrival XP or gold")
	close_session(locked)
	# Completed V6 and V7 saves at level 1 do not receive retrospective XP.
	for schema in [6,7]:
		var session=new_session("completed-v%d"%schema);var saved=session.sim.persistent(1)
		saved.merge({"schema_version":schema,"tutorial_done":true,"quest_done":true,"tutorial_kills":5,"level":1,"xp":152,"gold":317,"stats":{},"creation_points":0,"world_seed":session.world_seed},true)
		check(session.write_save(saved,session.save_path()),"completed legacy fixture saved")
		session.connected=false;session.start_game("ignored",1)
		check(session.travel("town"),"completed legacy save enters town")
		var old=session.sim.players[1]
		check(old.level==1 and old.xp==152 and old.gold==317 and Content.available_points(old)==0,"completed V%d save gets no duplicate reward"%schema)
		close_session(session)

func tutorial_save_failure():
	var session=new_session("atomic-arrival");var p=session.sim.players[1]
	p.tutorial_kills=5;p.xp=152;p.gold=38;p.hp=17;p.stamina=3
	check(session.save_game(),"pre-arrival fixture saved")
	var before=p.duplicate(true);var old_sim=session.sim;var old_seed=session.world_seed
	var disk=FileAccess.get_file_as_bytes(session.save_path());var snapshots=session.received_snapshots
	var entered=[];var received=[]
	session.entered.connect(func():entered.append(true))
	session.event_received.connect(func(e):received.append(e.duplicate(true)))
	var occupied=session.save_path()+".tmp"
	check(DirAccess.make_dir_absolute(occupied)==OK,"isolated temporary save path blocked")
	check(not session.travel("town"),"failed save rejects tutorial completion")
	check(session.sim==old_sim and session.world_seed==old_seed and p==before,"failed arrival keeps HP, XP, level, gold, flags and allocations")
	check(FileAccess.get_file_as_bytes(session.save_path())==disk,"failed arrival preserves previous save bytes")
	check(entered.is_empty() and session.received_snapshots==snapshots and level_notices(received)==0,"failed arrival publishes no level-up or new snapshot")
	check(DirAccess.remove_absolute(occupied)==OK,"isolated save path recovered")
	check(session.travel("town"),"same arrival succeeds on retry")
	p=session.sim.players[1]
	check(p.level==2 and p.xp==0 and p.gold==138 and level_notices(received)==1,"retry grants missing XP and gold exactly once")
	check(session.travel("town") and session.sim.players[1].xp==0 and session.sim.players[1].gold==138 and level_notices(received)==1,"post-retry travel cannot repeat reward")
	close_session(session)

func ordinary_level_ups():
	var sim=Sim.new(1253);var p=sim.add_player(1,"처치 성장 검증")
	var enemy=sim.enemies.values()[0];enemy.xp=616;p.hp=1
	sim.kill(1,enemy)
	check(p.level==3 and p.xp==11 and Content.available_points(p)==2 and Progression.available(p)==6,"ordinary kill still processes multiple level thresholds")
	check(p.hp==p.max_hp and level_notices(sim.events)==2,"ordinary level-up still recalculates HP and emits each level")
	var before=sim.persistent(1).duplicate(true);sim.kill(1,enemy)
	check(sim.persistent(1)==before,"repeated kill does not regrant XP after extraction")

func force_gear(sim,kind:String):
	# Force existing categories through the real kill/item-generation path.
	# Probability tests remain in loot_v04; this fixture removes sampling luck.
	sim.loot_tables.tables[kind]=[
		{"key":"weapon","chance":1.0,"kind":"weapon","weapon":"sword","rarity":1},
		{"key":"head","chance":1.0,"kind":"armor","slot":"head","rarity":0},
		{"key":"accessory","chance":1.0,"kind":"accessory","slot":"accessory","rarity":2},
	]

func tutorial_loot():
	for cls in ["warrior","ranger","mage"]:
		for seed_value in range(8):
			var sim=Sim.new(53530+seed_value);var p=sim.add_player(1,"드랍 검증",{"schema_version":7,"class_id":cls})
			var existing=Equipment.make("head",1,1,"existing-locked","vigor",cls)
			check(Inventory.add_gear(p,existing),"existing level-10 gear fixture retained")
			var inventory=p.inventory.duplicate(true)
			for kind in World.DUNGEONS.forest.mobs:
				force_gear(sim,kind)
				var enemy=sim.enemies.values().filter(func(e):return e.kind==kind)[0]
				sim.kill(1,enemy)
			check(sim.drops.size()==15 and p.inventory==inventory,"five normal monsters generate gear without rewriting existing inventory")
			for drop in sim.drops.values():
				check(drop.item.tier==0 and drop.item.required_level==1 and Equipment.reason(p,drop.item).is_empty(),cls+" tutorial gear immediately wearable")
				check(drop.item.rarity=={"weapon":1,"head":0,"accessory":2}[drop.item.slot],"tutorial tier change preserves rolled rarity")
	for entry in [
		["forest",0,"goblin_captain",1,2],["forest",0,"warden",1,2],
		["cave",0,"beetle",1,2],["ruins",0,"clockwork",2,3],
		["forest",1,"shade",0,0],["forest",10,"warden",0,0],
		["cave",11,"beetle",1,1],["ruins",21,"frost_slime",2,2],
		["ruins",100,"sentinel",9,9],
	]:
		var sim=Sim.new(53539,entry[0],entry[1]);sim.add_player(1,"드랍 경계 검증")
		force_gear(sim,entry[2]);var enemies=sim.enemies.values().filter(func(e):return e.kind==entry[2])
		check(not enemies.is_empty(),"drop boundary enemy exists "+str(entry))
		if enemies.is_empty():continue
		sim.kill(1,enemies[0])
		check(sim.drops.size()==(4 if enemies[0].get("raid",false) else 3),"existing independent and extra raid drops retained")
		for drop in sim.drops.values():check(drop.item.tier>=entry[3] and drop.item.tier<=entry[4],"elite, boss, other terrain and abyss tiers unchanged "+str(entry))

func inn_action(sim,operation:String,extra:Dictionary={})->bool:
	var request=extra.duplicate(true);request.merge({"facility":"inn","operation":operation},true)
	return sim.action(1,"facility",JSON.stringify(request))

func inn_resupply():
	check(Operations.DEFAULT_INN_OPERATION=="resupply_small" and Operations.INN_RESUPPLY_TARGETS=={"resupply_small":5,"resupply":20},"UI default and both stock targets exposed")
	var sim=Sim.new(5353,"town");var p=sim.add_player(1,"보급 검증")
	p.pos=World.FACILITIES.inn.pos
	for entry in [[0,85,5],[2,55,5],[4,25,5],[5,10,5],[8,10,8],[20,10,20]]:
		p.potions=entry[0];p.gold=entry[1];p.hp=17;p.stamina=3;Inventory.initialize(p)
		var before=p.duplicate(true);var q=Quote.quote(p,"inn","resupply_small")
		check(p==before and q.reason.is_empty() and q.cost==entry[1] and q.target_potions==5,"small supply quote is read-only and exact "+str(entry))
		check(int(q.outputs.get("potion",0))==entry[2]-entry[0] and q.result.contains("물약 %d → %d"%[entry[0],entry[2]]),"quote never suggests discarding existing potions")
		check(inn_action(sim,"resupply_small") and p.potions==entry[2] and p.gold==0 and p.hp==p.max_hp and p.stamina==p.max_stamina,"actual small supply matches quoted stock, price and restoration")
		p.potions=entry[0];p.gold=entry[1]-1;p.hp=17;p.stamina=3;Inventory.initialize(p);before=p.duplicate(true)
		check(not Quote.quote(p,"inn","resupply_small").reason.is_empty() and not inn_action(sim,"resupply_small") and p==before,"one gold short rejects complete trade including healing")
	for entry in [[0,310],[5,235],[19,25],[20,10]]:
		p.potions=entry[0];p.gold=entry[1];p.hp=17;p.stamina=3;Inventory.initialize(p)
		var q=Quote.quote(p,"inn","resupply")
		check(q.cost==entry[1] and q.target_potions==20 and int(q.outputs.get("potion",0))==20-entry[0],"existing full supply quote unchanged")
		check(inn_action(sim,"resupply") and p.potions==20 and p.gold==0 and p.hp==p.max_hp and p.stamina==p.max_stamina,"existing 20-potion supply remains usable")
	p.gold=100;p.potions=0;p.hp=17;p.stamina=3;Inventory.initialize(p)
	for quantity in [-1,0,2,5,1.5,"1"]:
		var before=p.duplicate(true)
		check(not Quote.quote(p,"inn","resupply_small",{"quantity":quantity}).reason.is_empty() and not inn_action(sim,"resupply_small",{"quantity":quantity}) and p==before,"small supply rejects invalid batch quantity "+str(quantity))
	p.pos=sim.map.spawn;var before=p.duplicate(true)
	check(not inn_action(sim,"resupply_small") and p==before,"small supply retains physical inn proximity requirement")

func fill_bag(p:Dictionary,potions:int):
	p.inventory=[];p.equipment={};p.equipped="";p.bag_positions={};p.materials={};p.potions=potions
	Inventory.initialize(p)
	for index in range(Inventory.CAPACITY-(1 if potions>0 else 0)):
		check(Inventory.add_gear(p,Equipment.make("head",0,0,"supply-fill-%d"%index)),"fill isolated bag boundary")
	check(Inventory.bag_items(p).size()==Inventory.CAPACITY,"bag fixture is actually full")

func inn_bag_boundaries():
	var sim=Sim.new(5354,"town");var p=sim.add_player(1,"가방 보급 검증")
	p.pos=World.FACILITIES.inn.pos;p.gold=100;p.hp=17;p.stamina=3
	fill_bag(p,0);var before=p.duplicate(true)
	check(not Quote.quote(p,"inn","resupply_small").reason.is_empty() and not inn_action(sim,"resupply_small") and p==before,"full bag without potion stack rejects charge and restoration atomically")
	fill_bag(p,1)
	check(Quote.quote(p,"inn","resupply_small").reason.is_empty() and inn_action(sim,"resupply_small") and p.potions==5 and p.gold==30,"full bag with existing potion stack can replenish exactly")
	p.potions=8;p.gold=10;p.hp=17;p.stamina=3
	check(inn_action(sim,"resupply_small") and p.potions==8 and p.gold==0 and p.hp==p.max_hp,"full bag with surplus potions still allows rest without output space")
	var local=Local.new();var saved=sim.persistent(1);saved.world_seed=5354
	var path=folder.path_join("small-supply-save.json")
	check(local.write_save(saved,path),"small supply result saved")
	var parsed=local.parse_save(path)
	check(parsed!=null and parsed.potions==8 and parsed.gold==0 and parsed.inventory.size()==119,"small supply result survives existing save validation")
	local.free()

func run():
	folder=ProjectSettings.globalize_path("res://../runtime/progression-rewards-v053/"+str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(folder)
	tutorial_arrival();tutorial_boundaries();tutorial_save_failure();ordinary_level_ups();tutorial_loot();inn_resupply();inn_bag_boundaries()
	print("PROGRESSION_REWARDS_V053 checks=%d failures=%d"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
