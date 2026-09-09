extends RefCounted
const Content=preload("res://scripts/content.gd")
const Scaling=preload("res://scripts/skill_scaling.gd")
const HitGeometry=preload("res://scripts/enemy_hit_geometry.gd")
var combat_ref:WeakRef
var combat:
	get:return combat_ref.get_ref()
var zones:Array=[]
func _init(owner_combat):combat_ref=weakref(owner_combat)
static func bonuses(p:Dictionary)->Dictionary:
	var result={}
	for key in ["skill_power","skill_radius","skill_haste","skill_discount","slow_duration","stun_duration"]:result[key]=Content.skill_bonus(p,key)
	result["gear"]=preload("res://scripts/equipment_catalog.gd").skill_modifiers(p)
	result["cooldown_factor"]=preload("res://scripts/progression.gd").cooldown_factor(p)
	result["player"]=p
	return result
func cast(p:Dictionary,action:String)->bool:
	if action not in Content.ACTIONS:return false
	var rank=Content.action_rank(p,action);var node=Content.active_node(p,action)
	# Reject an empty or unlearned slot before constructing cast metadata. Empty
	# dictionaries are not valid Scaling nodes and must never allocate a budget.
	if node.is_empty() or rank<=0:
		combat.sim.notice(p.id,"K에서 이 기술을 배운 뒤 사용할 수 있습니다.");return false
	var profile=Scaling.profile(node,rank,bonuses(p))
	var previous=combat.stagger_context
	combat.stagger_context=combat.constellation.prepare(p,node,profile)
	var result=_cast(p,action,profile)
	combat.stagger_context=previous
	return result

func _cast(p:Dictionary,action:String,profile:Dictionary)->bool:
	var rank=Content.action_rank(p,action)
	if rank<=0:
		combat.sim.notice(p.id,"K에서 이 기술을 배운 뒤 사용할 수 있습니다.");return false
	var node=Content.active_node(p,action);var s=profile
	if p.skill_cooldowns.get(node.id,0)>0 or p.stamina<s.cost:return false
	p.stamina-=s.cost;p[action+"_cd"]=s.cooldown;p.skill_cooldowns[node.id]=s.cooldown
	combat.constellation.committed(p,node,s)
	var power=combat.sim.damage_for(p)*s.multiplier;var before=combat.projectiles.size()
	p.motion_time=.5;p.motion_duration=.5;p.swing=.5;p.casting_rank=rank
	p["casting_vfx"]={"skill_id":node.id,"skill_mode":s.mode,"rank":rank,"origin":p.pos,"count":s.count}
	if s.mode=="pull":p.casting_vfx["ground_shape"]="circle"
	if node.has("mode"):cast_extended(p,node,power,s)
	else:
		match s.mode:
			"wave":
				combat.launch(p,"wave",p.aim,roundi(power),s.range,11,0);combat.projectiles.back().pierce=5+rank-1;p.motion="cleave";fx(p,"blade_wave",p.pos,.5,s.radius)
			"spin":
				p.motion="spin";p.motion_time=.75+.24*(s.count-3);p.motion_duration=p.motion_time
				add_zone(p,"whirlwind",p.pos,s.radius,power,pulses(s.count,0,.24))
			"dash":
				var start=p.pos;var hit_ids=[]
				for i in range(ceili(s.distance/.12)):
					p.pos=combat.sim.map.move(p.pos,p.aim*minf(.12,s.distance-i*.12))
					for enemy in combat.sim.enemies.values():
						if HitGeometry.circle(enemy,p.pos,s.radius) and not hit_ids.has(enemy.id) and combat.hit(p,enemy,roundi(power)):hit_ids.append(enemy.id)
				p.motion="dash";p.invulnerable=maxf(p.invulnerable,.20);fx(p,"rush",start,.45,s.radius,p.pos)
			"piercing":
				combat.launch(p,"piercing",p.aim,roundi(power),s.range,18,0);combat.projectiles.back().pierce=6+rank-1;p.motion="shoot";fx(p,"piercing",p.pos,.5,s.radius)
			"rain":p.motion="shoot_high";add_zone(p,"arrow_rain",target(p,3.5),s.radius,power,pulses(s.count,.25,.30))
			"retreat":
				var start=p.pos
				for i in range(ceili(s.distance/.12)):p.pos=combat.sim.map.move(p.pos,-p.aim*minf(.12,s.distance-i*.12))
				for i in range(s.count):combat.launch(p,"bow",p.aim.rotated((i-(s.count-1)*.5)*.15),roundi(power),s.range,14,0)
				p.motion="leap";p.invulnerable=maxf(p.invulnerable,.25);fx(p,"leap",start,.5,s.radius,p.pos)
			"frost":p.motion="cast";add_zone(p,"frost",p.pos,s.radius,power,[.08],s.slow)
			"thunder":p.motion="cast_high";add_zone(p,"thunder",target(p,4),s.radius,power,[.32],0,s.stun)
			"blink":
				var start=p.pos;p.pos=target(p,s.distance);p.motion="blink";p.invulnerable=maxf(p.invulnerable,.30)
				fx(p,"blink",start,.55,s.radius,p.pos);add_zone(p,"starburst",p.pos,s.radius,power,[.10])
	for i in range(before,combat.projectiles.size()):
		combat.projectiles[i].width=s.width;combat.projectiles[i].visual_scale=1+.25*(rank-1);combat.projectiles[i].skill_rank=rank
		combat.projectiles[i].merge(p.casting_vfx,true);combat.projectiles[i]["class_id"]=p.class_id;combat.projectiles[i]["fx"]=node.get("fx",node.id);combat.projectiles[i]["origin"]=combat.projectiles[i].pos
	p.erase("casting_rank")
	p.erase("casting_vfx")
	if s.mode in combat.constellation.MOVEMENT:combat.constellation.moved(p)
	return true
