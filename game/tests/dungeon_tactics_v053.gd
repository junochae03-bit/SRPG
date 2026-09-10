extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Content=preload("res://scripts/content.gd")
const Rules=preload("res://scripts/skill_build.gd")
const Attacks=preload("res://scripts/monster_attacks.gd")
const Equipment=preload("res://scripts/equipment_catalog.gd")
const Inventory=preload("res://scripts/inventory_model.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func learn(p:Dictionary,id:String,rank:int=1):
	var plan=Rules.path_plan(p,id)
	if not plan.ok:return
	p.skill_ranks=plan.player.skill_ranks;p.constellation_allocations=plan.player.constellation_allocations
	while Rules.rank(p,Rules.definition(id))<rank:
		var next=Rules.preview(p,id,Rules.rank(p,Rules.definition(id))+1)
		if not next.ok:break
		p.skill_ranks=next.player.skill_ranks;p.constellation_allocations=next.player.constellation_allocations
func fixture(floor_number:int,strategy:String,seed_value:int)->Dictionary:
	var sim=Sim.new(seed_value,"forest",floor_number)
	var p=sim.add_player(1,"전술 비교",{"schema_version":7,"class_id":"warrior","level":10,"creation_points":10,"stats":{"strength":20,"endurance":10,"technique":4,"agility":3,"magic":0},"tutorial_done":true,"skill_ranks":{},"constellation_allocations":{},"gold":300,"potions":5})
	var wanted=["warrior_fan","warrior_burst","blade_wave"] if strategy=="cleave" else ["warrior_fan","warrior_heal","warrior_barrier"]
	for id in wanted:learn(p,id)
	for id in wanted:learn(p,id,3)
	for n in Rules.nodes_for(p.class_id):
		if n.type=="original" and n.effect!="active":learn(p,n.id,3)
	var slot=0
	for id in wanted:
		if p.skill_ranks.get(id,0)>0:p.skill_loadout[Content.ACTIONS[slot]]=id;slot+=1
	for key in ["sword","head","chest","feet"]:
		var item=Equipment.make(key,0,1,"fixture-"+key,"none","warrior");Inventory.add_gear(p,item);Inventory.equip(p,item.id)
	sim.recalculate(p);p.hp=p.max_hp;p.stamina=p.max_stamina
	return {"sim":sim,"p":p}
func route(map,start:Vector2,goal:Vector2)->Array:
	var begin=Vector2i(roundi(start.x),roundi(start.y));var end=Vector2i(roundi(goal.x),roundi(goal.y))
	var queue=[begin];var parent={begin:begin};var at=0
	while at<queue.size():
		var cell=queue[at];at+=1
		if cell==end:break
		for offset in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			var next=cell+offset
			if map.floor_cells.has(next) and not parent.has(next):parent[next]=cell;queue.append(next)
	if not parent.has(end):return []
	var result=[];var cell=end
	while cell!=begin:result.push_front(Vector2(cell));cell=parent[cell]
	return result
func measure(floor_number:int,strategy:String,seed_value:int)->Dictionary:
	var f=fixture(floor_number,strategy,seed_value);var sim=f.sim;var p=f.p
	var row={"floor":floor_number,"layout":sim.map.layout_id,"strategy":strategy,"seed":seed_value,"level":p.level,"sp":Rules.spent_points(p),"legal":Rules.validate_build(p).ok,"skills":p.skill_ranks.duplicate(true),"loadout":p.skill_loadout.duplicate(true),"damage_out":0,"damage_in":0,"enemy_impacts":0,"casts":0,"dodges":0,"potions":0,"defeats":0,"distance":0.,"kills":0,"elapsed":0.}
	var path=[];var goal=Vector2.INF;var previous=p.pos
	for tick in range(3600):
		if tick%4==0:
			var enemies=sim.enemies.values().filter(func(e):return e.hp>0)
			enemies.sort_custom(func(a,b):return p.pos.distance_squared_to(a.pos)<p.pos.distance_squared_to(b.pos))
			if enemies.is_empty():break
			var enemy=enemies[0];var aim=p.pos.direction_to(enemy.pos);var direction=Vector2.ZERO
			if p.pos.distance_to(enemy.pos)>1.5 or not sim.map.line_clear(p.pos,enemy.pos):
				if path.is_empty() or goal.distance_to(enemy.pos)>1.5 or not sim.map.line_clear(p.pos,path[0]) or p.pos.distance_to(path[0])>2.3:path=route(sim.map,p.pos,enemy.pos);goal=enemy.pos
				while not path.is_empty() and p.pos.distance_to(path[0])<.35:path.pop_front()
				if not path.is_empty():direction=p.pos.direction_to(path[0])
			var threatened=enemies.any(func(e):return e.windup>0 and e.get("attack_areas",[]).any(func(z):return Attacks.contains(z,p.pos)))
			if threatened:direction=aim.orthogonal()
			sim.set_input(1,direction,aim)
			if threatened and sim.action(1,"dodge"):row.dodges+=1
			if p.hp<p.max_hp*.4 and sim.action(1,"potion"):row.potions+=1
			if p.pos.distance_to(enemy.pos)<7 and sim.map.line_clear(p.pos,enemy.pos):
				for action in p.skill_loadout:
					var n=Content.active_node(p,action)
					if n.get("mode","")=="heal" and p.hp>p.max_hp*.7:continue
					if p.skill_cooldowns.get(n.id,0)<=0 and sim.action(1,action):row.casts+=1
				if p.attack_cd<=0:sim.action(1,"attack")
			sim.action(1,"interact")
		sim.tick(1./30.)
		row.distance+=p.pos.distance_to(previous);previous=p.pos;row.elapsed=(tick+1)/30.
		for e in sim.events:
			if e.type=="damage":row["damage_out" if e.get("enemy",false) else "damage_in"]+=e.amount
			if e.type=="monster_attack":row.enemy_impacts+=1
			if e.type=="notice" and str(e.get("text","")).contains("쓰러졌"):row.defeats+=1
		sim.events.clear()
		if p.kills>=12:break
	row.kills=p.kills;row["ending_hp"]=p.hp
	check(row.legal and row.sp==9,"equal legal starting budget")
	check(row.distance>3 and row.damage_out>0 and row.enemy_impacts>0,"AI and receiving damage remain enabled")
	return row
func run():
	Content.initialize_jobs();var rows=[]
	for floor_number in [6,7,8]:
		for seed_value in [123,456,789]:
			for strategy in ["cleave","guard"]:rows.append(measure(floor_number,strategy,seed_value))
	var path=ProjectSettings.globalize_path("res://../artifacts/dungeon-tactics-v053.json")
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"scope":"LV10/9SP, identical 37 stats and four tier0 rare items, 5 potions, 300G. Normal AI, damage, collision, cooldowns, deaths, rewards. 120 simulated seconds or 12 kills. Automated equal-input-policy comparison, not human win rate or elapsed playtime.","rows":rows},"  "))
	print("DUNGEON_TACTICS_V053 checks=%d failures=%d scenarios=%d"%[checks,failures.size(),rows.size()]);quit(0 if failures.is_empty() else 1)
