extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const C=preload("res://scripts/content.gd")
const R=preload("res://scripts/skill_build.gd")
const Benchmark=preload("res://tests/job_benchmark.gd")
var failures=0
func _initialize():run.call_deferred()
static func invest(p:Dictionary,id:String,target:int=1):
	var path=R.path_plan(p,id)
	if not path.ok:return
	p.skill_ranks=path.player.skill_ranks;p.constellation_allocations=path.player.constellation_allocations
	while R.rank(p,R.definition(id))<target:
		var next=R.preview(p,id,R.rank(p,R.definition(id))+1)
		if not next.ok:break
		p.skill_ranks=next.player.skill_ranks;p.constellation_allocations=next.player.constellation_allocations
static func prepare(sim,job:String,strategy:String)->Dictionary:
	var p=sim.add_player(1,"스킬트리 측정");p.class_id=job;p.level=60 if C.CLASSES[job].has("base") and not C.CLASSES[job].get("starter",false) else 30
	var budget=(p.level-1)*3;var primary=floori(budget*.55);var endurance=floori(budget*.25);var technique=floori(budget*.12)
	p.stats={"strength":0,"endurance":endurance,"technique":technique,"agility":budget-primary-endurance-technique,"magic":0};p.stats["magic" if preload("res://scripts/progression.gd").magic_user(p) else "strength"]=primary
	p.skill_ranks={};p.constellation_allocations={};p.skill_loadout={}
	var actives=C.SKILLS[job].filter(func(n):return n.effect=="active")
	var equipped=[]
	if Benchmark.LOADOUTS.has(job):
		for index in Benchmark.LOADOUTS[job]:equipped.append(job+"_a%02d"%(index+1))
	else:
		for n in actives:equipped.append(n.id)
	for id in equipped.slice(0,6):invest(p,id)
	var usable=equipped.filter(func(id):return p.skill_ranks.get(id,0)>0).slice(0,6)
	for i in range(usable.size()):p.skill_loadout[C.ACTIONS[i]]=usable[i]
	if strategy=="character":
		invest(p,job+":star:3:key");invest(p,job+":star:4:n1");invest(p,job+":star:3:n1")
	elif strategy=="stat":
		for n in R.nodes_for(job):
			if n.type=="minor":invest(p,n.id)
	elif strategy=="module":
		for id in usable:
			if not R.definition(id+"_upgrade").is_empty():invest(p,id+"_upgrade")
	for rank in range(1,6):
		for id in usable:invest(p,id,mini(rank,int(R.definition(id).max_rank)))
	for rank in range(1,6):
		for n in R.nodes_for(job):
			if n.type=="original" and n.effect not in ["active","upgrade"]:invest(p,n.id,mini(rank,int(n.max_rank)))
	for n in R.nodes_for(job):
		if n.type=="minor":invest(p,n.id)
	sim.recalculate(p);sim.combat.jobs.reset(p);sim.combat.constellation.reset(p);p.stamina=p.max_stamina
	return p
static func measure(job:String,strategy:String,count:int,seed_value:int)->Dictionary:
	var sim=Sim.new(seed_value);sim.enemies.clear();var p=prepare(sim,job,strategy)
	var valid=R.validate_build(p);var origin=Vector2(sim.map.rooms[1]);p.pos=origin;p.aim=Vector2.RIGHT
	var positions=[]
	for i in range(count):
		var pos=origin+Vector2(1.1+(i%2)*.45,(i/2-1)*.45 if count>1 else 0.);positions.append(pos)
		var e=sim.spawn_enemy("shade",pos,p.level,count==1);e.hp=10000000;e.max_hp=e.hp
	var casts=0;var minimum=p.stamina;var cursor=0;var starved=0
	for tick in range(750):
		sim.clock+=.04;p.pos=origin;p.aim=Vector2.RIGHT;p.attack_cd=maxf(0,p.attack_cd-.04)
		for i in range(count):sim.enemies[i+1].pos=positions[i]
		for offset in range(6):
			var index=(cursor+offset)%6;var node=C.active_node(p,C.ACTIONS[index])
			if node.is_empty():continue
			if node.get("mode","")=="summon" and p.job_state.pets.any(func(pet):return pet.source==node.id):continue
			if node.get("mode","") in ["heal","regen"] and p.hp>p.max_hp*.85:continue
			if sim.action(1,C.ACTIONS[index]):casts+=1;cursor=(index+1)%6;break
		sim.action(1,"attack");minimum=minf(minimum,p.stamina)
		if p.stamina<5:starved+=1
		sim.combat.tick_player(p,.04);sim.combat.tick_projectiles(.04);sim.combat.skills.tick(.04)
		for enemy in sim.enemies.values():preload("res://scripts/boss_stagger.gd").tick(sim,enemy,.04)
		sim.events.clear()
	var damage=0
	for e in sim.enemies.values():damage+=10000000-e.hp
	return {"class_id":job,"strategy":strategy,"targets":count,"seed":seed_value,"level":p.level,"sp":R.spent_points(p),"available":R.available_points(p),"legal":valid.ok,"reason":valid.reason,"dps":snappedf(damage/30.,.1),"casts":casts,"minimum_stamina":snappedf(minimum,.1),"starved_seconds":snappedf(starved*.04,.01),"max_hp":p.max_hp,"defense":p.defense,"skill_ranks":p.skill_ranks,"constellation_allocations":p.constellation_allocations,"loadout":p.skill_loadout}
func run():
	C.initialize_jobs();var rows=[]
	for job in C.CLASSES:
		for strategy in ["active","module","character","stat"]:
			for count in [1,5]:
				for seed_value in [123,456]:
					var row=measure(job,strategy,count,seed_value);rows.append(row)
					if not row.legal or row.available!=0 or row.dps<=0:failures+=1;push_error("비교 빌드 오류: "+JSON.stringify(row))
	var suffix="current"
	if not OS.get_cmdline_user_args().is_empty():suffix=OS.get_cmdline_user_args()[0]
	var path=ProjectSettings.globalize_path("res://../artifacts/tree-balance-"+suffix+".json")
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"scenario":"동일 직업·장비·능력치·SP, 기본직 LV30/29SP·전직 LV60/59SP, 30초, 단일 보스/일반 5대상, 시드 123·456. 실제 쿨타임·기력·자원·별자리 지연타격. 적 AI·피격·회피 없음, 위치 고정. 전투 승률 측정이 아님.","samples":rows},"  "))
	print("TREE_BALANCE_BENCHMARK checks=",rows.size()," failures=",failures);quit(0 if failures==0 else 1)
