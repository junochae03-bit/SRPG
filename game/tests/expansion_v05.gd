extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Content=preload("res://scripts/content.gd")
const Progression=preload("res://scripts/progression.gd")
const World=preload("res://scripts/world_catalog.gd")
const Inventory=preload("res://scripts/inventory_model.gd")
const Gear=preload("res://scripts/equipment_catalog.gd")
var checks=0
var failed=[]
func check(ok:bool,name:String):
	checks+=1
	if not ok:failed.append(name);push_error(name)
func _initialize():run.call_deferred()
func service(sim,p,facility,operation,extra={})->bool:
	p.pos=World.FACILITIES[facility].pos;extra=extra.duplicate();extra.merge({"facility":facility,"operation":operation})
	return sim.action(1,"facility",JSON.stringify(extra))
func run():
	for zone in World.DUNGEONS:
		var sim=Sim.new(701,zone);var p=sim.add_player(1,"검증");var map=sim.map
		check(sim.enemies.size()==23 and sim.enemies.values().filter(func(e):return e.boss).size()==1,"one boss, one elite and 21 mobs "+zone)
		check(sim.enemies.values().back().kind==World.DUNGEONS[zone].boss,"correct boss "+zone)
		var visited={};var queue=[Vector2i(map.spawn)];visited[queue[0]]=true
		while not queue.is_empty():
			var at=queue.pop_front()
			for off in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var next=at+off
				if map.walkable(next) and not visited.has(next):visited[next]=true;queue.append(next)
		check(visited.size()==map.floor_cells.size(),"all rooms reachable "+zone)
		check(Sim.new(701,zone).map.floor_cells==map.floor_cells,"deterministic dungeon "+zone)
		p.pos=Vector2(map.rooms[1]);sim.tick(.1)
		check(sim.enemies.values().all(func(e):return map.walkable(e.pos)),"enemy positions valid "+zone)
		var boss=sim.enemies.values().back();p.pos=boss.pos+Vector2(.3,.3);boss.hp=int(boss.max_hp*.4);sim.tick(.1)
		check(boss.phase==2,"boss enrage "+zone)
		var before=p.boss_kills;sim.combat.hit(p,boss,999999)
		check(boss.hp<=0 and p.boss_kills==before+1 and p.dungeon_clears[zone]==1,"boss defeat recorded "+zone)
		check(sim.drops.values().any(func(d):return d.item.category=="weapon" and d.item.rarity==2),"boss rare weapon guaranteed "+zone)
	for cls in ["warrior","ranger","mage"]:
		var list=Content.SKILLS[cls];check(list.size()==50,"50 nodes "+cls)
		check(list.filter(func(n):return n.effect=="active").size()==12,"12 active skills "+cls)
		var ids=[]
		for node in list:ids.append(node.id)
		for node in list:
			check(node.parents.all(func(id):return id in ids) and node.id not in node.parents,"valid web edges "+node.id)
			var sim=Sim.new(701);var p=sim.add_player(1,"검증");p.level=100;p.class_id=cls
			if not node.parents.is_empty():p.skill_ranks[node.parents[0]]=1
			check(sim.action(1,"invest",node.id),"invest available path "+node.id)
			check(p.skill_ranks[node.id]==1,"actual node rank "+node.id)
			if node.effect!="active":
				check(Content.skill_bonus(p,node.effect)>=float(node.value),"passive contributes "+node.id);continue
			check(sim.action(1,"bind_skill","skill_f:"+node.id),"bind learned active "+node.id)
			check(Content.active_node(p,"skill_f").id==node.id,"binding resolves "+node.id)
			p.pos=Vector2(sim.map.rooms[1]);p.aim=Vector2.RIGHT;p.hp=30;p.stamina=100
			for e in sim.enemies.values():e.hp=0
			var e=sim.enemies[1];e.hp=10000;e.max_hp=10000;e.pos=p.pos+Vector2(1,0)
			check(sim.action(1,"skill_f"),"cast active "+node.id)
			check(p.stamina<100 and not sim.events.is_empty(),"cast costs and effects "+node.id)
			check(not sim.action(1,"skill_f"),"skill cooldown enforced "+node.id)
			check(not sim.action(1,"bind_skill","skill_v:"+node.id) and not sim.action(1,"skill_f"),"rebind cannot bypass cooldown "+node.id)
			if node.get("mode","")=="heal":check(p.hp>30,"healing skill "+cls)
			elif node.get("mode","")=="barrier":check(p.barrier_time>0 and p.barrier_strength>0,"barrier skill "+cls)
			elif node.get("mode","")=="haste":check(p.haste_time>0,"haste skill "+cls)
	var sim=Sim.new(321);var p=sim.add_player(1,"성장");p.level=10
	check(Progression.available(p)==27,"retroactive stats 3 per level")
	var old_damage=sim.damage_for(p);check(sim.action(1,"stat","strength") and sim.damage_for(p)==old_damage+2,"strength changes melee damage")
	sim.recalculate(p);var hp=p.max_hp;check(sim.action(1,"stat","endurance") and p.defense==2 and p.magic_defense==2 and p.max_hp==hp,"endurance boosts both defenses")
	check(sim.action(1,"reset_stats") and Progression.available(p)==27,"town stats reset")
	check(not sim.action(1,"stat","forged"),"invalid stat rejected")
	check(Progression.xp_required(1)>60 and Progression.xp_required(10)>600 and Progression.xp_required(20)>Progression.xp_required(10)*2,"slower progressive XP")
	p.level=1;p.xp=0;p.pos=Vector2(sim.map.rooms[1]);var victim=sim.enemies[1]
	sim.kill(1,victim);check(p.level==1,"one enemy cannot level character")
	p.xp=Progression.xp_required(1)-1;victim.rewarded=false;sim.kill(1,victim);check(p.level==2 and Progression.available(p)==3,"level awards allocatable stats")
	sim=Sim.new(321,"town");p=sim.add_player(1,"시설");p.gold=5000;p.materials={"seed":100,"ore":100,"essence":10};Inventory.initialize(p)
	check(not sim.action(1,"attack") and sim.enemies.is_empty(),"safe independent town")
	for f in World.FACILITIES:check(sim.map.walkable(World.FACILITIES[f].pos),"facility entrance walkable "+f)
	for i in range(7):check(service(sim,p,"shop","buy",{"index":i}),"buy equipment family "+str(i))
	check(p.inventory.size()==7,"seven class equipment slots stocked")
	var first=p.inventory[0];Inventory.equip(p,first.id);var old=first.bonus
	check(service(sim,p,"smith","upgrade",{"item":first.id}),"blacksmith upgrade succeeds")
	first=Inventory.find_item(p,first.id);check(first.bonus==old+2 and first.upgrade==1,"upgrade actual stats")
	for i in range(4):check(service(sim,p,"smith","upgrade",{"item":first.id}),"upgrade to cap")
	check(not service(sim,p,"smith","upgrade",{"item":first.id}),"upgrade cap")
	check(not service(sim,p,"smith","reforge",{"item":first.id}),"normal gear cannot gain affix")
	Inventory.find_item(p,first.id).rarity=1
	check(service(sim,p,"smith","reforge",{"item":first.id}),"rare reforge actual affix")
	check(Inventory.find_item(p,first.id).affix!="none","reforge changes equipment")
	check(not service(sim,p,"shop","sell",{"item":first.id}),"equipped sale protected")
	var count=p.inventory.size();check(service(sim,p,"shop","sell",{"item":p.inventory[1].id}) and p.inventory.size()==count-1,"shop sale removes exactly one")
	var potions=p.potions;check(service(sim,p,"alchemy","potion") and p.potions==potions+3,"alchemy crafts potions")
	var essence=p.materials.essence;check(service(sim,p,"alchemy","essence") and p.materials.essence==essence+1,"alchemy synthesizes essence")
	p.hp=10;p.stamina=2;check(service(sim,p,"inn","rest") and p.hp==p.max_hp and p.stamina==p.max_stamina,"inn restores both resources")
	check(service(sim,p,"guild","accept",{"zone":"cave"}),"guild accepts contract")
	check(not service(sim,p,"guild","claim"),"incomplete guild cannot claim")
	p.guild_contract.progress=10;check(service(sim,p,"guild","claim") and p.guild_contract.is_empty(),"guild pays and clears")
	check(not service(sim,p,"guild","claim"),"guild reward cannot repeat")
	p.gold=0;var before=sim.persistent(1).duplicate(true)
	check(not service(sim,p,"shop","buy",{"index":0}) and sim.persistent(1)==before,"insufficient funds atomic")
	p.gold=100;p.potions=20;Inventory.initialize(p);before=sim.persistent(1).duplicate(true)
	check(not service(sim,p,"alchemy","potion") and sim.persistent(1)==before,"full potion stack atomic")
	check(not service(sim,p,"smith","upgrade",{"item":"@potion"}),"consumable cannot be upgraded")
	before=sim.persistent(1).duplicate(true)
	for id in ["@potion","@mat:seed","@mat:ore","@mat:essence"]:
		check(not service(sim,p,"shop","sell",{"item":id}) and sim.persistent(1)==before,"virtual stack cannot duplicate sale gold "+id)
	var battle=Sim.new(321,"forest");var fighter=battle.add_player(1,"행운 검증")
	var fortune=Gear.make("accessory",0,1,"fortune-test","fortune");Inventory.add_gear(fighter,fortune);Inventory.equip(fighter,fortune.id)
	fortune.upgrade=2;battle.recalculate(fighter);check(fighter.gear_stats.magic==3,"magic option applies after enhancement")
	var previous_gold=fighter.gold;var target=battle.enemies.values().back()
	battle.kill(1,target);check(fighter.gold-previous_gold==90,"stat option does not multiply currency")
	var names={}
	for job in Content.CLASSES:
		for type in Gear.SHOP_TYPES:
			for tier in range(10):names[Gear.make(type,tier,0,"test","none",job).name]=true
	check(names.size()==500,"200 job weapons and 300 family armor/accessory base names")
	var session=preload("res://scripts/local_session.gd").new();root.add_child(session);session.set_physics_process(false);session.save_directory=ProjectSettings.globalize_path("res://../runtime/v05-model/"+str(Time.get_ticks_usec()));session.start_game("저장",1)
	check(session.sim.map.zone=="forest","game starts in tutorial")
	session.sim.players[1].tutorial_done=true;session.sim.players[1].highest_floor=11;session.sim.players[1].cleared_floor=10;session.sim.players[1].level=10;session.travel("town")
	check(session.travel("cave") and session.sim.map.zone=="cave","travel to selected dungeon")
	p=session.sim.players[1];p.pos=Vector2(session.sim.map.rooms[1]);check(not session.travel("ruins"),"cannot change dungeon in combat field")
	check(session.act("return") and session.sim.map.zone=="town","R returns to town")
	p=session.sim.players[1];p.level=10;session.act("stat","endurance");session.save_game();var loaded=session.parse_save(session.save_path())
	check(loaded!=null and loaded.schema_version==6 and loaded.stats.endurance==1,"v5 stats saved and validated")
	session.disconnect_game();session.queue_free();await process_frame
	print("V05_TESTS checks=",checks," failures=",failed.size())
	quit(0 if failed.is_empty() else 1)
