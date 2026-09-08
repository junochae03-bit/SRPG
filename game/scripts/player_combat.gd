extends RefCounted
const Content=preload("res://scripts/content.gd")
const Inventory=preload("res://scripts/inventory_model.gd")
var sim_ref:WeakRef
var sim:
	get:return sim_ref.get_ref()
var projectiles:Array=[]
var skills
func _init(owner_sim):
	sim_ref=weakref(owner_sim)
	skills=preload("res://scripts/active_skills.gd").new(self)

func weapon_type(p:Dictionary)->String:
	return Inventory.find_item(p,p.equipped).get("weapon_type","sword")

func initialize(p:Dictionary):
	p.merge({"sprint":false,"dodge_cd":0.0,"dodge_time":0.0,"dodge_dir":Vector2.ZERO,"invulnerable":0.0,"charge_time":-1.0})
	p.merge({"skill_f_cd":0.0,"skill_v_cd":0.0,"skill_c_cd":0.0,"motion":"idle","motion_time":0.0,"motion_duration":0.4,"hurt_time":0.0})
	p.merge({"skill_cooldowns":{},"barrier_time":0.0,"barrier_strength":0.0,"haste_time":0.0,"regen_fraction":0.0,"combat_time":0.0,"enemy_slow_time":0.0})

func tick_player(p:Dictionary,delta:float):
	for key in ["dodge_cd","dodge_time","invulnerable","skill_f_cd","skill_v_cd","skill_c_cd","motion_time","hurt_time"]:p[key]=maxf(0,p[key]-delta)
	for key in ["barrier_time","haste_time","combat_time","enemy_slow_time"]:p[key]=maxf(0,p[key]-delta)
	for key in p.skill_cooldowns:p.skill_cooldowns[key]=maxf(0,p.skill_cooldowns[key]-delta)
	for action in ["skill_f","skill_v","skill_c"]:p[action+"_cd"]=p.skill_cooldowns.get(Content.active_node(p,action).get("id",""),0)
	if p.combat_time<=0:
		p.regen_fraction+=Content.skill_bonus(p,"health_regen")*delta
		if p.regen_fraction>=1:p.hp=mini(p.max_hp,p.hp+int(p.regen_fraction));p.regen_fraction=fposmod(p.regen_fraction,1)
	if p.charge_time>=0:p.charge_time=minf(0.9,p.charge_time+delta)
	var speed=sim.balance.player.speed+Content.skill_bonus(p,"speed")
	if p.haste_time>0:speed*=1.25
	if p.enemy_slow_time>0:speed*=.65
	if p.dodge_time>0:
		p.pos=sim.map.move(p.pos,p.dodge_dir*11.5*delta)
	elif p.sprint and p.dir.length()>0.1 and p.stamina>0 and p.charge_time<0:
		p.pos=sim.map.move(p.pos,p.dir*speed*1.65*delta)
		p.stamina=maxf(0,p.stamina-maxf(5,23-Content.skill_bonus(p,"sprint_discount"))*delta)
	else:
		p.pos=sim.map.move(p.pos,p.dir*speed*(0.4 if p.charge_time>=0 else 1.0)*delta)
		if p.charge_time<0:p.stamina=minf(p.max_stamina,p.stamina+(18+Content.skill_bonus(p,"stamina_regen"))*delta)