static func pulses(count:int,start:float,interval:float)->Array:
	var result=[]
	for i in range(count):result.append(start+i*interval)
	return result
func cast_extended(p:Dictionary,node:Dictionary,power:float,s:Dictionary):
	var center=target(p,3);var radius=s.radius
	p.motion={"warrior":"cleave","ranger":"shoot","mage":"cast"}[p.class_id]
	match node.mode:
		"fan":
			center=p.pos
			for i in range(s.count):combat.launch(p,"wave" if p.class_id=="warrior" else "bow" if p.class_id=="ranger" else "staff",p.aim.rotated((i-(s.count-1)*.5)*.20),roundi(power),s.range,12,.7+.15*(s.rank-1) if p.class_id=="mage" else 0)
		"burst":
			p.motion="slam" if p.class_id=="warrior" else "shoot_high" if p.class_id=="ranger" else "cast_high"
			add_zone(p,node.fx,center,radius,power,[.35],0,s.stun);return
		"field":add_zone(p,node.fx,center,radius,power,pulses(s.count,.2,.5),s.slow);return
		"chain":
			var previous=p.pos;var examined=[];var remaining=int(s.count)
			while remaining>0:
				var best={};var distance=s.range
				for e in combat.sim.enemies.values():
					if e.hp>0 and e.id not in examined and HitGeometry.edge_distance(e,previous)<distance and combat.sim.map.line_clear(previous,e.pos):best=e;distance=HitGeometry.edge_distance(e,previous)
				if best.is_empty():break
				examined.append(best.id)
				var impact:Vector2=best.pos
				if not combat.hit(p,best,roundi(power),previous):continue
				fx(p,node.fx,previous,.6,1,impact,{"origin":previous});previous=best.pos;remaining-=1
			return
		"pull":
			for e in combat.sim.enemies.values():
				if e.hp<=0 or not HitGeometry.circle(e,center,radius) or not combat.sim.map.line_clear(e.pos,center):continue
				if not combat.hit(p,e,roundi(power),center):continue
				if e.hp>0 and not e.get("training",false):
					for i in range(12+4*(s.rank-1)):e.pos=combat.sim.map.move(e.pos,e.pos.direction_to(center)*.12)
		"heal":p.hp=mini(p.max_hp,p.hp+roundi(p.max_hp*s.heal));center=p.pos
		"barrier":p.barrier_time=s.duration;p.barrier_strength=s.barrier;center=p.pos
		"haste":p.haste_time=s.duration;p.haste_speed=s.haste_speed;p.haste_attack=s.haste_attack;center=p.pos
		"nova_ring":p.motion="cast_high";add_zone(p,node.fx,p.pos,radius,power,pulses(s.count,.1,.55));return
	fx(p,node.fx,center,.8,radius)
