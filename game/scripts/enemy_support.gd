extends RefCounted
## One interruptible heal, bounded across all healers by the recipient's budget.
const RANGE=3.8
const SEEK_RANGE=7.0
const WINDUP=.9
const COOLDOWN=6.0
const HEAL_FRACTION=.08
const LIFETIME_FRACTION=.24
const MIN_MISSING=.05
const TARGET_LOCK=3.0
const SCAN_INTERVAL=.25

static func cancel(enemy:Dictionary,interrupted:bool=false):
	if interrupted and enemy.has("support_target"):enemy.ability_cd=maxf(float(enemy.ability_cd),2.)
	enemy.erase("support_target");enemy.erase("support_cast");enemy.erase("support_scan_at");enemy.erase("support_seek")

static func eligible(sim,healer:Dictionary,friend:Dictionary)->bool:
	if friend.is_empty() or friend.id==healer.id or friend.hp<=0 or friend.get("boss",false) or friend.get("guardian",false) or friend.get("training",false):return false
	if sim.balance.enemies[friend.kind].ai=="healer":return false
	if healer.has("encounter_room") and friend.get("encounter_room",-1)!=healer.encounter_room:return false
	if friend.pos.distance_to(healer.home)>10. or friend.pos.distance_to(healer.pos)>SEEK_RANGE:return false
	if not sim.map.line_clear(healer.pos,friend.pos):return false
	return friend.max_hp-friend.hp>=maxi(1,ceili(friend.max_hp*MIN_MISSING)) and LIFETIME_FRACTION-float(friend.get("support_received",0))>=MIN_MISSING and float(friend.get("support_lock_until",0))<=sim.clock

static func step(sim,enemy:Dictionary,threat:Dictionary,speed:float,delta:float)->bool:
	if sim.balance.enemies[enemy.kind].ai!="healer":return false
	if threat.is_empty() or enemy.get("taunt_time",0)>0 or enemy.get("stun_time",0)>0:
		cancel(enemy,true);return false
	if enemy.has("support_target"):
		var friend:Dictionary=sim.enemies.get(enemy.support_target,{})
		if not eligible(sim,enemy,friend) or enemy.pos.distance_to(friend.pos)>RANGE:
			cancel(enemy,true);return false
		enemy.support_cast=maxf(0.,float(enemy.support_cast)-delta)
		if enemy.support_cast>0:return true
		var fraction=minf(HEAL_FRACTION,LIFETIME_FRACTION-float(friend.get("support_received",0)))
		var amount=mini(friend.max_hp-friend.hp,maxi(1,floori(friend.max_hp*fraction)))
		friend.hp+=amount
		friend["support_received"]=float(friend.get("support_received",0))+float(amount)/friend.max_hp
		friend["support_lock_until"]=sim.clock+TARGET_LOCK
		enemy.ability_cd=COOLDOWN;enemy.attack_motion=.35;enemy["attack_motion_kind"]="support"
		sim.events.append({"type":"skill_fx","fx":"ranger_heal","pos":friend.pos,"dir":Vector2.RIGHT,"owner":0,"duration":.6,"radius":.85})
		cancel(enemy);return true
	if enemy.ability_cd>0 or enemy.windup>0:return false
	# A pressured or taunted caster must defend itself, rather than freely heal.
	if enemy.pos.distance_to(threat.pos)<2.:
		enemy.pos=sim.map.move(enemy.pos,threat.pos.direction_to(enemy.pos)*speed*delta);return true
	var target:Dictionary=sim.enemies.get(enemy.get("support_seek",0),{})
	if not eligible(sim,enemy,target):target={}
	if float(enemy.get("support_scan_at",0))<=sim.clock:
		enemy["support_scan_at"]=sim.clock+SCAN_INTERVAL
		var lowest=1.0
		for friend in sim.enemies.values():
			if eligible(sim,enemy,friend) and float(friend.hp)/friend.max_hp<lowest:
				target=friend;lowest=float(friend.hp)/friend.max_hp
		if not target.is_empty():enemy["support_seek"]=target.id
	if target.is_empty():return false
	if enemy.pos.distance_to(target.pos)>RANGE:
		var destination=sim.map.move(enemy.pos,enemy.pos.direction_to(target.pos)*minf(speed*delta,enemy.pos.distance_to(target.pos)-RANGE+.1))
		if destination.distance_to(enemy.home)<=10.:enemy.pos=destination
		return true
	enemy["support_target"]=target.id;enemy["support_cast"]=WINDUP
	return true

static func configuration()->Dictionary:
	return {"range":RANGE,"seek_range":SEEK_RANGE,"windup":WINDUP,"cooldown":COOLDOWN,"heal_fraction":HEAL_FRACTION,"recipient_lifetime_fraction":LIFETIME_FRACTION,"minimum_missing_fraction":MIN_MISSING,"recipient_lock_seconds":TARGET_LOCK,"scan_interval":SCAN_INTERVAL,"same_encounter_only":true,"heal_healers":false,"heal_guardians":false,"requires_line_of_sight":true,"interruptions":["stun","taunt","death","lost_target","lost_threat","hazard_escape"],"budget_reset":"new_spawn_only","authority":"host"}