func act(p:Dictionary,kind:String)->bool:
	if kind=="dodge":
		var cost=maxf(5,25-Content.skill_bonus(p,"dodge_discount"))
		if p.dodge_cd>0 or p.stamina<cost:return false
		p.stamina-=cost;p.dodge_cd=0.8;p.dodge_time=0.26;p.invulnerable=0.24;p.charge_time=-1.0
		p.invulnerable+=Content.skill_bonus(p,"dodge_duration")
		p.dodge_dir=p.dir.normalized() if p.dir.length()>0.1 else p.aim.normalized()
		if p.dodge_dir==Vector2.ZERO:p.dodge_dir=Vector2.RIGHT
		sim.events.append({"type":"dodge","pos":p.pos,"dir":p.dodge_dir,"owner":p.id})
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
	var type=weapon_type(p);var config=Content.WEAPONS[type]
	p.attack_cd=maxf(0.15,config.cooldown-Content.skill_bonus(p,"attack_haste"))*(1.5 if heavy else 1.0);p.swing=0.32
	if p.haste_time>0:p.attack_cd*=.7
	p.motion={"sword":"cleave","axe":"slam","bow":"shoot","staff":"cast"}[type]
	if heavy:p.motion="slam" if type in ["sword","axe"] else "cast_high" if type=="staff" else "shoot_high"
	p.motion_time=0.5 if heavy else 0.32;p.motion_duration=p.motion_time
	var multiplier=(1.6+charge*1.4)*(1+Content.skill_bonus(p,"heavy_power")) if heavy else 1.0
	var amount=roundi(sim.damage_for(p)*config.multiplier*multiplier)
	var radius=config.range+Content.skill_bonus(p,"range" if config.projectile else "melee_range")
	sim.events.append({"type":"heavy" if heavy else "attack","pos":p.pos,"dir":p.aim,"owner":p.id,"weapon":type})
	if config.projectile:
		launch(p,type,p.aim,amount,radius+(2 if heavy else 0),config.speed,1.4 if type=="staff" else 0)
	else:
		if heavy:radius+=0.8
		for e in sim.enemies.values():
			var delta:Vector2=e.pos-p.pos
			if delta.length()>radius or (delta.length()>0.7 and p.aim.dot(delta.normalized())<(-0.45 if type=="axe" or heavy else -0.05)):continue
			hit(p,e,amount)
	return true

func hit(p:Dictionary,e:Dictionary,amount:int,source:Variant=null):
	if e.hp<=0 or not sim.map.line_clear(p.pos if source==null else source,e.pos):return
	p.combat_time=4.0
	if sim.balance.enemies[e.kind].get("ai","")=="armored":amount=maxi(1,roundi(amount*.75))
	if e.kind=="sentinel" and e.windup<=0:amount=maxi(1,roundi(amount*.70))
	if float(e.hp)/e.max_hp<.3:amount=roundi(amount*(1+Content.skill_bonus(p,"execute")))
	if e.kind in ["warden","golem","sentinel"] or e.get("elite",false):amount=roundi(amount*(1+Content.skill_bonus(p,"elite_damage")))
	var critical=Content.skill_bonus(p,"critical")+preload("res://scripts/progression.gd").bonus(p,"dexterity")*.003
	if critical>0 and sim.rng.randf()<minf(.65,critical):amount=roundi(amount*(1.5+Content.skill_bonus(p,"critical_damage")))
	p.hp=mini(p.max_hp,p.hp+floori(amount*Content.skill_bonus(p,"lifesteal")))
	e.hp-=amount
	var push=Content.skill_bonus(p,"knockback")
	if push>0:e.pos=sim.map.move(e.pos,p.pos.direction_to(e.pos)*push)
	sim.events.append({"type":"damage","pos":e.pos,"amount":amount,"enemy":true,"owner":p.id})
	if e.hp<=0:sim.kill(p.id,e)

func area(p:Dictionary,center:Vector2,radius:float,amount:int,fx_kind:String="star_impact"):
	sim.events.append({"type":"nova","fx":fx_kind,"pos":center,"dir":p.aim,"owner":p.id,"duration":0.6,"radius":radius})
	for e in sim.enemies.values():
		if e.pos.distance_to(center)<=radius and sim.map.line_clear(center,e.pos):hit(p,e,amount,center)

func launch(p:Dictionary,type:String,direction:Vector2,amount:int,distance:float,speed:float,splash:float):
	speed+=Content.skill_bonus(p,"projectile_speed")
	if direction.length()<0.1:direction=Vector2.RIGHT
	projectiles.append({"pos":p.pos,"dir":direction.normalized(),"amount":amount,"remaining":distance,"speed":speed,"type":type,"splash":splash,"owner":p.id,"pierce":int(Content.skill_bonus(p,"pierce")) if type=="bow" else 0,"hit":[]})

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
			if e.pos.distance_to(Geometry2D.get_closest_point_to_segment(e.pos,origin,next))>0.42:continue
			var p=sim.players[shot.owner]
			if shot.splash>0:area(p,e.pos,shot.splash,shot.amount)
			else:hit(p,e,shot.amount,origin)
			shot.hit.append(e.id)
			if shot.hit.size()>shot.pierce:shot.remaining=0;break
	projectiles=projectiles.filter(func(shot):return shot.remaining>0)
