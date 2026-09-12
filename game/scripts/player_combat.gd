extends RefCounted
const Content=preload("res://scripts/content.gd")
const Inventory=preload("res://scripts/inventory_model.gd")
const BossStagger=preload("res://scripts/boss_stagger.gd")
const HitGeometry=preload("res://scripts/enemy_hit_geometry.gd")
var sim_ref:WeakRef
var sim:
	get:return sim_ref.get_ref()
var projectiles:Array=[]
var skills
var jobs
var constellation
var stagger_context:Dictionary={}
func _init(owner_sim):
	sim_ref=weakref(owner_sim)
	jobs=preload("res://scripts/job_combat.gd").new(self)
	skills=preload("res://scripts/active_skills.gd").new(self)
	constellation=preload("res://scripts/constellation_effects.gd").new(self)

func weapon_type(p:Dictionary)->String:
	if Content.job(p):return Content.CLASSES[p.class_id].weapon
	return Inventory.find_item(p,p.equipped).get("weapon_type",Content.CLASSES[p.class_id].weapon)

func initialize(p:Dictionary):
	jobs.reset(p)
	constellation.reset(p)
	p.merge({"sprint":false,"dodge_cd":0.0,"dodge_time":0.0,"dodge_dir":Vector2.ZERO,"invulnerable":0.0,"charge_time":-1.0})
	p.merge({"skill_f_cd":0.0,"skill_v_cd":0.0,"skill_c_cd":0.0,"motion":"idle","motion_time":0.0,"motion_duration":0.4,"hurt_time":0.0})
	p.merge({"skill_cooldowns":{},"barrier_time":0.0,"barrier_strength":0.0,"haste_time":0.0,"regen_fraction":0.0,"combat_time":0.0,"enemy_slow_time":0.0})
	p.motion_aim=p.get("aim",Vector2.RIGHT);p.motion_aim_motion=""

func tick_player(p:Dictionary,delta:float):
	var dodge_step=minf(maxf(0,p.dodge_time),delta)
	preload("res://scripts/training_ground.gd").expire_measurement(p,sim.clock)
	constellation.tick_player(p,delta)
	jobs.tick(p,delta)
	for key in ["dodge_cd","dodge_time","invulnerable","skill_f_cd","skill_v_cd","skill_c_cd","motion_time","hurt_time"]:p[key]=maxf(0,p[key]-delta)
	if p.motion_time<=0 or p.dodge_time>0 or p.hurt_time>0 or p.get("down_time",0)>0:p.motion_aim_motion=""
	for key in ["barrier_time","haste_time","combat_time","enemy_slow_time"]:p[key]=maxf(0,p[key]-delta)
	for key in p.skill_cooldowns:p.skill_cooldowns[key]=maxf(0,p.skill_cooldowns[key]-delta)
	for action in Content.ACTIONS:p[action+"_cd"]=p.skill_cooldowns.get(Content.active_node(p,action).get("id",""),0)
	if p.combat_time<=0:
		p.regen_fraction+=Content.skill_bonus(p,"health_regen")*delta
		if p.regen_fraction>=1:p.hp=mini(p.max_hp,p.hp+int(p.regen_fraction));p.regen_fraction=fposmod(p.regen_fraction,1)
	if p.charge_time>=0:p.charge_time=minf(0.9,p.charge_time+delta)
	var speed=(sim.balance.player.speed+Content.skill_bonus(p,"speed"))*preload("res://scripts/progression.gd").move_speed(p)
	speed*=1.+float(constellation.values(p).get("move_speed",0))
	if p.haste_time>0:speed*=1+p.get("haste_speed",.25)
	if p.enemy_slow_time>0:speed*=.65
	if p.has("job_state"):
		speed*=1+jobs.value(p,"speed")
		if not p.job_state.casting.is_empty():speed*=.2+(jobs.passive(p,4)*.04 if p.class_id=="sniper" else 0)
		if p.job_state.get("channel",0)>0:speed*=.25 if p.skill_ranks.get("infighter_a01_upgrade",0)>0 and p.job_state.rush>=10 else 0.
		if jobs.value(p,"stand")>0:speed=0.
		if p.job_state.get("lock",0)>0 and p.job_state.get("channel",0)<=0:speed*=.35
	if dodge_step>0:
		# Sweep long/slow frames in short collision-checked steps, including the final fraction.
		var displacement:Vector2=p.dodge_dir*p.get("dash_speed",14.5)*dodge_step
		var steps=maxi(1,ceili(displacement.length()/.18))
		for i in range(steps):p.pos=sim.map.move(p.pos,displacement/steps)
	elif p.sprint and p.dir.length()>0.1 and p.stamina>0 and p.charge_time<0:
		p.pos=sim.map.move(p.pos,p.dir*speed*1.65*delta)
		p.stamina=maxf(0,p.stamina-maxf(5,23-Content.skill_bonus(p,"sprint_discount"))*delta)
	else:
		p.pos=sim.map.move(p.pos,p.dir*speed*(0.4 if p.charge_time>=0 else 1.0)*delta)
		if p.charge_time<0:p.stamina=minf(p.max_stamina,p.stamina+(18+Content.skill_bonus(p,"stamina_regen"))*delta)

