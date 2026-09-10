extends RefCounted
# Town-only practice state. No save fields, rewards, AI or new combo mechanic.
# Avoid preloading Content/Dungeon here: both simulation and town geometry use it.
const AREA=Rect2(29,24,15,16)
const POSITION=Vector2(37,30)
const HEALTH=1000000000
const IDLE_RESET_SECONDS=10.0
static func expire_measurement(p:Dictionary,clock:float):
	var stats=p.get("training_stats",{})
	if stats.get("hits",0)>0 and clock-float(stats.last_hit)>=IDLE_RESET_SECONDS:
		p["training_stats"]=blank()
static func contains(pos:Vector2)->bool:return AREA.has_point(pos)
static func can_practice(sim,p:Dictionary)->bool:return sim.map.zone=="town" and contains(p.pos)
static func spawn(sim)->Dictionary:
	var e=sim.spawn_enemy("warden",POSITION,1,true)
	e.merge({"training":true,"name":"거대 훈련 허수아비","hp":HEALTH,"max_hp":HEALTH,"pos":POSITION,"home":POSITION,"raid":false,"guardian":false,"xp":0,"gold":0},true)
	return e
static func blank()->Dictionary:
	return {"total_damage":0,"hits":0,"criticals":0,"first_hit":-1.,"last_hit":-1.,"last_skill":"—","last_skill_id":"","stagger_breaks":0}
static func summary(p:Dictionary)->Dictionary:
	var result=p.get("training_stats",blank()).duplicate(true)
	var elapsed=maxf(1.,float(result.last_hit)-float(result.first_hit)) if result.hits>0 else 0.
	result["elapsed"]=elapsed
	result["dps"]=float(result.total_damage)/elapsed if elapsed>0 else 0.
	return result
static func record(sim,p:Dictionary,e:Dictionary,amount:int,critical:bool,context:Dictionary={}):
	if not e.get("training",false):return
	e.hp=e.max_hp;e.pos=POSITION
	if amount<=0 or not can_practice(sim,p):return
	expire_measurement(p,sim.clock)
	if not p.has("training_stats"):p["training_stats"]=blank()
	var stats=p.training_stats
	stats.total_damage+=amount;stats.hits+=1;stats.criticals+=1 if critical else 0
	if float(stats.first_hit)<0:stats.first_hit=sim.clock
	stats.last_hit=sim.clock
	var source=str(context.get("budget",{}).get("source",""))
	stats.last_skill_id=source
	stats.last_skill={"basic":"기본 공격","heavy":"강공격"}.get(source,"지속 피해")
	for node in sim.Content.SKILLS.get(p.class_id,[]):
		if node.id==source:stats.last_skill=node.name;break
	stats.stagger_breaks=int(e.get("stagger",{}).get("breaks",0))
static func tick(sim,e:Dictionary,delta:float):
	e.hp=e.max_hp;e.pos=POSITION;e.home=POSITION;e.windup=0.;e.attack_motion=0.;e.cooldown=1.;e.ability_cd=4.
	e.erase("attack_areas")
	for key in ["slow_time","stun_time"]:e[key]=maxf(0.,float(e.get(key,0))-delta)
	# Ready/down/immunity transitions are normal boss stagger transitions. With
	# raid=false no threshold check or retaliatory punishment can be generated.
	sim.BossStagger.tick(sim,e,delta)
static func reset(sim,p:Dictionary)->bool:
	if not can_practice(sim,p):return false
	sim.clear_build_runtime(p)
	p.attack_cd=0.;p.dodge_cd=0.;p.nova_cd=0.;p.stamina=p.max_stamina
	p["training_stats"]=blank()
	for enemy in sim.enemies.values():
		if enemy.get("training",false):sim.BossStagger.reset(sim,enemy);enemy.hp=HEALTH;enemy.max_hp=HEALTH;enemy.pos=POSITION;enemy.home=POSITION
	sim.notice(p.id,"훈련 기록과 기술 대기시간을 초기화했습니다.")
	return true
