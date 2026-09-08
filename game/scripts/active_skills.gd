extends RefCounted
const Content=preload("res://scripts/content.gd")
var combat_ref:WeakRef
var combat:
	get:return combat_ref.get_ref()
var zones:Array=[]
func _init(owner_combat):combat_ref=weakref(owner_combat)
func cast(p:Dictionary,action:String)->bool:
	var rank=Content.action_rank(p,action)
	if rank<=0:
		combat.sim.notice(p.id,"K에서 이 기술을 배운 뒤 사용할 수 있습니다.")
		return false
	var cd=action+"_cd"
	var node=Content.active_node(p,action)
	var cost=maxf(5,float(node.get("cost",{"skill_f":20,"skill_v":30,"skill_c":25}[action]))-Content.skill_bonus(p,"skill_discount"))
	if p.skill_cooldowns.get(node.id,0)>0 or p.stamina<cost:return false
	p.stamina-=cost;p[cd]=maxf(1.0,float(node.get("cooldown",{"skill_f":7.0,"skill_v":11.0,"skill_c":9.0}[action]))-Content.skill_bonus(p,"skill_haste"));p.skill_cooldowns[node.id]=p[cd]
	var power=combat.sim.damage_for(p)*(1+0.20*(rank-1))*(1+Content.skill_bonus(p,"skill_power"))
	var radius_bonus=Content.skill_bonus(p,"skill_radius")
	p.motion_time=0.5;p.motion_duration=0.5;p.swing=0.5
	if node.has("mode"):
		cast_extended(p,node,power,radius_bonus,rank)
		return true
	match p.class_id+":"+str(node.get("action",action)):
		"warrior:skill_f":
			combat.launch(p,"wave",p.aim,roundi(power*1.8),6,11,0)
			combat.projectiles.back().pierce=5;p.motion="cleave"
			fx(p,"blade_wave",p.pos,0.5,1.5)
		"warrior:skill_v":
			p.motion="spin";p.motion_time=0.75;p.motion_duration=0.75
			add_zone(p,"whirlwind",p.pos,2.7+radius_bonus,power*.8,[0.0,0.24,0.48])
		"warrior:skill_c":
			var start=p.pos;var hit_ids=[]
			for i in range(28):
				p.pos=combat.sim.map.move(p.pos,p.aim*0.12)
				for enemy in combat.sim.enemies.values():
					if enemy.pos.distance_to(p.pos)<1.1 and not hit_ids.has(enemy.id):combat.hit(p,enemy,roundi(power*1.9));hit_ids.append(enemy.id)
			p.motion="dash";p.invulnerable=maxf(p.invulnerable,.20);fx(p,"rush",start,.45,1.0,p.pos)
		"ranger:skill_f":
			combat.launch(p,"piercing",p.aim,roundi(power*2.2),12,18,0);combat.projectiles.back().pierce=6
			p.motion="shoot";fx(p,"piercing",p.pos,.5,1.0)
		"ranger:skill_v":
			p.motion="shoot_high";add_zone(p,"arrow_rain",target(p,3.5),2.5+radius_bonus,power*.75,[.25,.55,.85])
		"ranger:skill_c":
			var start=p.pos
			for i in range(22):p.pos=combat.sim.map.move(p.pos,-p.aim*0.12)
			for angle in [-.15,0,.15]:combat.launch(p,"bow",p.aim.rotated(angle),roundi(power*.95),9,14,0)
			p.motion="leap";p.invulnerable=maxf(p.invulnerable,.25);fx(p,"leap",start,.5,1,p.pos)
		"mage:skill_f":
			p.motion="cast";add_zone(p,"frost",p.pos,3.0+radius_bonus,power*1.5,[0.08],2.5+Content.skill_bonus(p,"slow_duration"))
		"mage:skill_v":
			p.motion="cast_high";add_zone(p,"thunder",target(p,4.0),2.1+radius_bonus,power*2.7,[.32],0,0.8)
		"mage:skill_c":
			var start=p.pos;p.pos=target(p,2.8)
			p.motion="blink";p.invulnerable=maxf(p.invulnerable,.30)
			fx(p,"blink",start,.55,1.0,p.pos)
			add_zone(p,"starburst",p.pos,1.9+radius_bonus,power*1.4,[.10])
	return true