func act(p:Dictionary,kind:String)->bool:
	if kind=="card_next":return jobs.select_card(p)
	if kind=="nova":kind="skill_q"
	if Content.job(p):return jobs.act(p,kind)
	if kind in Content.ACTIONS:return skills.cast(p,kind)
	if kind=="dodge":
		var cost=maxf(5,25-Content.skill_bonus(p,"dodge_discount"))
		if p.dodge_cd>0 or p.stamina<cost:return false
		p.stamina-=cost;p.dodge_cd=0.8;p.dodge_time=0.26;p.dash_speed=14.5;p.invulnerable=0.24;p.charge_time=-1.0
		p.invulnerable+=Content.skill_bonus(p,"dodge_duration")
		p.dodge_dir=p.dir.normalized() if p.dir.length()>0.1 else p.aim.normalized()
		if p.dodge_dir==Vector2.ZERO:p.dodge_dir=Vector2.RIGHT
		sim.events.append({"type":"dodge","pos":p.pos,"dir":p.dodge_dir,"owner":p.id})
		constellation.moved(p,true)
		return true
	if kind=="cancel_charge":p.charge_time=-1.0;return true
	if sim.map.in_town(p.pos) or p.dodge_time>0:return false
	if kind=="heavy_begin":
		if p.attack_cd>0 or p.charge_time>=0 or p.stamina<maxf(5,20-Content.skill_bonus(p,"heavy_discount")):return false
		p.charge_time=0.0;return true
	if kind=="heavy":
		if p.charge_time<0:return false
		var charge=p.charge_time/0.9;p.charge_time=-1.0
		if p.attack_cd>0 or p.stamina<maxf(5,20-Content.skill_bonus(p,"heavy_discount")):return false
		p.stamina-=maxf(5,20-Content.skill_bonus(p,"heavy_discount"))
		return attack(p,true,charge)
	if p.charge_time>=0:return false
	if kind in ["skill_f","skill_v","skill_c"]:return skills.cast(p,kind)
	if kind=="attack":
		if p.attack_cd>0:return false
		return attack(p,false,0)
	if kind=="nova":
		if p.nova_cd>0 or p.stamina<15:return false
		p.stamina-=15;p.nova_cd=maxf(1.0,4.0-Content.skill_bonus(p,"skill_haste"));p.swing=0.3
		var amount=roundi(sim.damage_for(p)*2.0*(1+Content.skill_bonus(p,"skill_power")))
		p.motion={"warrior":"cleave","ranger":"shoot_high","mage":"cast_high"}[p.class_id];p.motion_time=0.55;p.motion_duration=0.55
		match p.class_id:
			"warrior":area(p,p.pos,3.4+Content.skill_bonus(p,"skill_radius"),amount,"sun_cleave")
			"ranger":
				for angle in [-0.3,-0.15,0.0,0.15,0.3]:launch(p,"bow",p.aim.rotated(angle),amount,10,14,0)
				skills.fx(p,"volley",p.pos,0.55,1.0)
			"mage":
				var center=p.pos
				for i in range(20):center=sim.map.move(center,p.aim*0.2)
				area(p,center,2.6+Content.skill_bonus(p,"skill_radius"),amount,"starburst")
		return true
	return false

func attack(p:Dictionary,heavy:bool,charge:float)->bool:
	var previous=stagger_context
	stagger_context=BossStagger.context(BossStagger.basic_token(heavy,charge,sim.clock))
	var result=_attack(p,heavy,charge)
	stagger_context=previous
	return result