func target(p:Dictionary,distance:float)->Vector2:
	var result:Vector2=p.pos
	for i in range(ceil(distance/.1)):result=combat.sim.map.move(result,p.aim*minf(.1,distance-i*.1))
	return result
func fx(p:Dictionary,kind:String,at:Vector2,duration:float,radius:float,end:Vector2=Vector2.INF,visual:Dictionary={})->Dictionary:
	var event={"type":"skill_fx","fx":kind,"pos":at,"dir":p.aim,"owner":p.id,"class_id":p.class_id,"origin":p.pos,"duration":duration,"radius":radius,"rank":p.get("casting_rank",1),"end":at if end==Vector2.INF else end,"sound":"heavy" if p.class_id=="warrior" else "bow" if p.class_id=="ranger" else "nova"}
	event.merge(p.get("casting_vfx",{}),true);event.merge(visual,true)
	combat.sim.events.append(event)
	return event
func add_zone(p:Dictionary,kind:String,at:Vector2,radius:float,power:float,times:Array,slow:float=0,stun:float=0,visual:Dictionary={}):
	zones.append({"owner":p.id,"fx":kind,"pos":at,"radius":radius,"amount":roundi(power),"pulses":times.duplicate(),"elapsed":0.0,"slow":slow,"stun":stun,"stagger":combat.stagger_context})
	var details=visual.duplicate();details["pulse_times"]=times.duplicate()
	details["ground_shape"]="circle"
	fx(p,kind,at,float(times.back())+.65,radius,Vector2.INF,details)
func tick(delta:float):
	for zone in zones:
		zone.elapsed+=delta
		var owner_player=combat.sim.players[zone.owner]
		if zone.get("follow",false):zone.pos=owner_player.pos+owner_player.aim*1.1
		if zone.get("mode","")=="barrage" and owner_player.job_state.get("channel",0)<=0:zone.pulses=[]
		while not zone.pulses.is_empty() and zone.elapsed>=zone.pulses[0]:
			zone.pulses.pop_front();var p=combat.sim.players[zone.owner]
			for e in combat.sim.enemies.values():
				if e.hp<=0 or not HitGeometry.circle(e,zone.pos,zone.radius) or not combat.sim.map.line_clear(zone.pos,e.pos):continue
				if not combat.hit(p,e,zone.amount,zone.pos,zone.get("stagger",{})):continue
				if not zone.get("hit_any",false) and zone.has("job_node"):
					zone.hit_any=true
					if p.class_id=="martialist":combat.jobs.combo(p,zone.job_node)
					if p.class_id=="infighter":p.job_state.rush=mini(10,p.job_state.rush+1);p.job_state.rush_time=2.
				if zone.get("mode","") in ["trap","trap_bleed"]:combat.jobs.status(p,e,"root",2.)
				if p.class_id=="martialist" and zone.get("mode","")=="combo" and zone.pulses.is_empty():combat.jobs.status(p,e,"stun",.1*combat.jobs.passive(p,3))
				if zone.get("mode","")=="trap_bleed":combat.jobs.status(p,e,"bleed",4.,zone.get("stagger",{}))
				if e.hp<=0:continue
				e.slow_time=maxf(e.get("slow_time",0),zone.slow);e.stun_time=maxf(e.get("stun_time",0),zone.stun)
	zones=zones.filter(func(zone):return not zone.pulses.is_empty())
	combat.constellation.tick(delta)