func cast_extended(p:Dictionary,node:Dictionary,power:float,radius_bonus:float,rank:int):
	var center=target(p,3.0);var radius=2.6+radius_bonus
	p.motion={"warrior":"cleave","ranger":"shoot","mage":"cast"}[p.class_id]
	match node.mode:
		"fan":
			for i in range(int(node.count)):
				combat.launch(p,"wave" if p.class_id=="warrior" else "bow" if p.class_id=="ranger" else "staff",p.aim.rotated((i-(node.count-1)*.5)*.20),roundi(power*node.power),8,12,.7 if p.class_id=="mage" else 0)
		"burst":
			p.motion="slam" if p.class_id=="warrior" else "shoot_high" if p.class_id=="ranger" else "cast_high"
			add_zone(p,node.fx,center,radius,power*node.power,[.35],0,.6+Content.skill_bonus(p,"stun_duration"));return
		"field":add_zone(p,node.fx,center,radius,power*node.power,[.2,.7,1.2,1.7],1.5+Content.skill_bonus(p,"slow_duration"));return
		"chain":
			var previous=p.pos;var used=[]
			for i in range(int(node.count)):
				var best={};var distance=6.0
				for e in combat.sim.enemies.values():
					if e.hp>0 and e.id not in used and previous.distance_to(e.pos)<distance and combat.sim.map.line_clear(previous,e.pos):best=e;distance=previous.distance_to(e.pos)
				if best.is_empty():break
				fx(p,node.fx,previous,.6,1,best.pos);combat.hit(p,best,roundi(power*node.power),previous);used.append(best.id);previous=best.pos
			return
		"pull":
			for e in combat.sim.enemies.values():
				if e.hp<=0 or e.pos.distance_to(center)>radius or not combat.sim.map.line_clear(e.pos,center):continue
				for i in range(12):e.pos=combat.sim.map.move(e.pos,e.pos.direction_to(center)*.12)
				combat.hit(p,e,roundi(power*node.power),center)
		"heal":p.hp=mini(p.max_hp,p.hp+roundi(p.max_hp*(.18+.04*rank)));center=p.pos
		"barrier":p.barrier_time=4+rank;p.barrier_strength=.35+.05*rank;center=p.pos
		"haste":p.haste_time=4+rank;center=p.pos
		"nova_ring":p.motion="cast_high";add_zone(p,node.fx,p.pos,3.5+radius_bonus,power*node.power,[.1,.65]);return
	fx(p,node.fx,center,.8,radius)
func target(p:Dictionary,distance:float)->Vector2:
	var result:Vector2=p.pos
	for i in range(ceil(distance/.1)):result=combat.sim.map.move(result,p.aim*minf(.1,distance-i*.1))
	return result
func fx(p:Dictionary,kind:String,at:Vector2,duration:float,radius:float,end:Vector2=Vector2.INF):
	combat.sim.events.append({"type":"skill_fx","fx":kind,"pos":at,"dir":p.aim,"owner":p.id,"duration":duration,"radius":radius,"end":at if end==Vector2.INF else end,"sound":"heavy" if p.class_id=="warrior" else "bow" if p.class_id=="ranger" else "nova"})
func add_zone(p:Dictionary,kind:String,at:Vector2,radius:float,power:float,pulses:Array,slow:float=0,stun:float=0):
	zones.append({"owner":p.id,"fx":kind,"pos":at,"radius":radius,"amount":roundi(power),"pulses":pulses.duplicate(),"elapsed":0.0,"slow":slow,"stun":stun})
	fx(p,kind,at,float(pulses.back())+0.65,radius)
func tick(delta:float):
	for zone in zones:
		zone.elapsed+=delta
		while not zone.pulses.is_empty() and zone.elapsed>=zone.pulses[0]:
			zone.pulses.pop_front()
			var p=combat.sim.players[zone.owner]
			for e in combat.sim.enemies.values():
				if e.hp<=0 or e.pos.distance_to(zone.pos)>zone.radius or not combat.sim.map.line_clear(zone.pos,e.pos):continue
				combat.hit(p,e,zone.amount,zone.pos)
				if e.hp<=0:continue
				e["slow_time"]=maxf(e.get("slow_time",0.0),zone.slow)
				e["stun_time"]=maxf(e.get("stun_time",0.0),zone.stun)
	zones=zones.filter(func(zone):return not zone.pulses.is_empty())