func attack_interval(p:Dictionary,heavy:bool=false)->float:
	var cooldown=float(Content.WEAPONS[weapon_type(p)].cooldown)
	if Content.job(p):cooldown=float(Content.CLASSES[p.class_id].cooldown)/jobs.attack_speed(p)
	var result=maxf(0.15,(cooldown-Content.skill_bonus(p,"attack_haste"))/preload("res://scripts/progression.gd").attack_speed(p))*(1.5 if heavy else 1.0)
	result=maxf(.15,result/(1.+float(constellation.values(p).get("attack_speed",0))))
	if p.haste_time>0:result*=1-p.get("haste_attack",.3)
	return result

func _attack(p:Dictionary,heavy:bool,charge:float)->bool:
	var type=weapon_type(p);var config=Content.WEAPONS[type].duplicate()
	if Content.job(p):
		var cls=Content.CLASSES[p.class_id];config.cooldown=cls.cooldown;config.range=cls.range;config.projectile=cls.projectile
		if not heavy:jobs.basic(p)
	p.attack_cd=attack_interval(p,heavy);p.swing=0.32
	p.motion={"sword":"cleave","axe":"slam","bow":"shoot","staff":"cast"}[type]
	if heavy:p.motion="slam" if type in ["sword","axe"] else "cast_high" if type=="staff" else "shoot_high"
	# Basic attacks resolve immediately. Show their contact pose immediately;
	# releasing a charged attack must not restart its already-shown windup.
	p.motion_duration=0.5 if heavy else 0.46
	p.motion_time=p.motion_duration*.48
	p.motion_aim=p.aim;p.motion_aim_motion=p.motion;p.motion_aim_duration=p.motion_duration
	var multiplier=(1.6+charge*1.4)*(1+Content.skill_bonus(p,"heavy_power")) if heavy else 1.0
	if Content.job(p):multiplier*=jobs.attack_multiplier(p,heavy)
	var amount=roundi(sim.damage_for(p)*config.multiplier*multiplier)
	var radius=config.range+Content.skill_bonus(p,"range" if config.projectile else "melee_range")
	sim.events.append({"type":"heavy" if heavy else "attack","pos":p.pos,"dir":p.aim,"owner":p.id,"weapon":type,"visual_origin":preload("res://scripts/gat_art.gd").launch_offset(p,p.aim)})
	if config.projectile:
		launch(p,type,p.aim,amount,radius+(2 if heavy else 0),config.speed,1.4 if type=="staff" else 0)
		projectiles.back()["basic"]=not heavy
		projectiles.back()["job"]=p.class_id
		if not heavy and p.class_id=="gambler" and p.job_state.get("clean_card",false):
			projectiles.back().speed+=jobs.passive(p,5);p.job_state.clean_card=false
	else:
		if heavy:radius+=0.8
		for e in sim.enemies.values():
			if not HitGeometry.arc(e,p.pos,p.aim,radius,-0.45 if type=="axe" or heavy else -0.05,.7):continue
			var accepted=hit(p,e,amount)
			if accepted and not heavy:jobs.basic_hit(p,e)
	if heavy:jobs.after_heavy(p)
	return true

# 처치 처리 후에도 해당 타격은 성공이다. 적중 시 직업 자원은 남은 체력이
# 아니라 이 반환값으로 지급하므로 마지막 타격도 정상적으로 보상한다.
func hit(p:Dictionary,e:Dictionary,amount:int,source:Variant=null,attribution:Variant=null)->bool:
	if p.get("down_time",0)>0 or p.get("network_leaving",false):return false
	if e.hp<=0 or amount<=0 or not sim.map.line_clear(p.pos if source==null else source,e.pos):return false
	if e.get("training",false) and not preload("res://scripts/training_ground.gd").can_practice(sim,p):return false
	var hit_context:Dictionary=stagger_context if attribution==null else attribution
	if not hit_context.is_empty() and float(hit_context.get("budget",{}).get("created",sim.clock))<float(e.get("stagger",{}).get("reset_at",0)):return false
	var build_hit=constellation.before_hit(p,e,hit_context)
	if not build_hit.allowed:return false
	amount=maxi(1,roundi(amount*build_hit.factor))
	p.combat_time=4.0
	if sim.balance.enemies[e.kind].get("ai","")=="armored":amount=maxi(1,roundi(amount*.75))
	if e.kind=="sentinel" and e.windup<=0:amount=maxi(1,roundi(amount*.70))
	if float(e.hp)/e.max_hp<.3:amount=roundi(amount*(1+Content.skill_bonus(p,"execute")))
	if e.kind in ["warden","golem","sentinel"] or e.get("elite",false):amount=roundi(amount*(1+Content.skill_bonus(p,"elite_damage")))
	var critical=Content.skill_bonus(p,"critical")
	var hit_details={"critical":false}
	if critical>0 and sim.rng.randf()<minf(.65,critical):
		amount=roundi(amount*(1.5+Content.skill_bonus(p,"critical_damage")));hit_details.critical=true
	p.hp=mini(p.max_hp,p.hp+floori(amount*Content.skill_bonus(p,"lifesteal")))
	amount=jobs.outgoing(p,e,amount,hit_details)
	if e.get("stagger",{}).get("state","")=="down":amount=roundi(amount*BossStagger.DOWN_DAMAGE)
	e.hp-=amount
	BossStagger.check_threshold(sim,e)
	BossStagger.apply(sim,p,e,hit_context)
	constellation.after_hit(p,e,hit_context)
	var push=Content.skill_bonus(p,"knockback")
	if push>0 and not e.get("training",false):e.pos=sim.map.move(e.pos,p.pos.direction_to(e.pos)*push)
	sim.events.append({"type":"damage","pos":e.pos,"amount":amount,"enemy":true,"target_id":e.id,"owner":p.id,"weapon":weapon_type(p),"critical":hit_details.critical})
	if e.get("training",false):
		preload("res://scripts/training_ground.gd").record(sim,p,e,amount,hit_details.critical,hit_context)
		return true
	if e.hp<=0:sim.kill(p.id,e)
	return true

