extends RefCounted
## Initial balance proposal; persistent injuries are separate from timed combat effects.
const Party=preload("res://scripts/party_rules.gd")
const FIELDS=["revival_weakness","revival_injury"]
const WEAKNESS_FACTOR=.85
const HEALTH_FACTOR=.80
const CHURCH_COST=10
static func configuration()->Dictionary:
	return {"balance_status":"initial_proposal","weakness_factor":WEAKNESS_FACTOR,"health_factor":HEALTH_FACTOR,"stacking":false,"church_cost":CHURCH_COST,"church_operation":"treat","inn_operations":["rest","resupply_small","resupply"],"return_cures":false}
static func restore(p:Dictionary,saved:Dictionary):
	for key in FIELDS:p[key]=saved.get(key,false)==true
static func valid(saved:Dictionary)->bool:
	for key in FIELDS:
		if not saved.get(key,false) is bool:return false
	return true
static func persist(p:Dictionary,result:Dictionary):
	for key in FIELDS:result[key]=bool(p.get(key,false))
static func attack(p:Dictionary,value:int)->int:
	return maxi(1,roundi(value*WEAKNESS_FACTOR)) if p.get("revival_weakness",false) else value
static func apply_stats(p:Dictionary):
	p["revival_base_max_hp"]=p.max_hp
	if p.get("revival_injury",false):p.max_hp=maxi(1,roundi(p.max_hp*HEALTH_FACTOR))
	if p.get("revival_weakness",false):
		p.defense=maxi(0,roundi(p.defense*WEAKNESS_FACTOR))
		p.magic_defense=maxi(0,roundi(p.magic_defense*WEAKNESS_FACTOR))
static func normal_max_hp(p:Dictionary)->int:return int(p.get("revival_base_max_hp",p.max_hp))
static func rest(p:Dictionary):
	p.revival_injury=false
	p.hp=normal_max_hp(p);p.stamina=p.max_stamina
static func summary(p:Dictionary)->String:
	var rows:PackedStringArray=[]
	if p.get("revival_weakness",false):rows.append("쇠약 · 공격력/방어력 -15% · 성당에서 치료")
	if p.get("revival_injury",false):rows.append("부상 · 최대 체력 -20% · 여관에서 회복")
	return "\n".join(rows)
static func cancel(p:Dictionary):
	p.erase("revive_target");p.erase("revive_progress")
	# Keep the held latch: interruption requires release before another rescue.
static func available(p:Dictionary)->bool:
	return p.get("hp",0)>0 and p.get("down_time",0)<=0 and not p.get("network_leaving",false)
static func target_valid(sim,p:Dictionary,target:Dictionary)->bool:
	return not target.is_empty() and target.id!=p.id and target.get("down_time",0)>0 and not target.get("network_leaving",false) and p.pos.distance_to(target.pos)<=Party.RESCUE_RADIUS and sim.map.line_clear(p.pos,target.pos)
static func candidate(sim,p:Dictionary)->Dictionary:
	if sim.map.zone=="town" or not available(p):return {}
	var best={};var distance=INF
	for target in sim.players.values():
		if not target_valid(sim,p,target):continue
		var next=p.pos.distance_squared_to(target.pos)
		if next<distance or (is_equal_approx(next,distance) and (best.is_empty() or target.id<best.id)):
			best=target;distance=next
	return best
static func consumes(sim,p:Dictionary)->bool:
	return bool(p.get("revive_consumed",false)) or not candidate(sim,p).is_empty()
static func input(sim,p:Dictionary,held:bool,moving:bool):
	var rising=held and not p.get("interact_held",false)
	p["interact_held"]=held
	if not held:
		cancel(p);p["revive_consumed"]=false;return
	if moving or not available(p):cancel(p);return
	if not rising:return
	var target=candidate(sim,p)
	if target.is_empty():return
	p["revive_consumed"]=true
	if p.get("charge_time",-1.)>=0 or p.get("dodge_time",0)>0 or not p.get("job_state",{}).get("casting",{}).is_empty():return
	p.revive_target=target.id;p.revive_progress=0.;p.dir=Vector2.ZERO
	sim.notice(p.id,"구조 중… 상호작용 키를 계속 누르세요.")
static func tick(sim,p:Dictionary,delta:float):
	if not p.has("revive_target"):return
	var target=sim.players.get(p.revive_target,{})
	if not available(p) or not p.get("interact_held",false) or p.get("input_age",INF)>Party.RESCUE_INPUT_TIMEOUT or not target_valid(sim,p,target):
		cancel(p);return
	p.revive_progress=float(p.get("revive_progress",0))+delta;p.dir=Vector2.ZERO
	if p.revive_progress+.000001<Party.RESCUE_SECONDS:return
	for key in FIELDS:target[key]=true
	sim.recalculate(target)
	target.down_time=0.;target.hp=maxi(1,roundi(target.max_hp*Party.RESCUE_HEALTH));target.invulnerable=Party.RESCUE_INVULNERABLE
	sim.dirty[target.id]=true
	cancel(p)
	sim.notice(target.id,"동료가 구조했습니다. 쇠약은 성당, 부상은 여관에서 치료하세요.")
