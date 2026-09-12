extends RefCounted
const SMART=["goblin_archer","goblin_shaman","clockwork","spellbook","centurion"]
const REACTION=.35
const BODY=preload("res://scripts/enemy_hit_geometry.gd")
static func danger(sim,enemy:Dictionary,position:Vector2)->float:
	var risk=0.
	for zone in sim.combat.skills.zones:
		if zone.get("amount",0)<=0 or zone.get("pulses",[]).is_empty() or zone.get("mode","") in ["trap","trap_bleed"]:continue
		if not sim.players.has(zone.owner) or sim.players[zone.owner].hp<=0 or sim.players[zone.owner].get("network_leaving",false):continue
		if not sim.map.line_clear(zone.pos,position):continue
		risk+=maxf(0.,float(zone.radius)+BODY.radius(enemy)-position.distance_to(zone.pos))
	return risk
static func avoid(sim,enemy:Dictionary,speed:float,delta:float)->bool:
	if sim.map.floor_number<=0 or enemy.get("raid",false) or enemy.get("training",false) or enemy.kind not in SMART or enemy.get("taunt_time",0)>0:return false
	var current=danger(sim,enemy,enemy.pos)
	if current<=0.:enemy.erase("hazard_since");return false
	if not enemy.has("hazard_since"):enemy.hazard_since=sim.clock;return false
	if sim.clock-float(enemy.hazard_since)<REACTION:return false
	var destination=enemy.pos;var score=current
	for index in range(12):
		var candidate=enemy.pos+Vector2.from_angle(index*TAU/12)*1.2
		if not sim.map.line_clear(enemy.pos,candidate):continue
		var next=danger(sim,enemy,candidate)
		if next<score-.01:destination=candidate;score=next
	if destination==enemy.pos:return false
	enemy.pos=sim.map.move(enemy.pos,enemy.pos.direction_to(destination)*minf(speed*delta,1.2))
	return true
static func spread(sim,enemy:Dictionary,speed:float,delta:float,origin:Vector2=Vector2.INF):
	if sim.map.floor_number<=0 or enemy.get("boss",false) or enemy.get("windup",0)>0:return
	if origin==Vector2.INF:origin=enemy.pos
	var direction=Vector2.ZERO
	for friend in sim.enemies.values():
		if friend.id==enemy.id or friend.hp<=0:continue
		var offset=enemy.pos-friend.pos;var distance=offset.length()
		if distance<.001:offset=Vector2.from_angle(enemy.id*2.4);distance=.001
		if distance<2.1:direction+=offset.normalized()*(2.1-distance)
	if direction.length_squared()>.001:
		var candidate=sim.map.move(enemy.pos,direction.limit_length(1.)*speed*.35*delta)
		enemy.pos=sim.map.move(origin,(candidate-origin).limit_length(speed*delta))
static func configuration()->Dictionary:
	return {"hazard_aware_kinds":SMART,"reaction_seconds":REACTION,"avoid_hidden_traps":false,"spread_distance":2.1,"spread_speed_factor":.35,"raid_movement_override":false,"dungeon_only":true,"speed_cap":"configured movement speed including slow"}