func area(p:Dictionary,center:Vector2,radius:float,amount:int,fx_kind:String="star_impact",attribution:Variant=null,exclude:Array=[])->Array:
	sim.events.append({"type":"nova","fx":fx_kind,"pos":center,"dir":p.aim,"owner":p.id,"duration":0.6,"radius":radius,"ground_shape":"circle"})
	var accepted=[]
	for e in sim.enemies.values():
		if e.id in exclude:continue
		if HitGeometry.circle(e,center,radius) and sim.map.line_clear(center,e.pos) and hit(p,e,amount,center,attribution):accepted.append(e.id)
	return accepted

func launch(p:Dictionary,type:String,direction:Vector2,amount:int,distance:float,speed:float,splash:float):
	speed+=Content.skill_bonus(p,"projectile_speed")
	if direction.length()<0.1:direction=Vector2.RIGHT
	projectiles.append({"pos":p.pos,"dir":direction.normalized(),"amount":amount,"remaining":distance,"speed":speed,"type":type,"splash":splash,"owner":p.id,"pierce":int(Content.skill_bonus(p,"pierce")) if type=="bow" else 0,"hit":[],"stagger":stagger_context,"visual_start":p.pos,"visual_origin":preload("res://scripts/gat_art.gd").launch_offset(p,direction)})

func tick_projectiles(delta:float):
	for shot in projectiles:
		var origin:Vector2=shot.pos
		var step:Vector2=shot.dir*minf(shot.remaining,shot.speed*delta)
		var next=origin+step
		shot.remaining-=step.length()
		if not sim.map.line_clear(origin,next) or not sim.map.walkable(next):shot.remaining=0;continue
		shot.pos=next
		var targets=sim.enemies.values().duplicate()
		targets.sort_custom(func(a,b):return origin.distance_squared_to(a.pos)<origin.distance_squared_to(b.pos))
		for e in targets:
			if e.hp<=0 or shot.hit.has(e.id):continue
			if not HitGeometry.forward_segment(e,origin,next,shot.get("width",.42)):continue
			# A wider body can overlap a shot in a neighbouring corridor. Do not
			# consume its pierce ledger or apply splash/status through that wall.
			if not sim.map.line_clear(origin,e.pos):continue
			var p=sim.players[shot.owner]
			var impact:Vector2=e.pos
			# 거절된 표적은 투사체를 막거나 관통 횟수를 쓰지 않는다.
			# 폭발도 유효한 주 표적이 있을 때만 발생하며 주 표적은 한 번 맞는다.
			var accepted=hit(p,e,shot.amount,impact if shot.splash>0 else origin,shot.get("stagger",{}))
			if not accepted:continue
			if shot.splash>0:area(p,impact,shot.splash,shot.amount,"star_impact",shot.get("stagger",{}),[e.id])
			if shot.get("status","") in ["bleed","root","slow"]:jobs.status(p,e,shot.status,4.,shot.get("stagger",{}))
			if shot.get("basic",false):jobs.basic_hit(p,e)
			shot.hit.append(e.id)
			if shot.hit.size()>shot.pierce:shot.remaining=0;break
	projectiles=projectiles.filter(func(shot):return shot.remaining>0)
