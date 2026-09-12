extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Content=preload("res://scripts/content.gd")
const Stagger=preload("res://scripts/boss_stagger.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func close(a:float,b:float)->bool:return absf(a-b)<.015
func fixture(job:String="warrior")->Dictionary:
	var sim=Sim.new(177,"forest",10);sim.enemies.clear()
	var p=sim.add_player(1,"무력화 검사");p.class_id=job;p.level=100;p.stats={"technique":0};p.skill_ranks={};p.skill_loadout={}
	for n in Content.SKILLS[job]:
		if n.effect=="active":p.skill_ranks[n.id]=1
	sim.recalculate(p);sim.combat.jobs.reset(p);p.stamina=10000;p.max_stamina=10000
	p.pos=Vector2(sim.map.rooms[1]);p.aim=Vector2.RIGHT
	var e=sim.spawn_enemy("warden",p.pos+Vector2(1.2,0),100,true);e.hp=10000000;e.max_hp=e.hp;e.raid=false;e.stagger.max_value=1000000.
	return {"sim":sim,"p":p,"e":e,"origin":p.pos}
func node_for(job:String,mode:String)->Dictionary:
	for n in Content.SKILLS[job]:
		if n.effect=="active" and Stagger.skill_profile(n,1).mode==mode:return n
	check(false,"missing fixture mode "+job+" "+mode);return {}
func cast(f:Dictionary,node:Dictionary,rank:int=1)->bool:
	if node.is_empty():return false
	f.p.skill_ranks[node.id]=rank;f.p.skill_loadout[Content.ACTIONS[0]]=node.id
	return f.sim.action(1,Content.ACTIONS[0])
func advance(f:Dictionary,seconds:float,aim:Vector2=Vector2.RIGHT):
	for i in range(ceili(seconds/.04)):
		f.sim.clock+=.04;f.p.pos=f.origin;f.p.aim=aim
		f.sim.combat.tick_player(f.p,.04);f.sim.combat.tick_projectiles(.04);f.sim.combat.skills.tick(.04)
func total(f:Dictionary)->float:
	var value=0.
	for event in f.sim.events:
		if event.type=="stagger_damage":value+=event.amount
	return value
func run():
	Content.initialize_jobs()
	var node=node_for("breaker","charge")
	var a=Stagger.skill_profile(node,1);var b=Stagger.skill_profile(node,3,{"stats":{"technique":30},"gear_stats":{"technique":30}})
	check(a.value>0 and b.base>a.base and close(b.multiplier,1.30),"rank and total TECH including gear improve distinct stagger")
	check(close(b.value,b.base*1.3),"shared profile exact TECH formula")
	check(Stagger.skill_profile(node,0).value==0,"unlearned skill has no stagger")
	for job in Content.CLASSES:
		var rejected=fixture(job);var player=rejected.p;var battle=rejected.sim.combat
		var reserved=Stagger.context(Stagger.basic_token(false,0,rejected.sim.clock));battle.stagger_context=reserved
		var stamina=player.stamina;var cooldowns=player.skill_cooldowns.duplicate(true)
		check(not rejected.sim.action(1,"skill_q"),"empty slot safely rejected "+job)
		player.skill_loadout.skill_q="removed_skill"
		check(not rejected.sim.action(1,"skill_q"),"unknown assigned skill safely rejected "+job)
		var unlearned=Content.SKILLS[job].filter(func(n):return n.effect=="active")[0]
		player.skill_loadout.skill_q=unlearned.id;player.skill_ranks[unlearned.id]=0
		check(not rejected.sim.action(1,"skill_q"),"assigned unlearned skill safely rejected "+job)
		check(not battle.skills.cast(player,"ability"),"invalid active action safely rejected "+job)
		check(player.stamina==stamina and player.skill_cooldowns==cooldowns and battle.stagger_context==reserved and total(rejected)==0 and not player.has("casting_vfx"),"rejected skill preserves resources and surrounding attribution "+job)
	for job in Content.SKILLS:
		for n in Content.SKILLS[job]:
			var first=Stagger.skill_profile(n,1);var last=Stagger.skill_profile(n,Content.max_rank(n))
			check(is_finite(first.value) and first.value>=0 and last.value>=first.value,"valid shared profile "+n.id)
			if n.effect!="active":check(first.value==0,"passive/upgrade cannot masquerade as a hit "+n.id)
			elif job in ["warrior","ranger","mage"]:check(first.mode==preload("res://scripts/skill_scaling.gd").profile(n,1).mode,"legacy mode matches actual skill dispatcher "+n.id)
	var f=fixture();var p=f.p;var e=f.e;var sim=f.sim
	check(sim.action(1,"attack") and close(total(f),7.),"real basic hit contributes seven")
	p.attack_cd=0;p.stats.technique=999;check(sim.action(1,"attack") and close(total(f),14.),"TECH never amplifies basic")
	p.attack_cd=0;check(sim.action(1,"heavy_begin"),"heavy charge begins");p.charge_time=.9
	check(sim.action(1,"heavy") and close(total(f),34.),"full heavy contributes twenty independently")
	p.attack_cd=0;p.aim=Vector2.LEFT;sim.action(1,"attack");check(close(total(f),34.),"swing miss earns no stagger")
	var harmless=sim.spawn_enemy("shade",p.pos+Vector2.RIGHT,1,false)
	sim.combat.hit(p,harmless,1,null,Stagger.context(Stagger.basic_token(false,0,sim.clock)))
	check(not harmless.has("stagger"),"ordinary enemy uses ordinary stun only")
	for pair in [["warrior","spin"],["ranger","rain"],["mage","thunder"],["infighter","barrage"],["hunter","trap_bleed"],["thief","bleed"]]:
		f=fixture(pair[0]);node=node_for(pair[0],pair[1]);var expected=Stagger.skill_profile(node,1,f.p).value
		if pair[1]=="thunder":f.e.pos=f.p.pos+Vector2(4,0)
		check(cast(f,node),"actual cast "+str(pair));advance(f,8.)
		check(total(f)>0 and total(f)<=expected+.015,"multi/DOT cast total capped "+str(pair)+" got "+str(total(f)))
		if pair[1] in ["spin","thunder","barrage","trap_bleed","bleed"]:check(close(total(f),expected),"all real pulses add to advertised budget "+str(pair)+" got "+str(total(f)))
		check(f.sim.combat.stagger_context.is_empty(),"synchronous cast scope restored "+str(pair))
	f=fixture("sniper");node=node_for("sniper","shot");f.e.pos=f.p.pos+Vector2(4,0);var expected=Stagger.skill_profile(node,1,f.p).value
	check(cast(f,node) and close(total(f),0.),"projectile cast does not stagger before impact")
	f.p.stats.technique=900;advance(f,3.)
	check(close(total(f),expected),"projectile actual impact retains cast TECH snapshot")
	f=fixture("sniper");node=node_for("sniper","shot");f.p.aim=Vector2.LEFT
	check(cast(f,node),"miss projectile cast accepted");advance(f,2.,Vector2.LEFT);check(close(total(f),0.),"miss projectile gives zero")
	f=fixture("warrior");node=node_for("warrior","wave");f.p.skill_loadout.skill_q=node.id
	check(f.sim.action(1,"nova"),"legacy nova action resolves current Q skill")
	advance(f,1.);check(close(total(f),Stagger.skill_profile(node,1,f.p).value),"legacy nova alias retains real learned skill attribution")
	f=fixture("breaker");node=node_for("breaker","charge");expected=Stagger.skill_profile(node,5,f.p).value
	check(Content.max_rank(node)==5 and cast(f,node,5),"rank five charge dispatch")
	f.p.stats.technique=999;f.p.gear_stats.technique=999;advance(f,6.)
	check(close(total(f),expected),"rank five cast snapshot matches shared UI and DB value before later stat changes")
	f=fixture("summoner");node=node_for("summoner","summon");expected=Stagger.skill_profile(node,1,f.p).value
	check(cast(f,node),"summon real cast");advance(f,8.)
	check(close(total(f),0.),"manifestation never attacks without player input")
	for i in range(8):
		f.p.attack_cd=0. # This fixture advances combat components without the world cooldown loop.
		check(f.sim.action(1,"attack"),"player basic attack triggers manifestation");advance(f,1.2)
	var summon_total=0.
	for event in f.sim.events:
		if event.type=="stagger_damage" and event.source==node.id:summon_total+=event.amount
	check(close(summon_total,expected),"player-triggered manifestation respects six-strike summon budget")
	f=fixture("healer");node=node_for("healer","heal");f.p.hp=1
	check(cast(f,node),"heal cast works");advance(f,1.);check(close(total(f),0.),"healing near boss cannot grant phantom stagger")
	f=fixture("breaker");node=node_for("breaker","charge");check(cast(f,node),"interruptible cast starts")
	f.sim.action(1,"cancel_charge");advance(f,4.);check(close(total(f),0.),"cancelled cast consumes no stagger budget")
	f=fixture("breaker");node=node_for("breaker","parry_counter");check(cast(f,node),"counter stance begins")
	advance(f,.04);check(close(total(f),0.),"counter preparation has no phantom hit")
	f.e.stagger.max_value=Stagger.skill_profile(node,1,f.p).value
	var strike=f.sim.monster_attacks.area("circle",f.e.pos,f.p.pos,1.)
	f.e.attack_areas=[strike,strike.duplicate(true)]
	f.sim.monster_attacks.release(f.e)
	check(close(total(f),Stagger.skill_profile(node,1,f.p).value),"actual successful parry consumes counter skill budget")
	check(f.e.stagger.state=="down" and f.p.hp==f.p.max_hp and f.sim.events.filter(func(ev):return ev.type=="monster_attack").size()==1,"mid-release counter break cancels later same-frame hits")
	for job in Content.CLASSES:
		f=fixture(job);f.e.raid=true;f.e.stagger.check_max=85.;f.e.hp=f.e.max_hp*.69
		var elapsed=0.
		while elapsed<12. and f.e.stagger.state!="down":
			f.p.pos=f.origin;f.p.aim=Vector2.RIGHT
			f.sim.action(1,"attack");f.sim.tick(.04);elapsed+=.04
		check(f.e.stagger.state=="down" and elapsed<12.,"LV100 solo check attainable with actual baseline cooldowns "+job+" "+str(elapsed))
	f=fixture();e=f.e;sim=f.sim;p=f.p;e.stagger.max_value=7.;e.windup=1.;e.attack_areas=[sim.monster_attacks.area("circle",e.pos,e.pos,2.)]
	sim.monster_attacks.zones=[{"enemy":e.id,"timer":1.}]
	sim.action(1,"attack")
	check(e.stagger.state=="down" and e.windup==0 and not e.has("attack_areas") and sim.monster_attacks.zones.is_empty(),"break cancels queued and winding attacks")
	var hp=e.hp;sim.combat.hit(p,e,100);check(close(hp-e.hp,120.),"down creates twenty percent damage opportunity")
	var before=e.stagger.duplicate(true);sim.tick(0);check(e.stagger==before,"zero elapsed tick freezes stagger")
	Stagger.tick(sim,e,6.);check(e.stagger.state=="immune" and close(e.stagger.time_left,60.),"six second down transitions to sixty second lock")
	sim.combat.hit(p,e,1,null,Stagger.context(Stagger.basic_token(true,1,sim.clock)));check(e.stagger.value==0,"no chain lock during immunity")
	Stagger.tick(sim,e,59.);check(e.stagger.state=="immune","lock remains throughout first fifty nine seconds")
	Stagger.tick(sim,e,1.);check(e.stagger.state=="ready","sixty second immunity ends")
	f=fixture();e=f.e;p=f.p;sim=f.sim;e.raid=true;e.hp=e.max_hp*.69;sim.action(1,"attack")
	check(e.stagger.state=="check" and e.stagger.checks_done==[0] and close(e.stagger.check_value,7.),"seventy percent triggers timed check and attributes triggering hit")
	for i in range(12):p.attack_cd=0;sim.action(1,"attack")
	check(e.stagger.state=="down" and e.stagger.breaks==1,"solo baseline attacks can complete check")
	Stagger.tick(sim,e,6.);Stagger.tick(sim,e,60.);Stagger.tick(sim,e,.01)
	check(e.stagger.state=="ready","same HP threshold is not repeatedly triggered")
	e.hp=e.max_hp*.39;Stagger.tick(sim,e,.01)
	check(e.stagger.state=="check" and e.stagger.checks_done==[0,1],"forty percent independent second check")
	Stagger.tick(sim,e,12.)
	check(e.stagger.state=="immune" and close(e.windup,1.8) and e.attack_areas.size()==1,"failure schedules readable telegraphed punishment")
	var zone=e.attack_areas[0];p.hp=p.max_hp;e.damage=p.max_hp*10.;var outside=e.pos+Vector2(4,0)
	check(not sim.monster_attacks.contains(zone,outside),"failure has safe space outside circle")
	p.pos=e.pos;p.invulnerable=0;hp=p.hp;sim.monster_attacks.damage(e,p,zone)
	check(p.hp>0 and hp-p.hp<=roundi(p.max_hp*.70),"failure never imposes a full-health one-shot")
	p.hp=p.max_hp;p.invulnerable=.2;sim.monster_attacks.damage(e,p,zone);check(p.hp==p.max_hp,"failure punishment can be dodged")
	f=fixture();e=f.e;sim=f.sim;p=f.p;e.raid=true;e.hp=e.max_hp*.65;sim.action(1,"attack");sim.clock=1.;p.pos=sim.map.spawn
	Stagger.tick(sim,e,5.1)
	check(e.hp==e.max_hp and e.stagger.state=="ready" and e.stagger.checks_done.is_empty(),"disengagement resets encounter and threshold history")
	p.pos=f.origin;e.hp=e.max_hp*.6;p.attack_cd=0;sim.action(1,"attack")
	check(e.stagger.state=="check" and e.stagger.checks_done==[0],"fresh reentry can trigger its own first check")
	var old=Stagger.context(Stagger.token(node_for("mage","thunder"),1,p,sim.clock))
	sim.clock=2.;p.pos=sim.map.spawn;sim.reset_after_defeat(1)
	check(e.hp==e.max_hp and e.stagger.value==0 and e.stagger.checks_done.is_empty(),"defeat resets boss check and HP")
	p.pos=f.origin;hp=e.hp;sim.combat.hit(p,e,10,null,old)
	check(e.hp==hp and e.stagger.value==0,"late pre-reset spell cannot damage or refill encounter")
	e.stun_time=8.;sim.tick(.02);check(e.stun_time==0,"raid keeps ordinary stun immunity")
	print("BOSS_STAGGER_V03 "+("PASS" if failures.is_empty() else "FAIL")+" checks="+str(checks)+" failures="+str(failures.size()))
	quit(0 if failures.is_empty() else 1)
