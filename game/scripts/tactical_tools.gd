extends RefCounted
## Host-owned, map-local tools. Inventory mutation occurs only after place succeeds.
const Items=preload("res://scripts/consumables.gd")
const Geometry=preload("res://scripts/enemy_hit_geometry.gd")
const Vision=preload("res://scripts/dungeon_vision.gd")
const Stagger=preload("res://scripts/boss_stagger.gd")
const OWNER_LIMIT=2
const PARTY_LIMIT=8
const EFFECT_SECONDS=.6
var sim_ref:WeakRef
var sim:
	get:return sim_ref.get_ref()
var records:Array=[]
var serial=0
func _init(owner_sim):sim_ref=weakref(owner_sim)
static func is_deployable(item:String)->bool:return Items.ITEMS.get(item,{}).get("tool",false)
func destination(p:Dictionary,item:String)->Vector2:
	return p.pos+p.aim.normalized()*float(Items.ITEMS[item].distance)
func reason(p:Dictionary,item:String)->String:
	if not is_deployable(item):return "사용할 도구를 선택하세요."
	if p.hp<=0 or p.get("network_leaving",false):return "지금은 도구를 사용할 수 없습니다."
	if sim.map.floor_number<=0:return "던전에서 사용할 수 있습니다."
	if p.aim.length_squared()<.01:return "사용할 방향을 정하세요."
	var active=records.filter(func(r):return r.state!="spent" and owner_valid(r.owner) and r.expires>sim.clock)
	if active.filter(func(r):return r.owner==p.id).size()>=OWNER_LIMIT:return "동시에 사용할 수 있는 도구는 2개입니다."
	if active.size()>=PARTY_LIMIT:return "파티의 설치·투척 도구가 가득 찼습니다."
	var target=destination(p,item)
	if not sim.map.walkable(target) or not sim.map.line_clear(p.pos,target):return "벽이 없는 바닥을 향해 사용하세요."
	return ""
func place(p:Dictionary,item:String)->bool:
	var failure=reason(p,item)
	if not failure.is_empty():sim.notice(p.id,failure);return false
	var data=Items.ITEMS[item];serial+=1
	records.append({"id":serial,"owner":p.id,"item":item,"pos":destination(p,item),"from":p.pos,"radius":data.radius,"created":sim.clock,"ready":sim.clock+data.delay,"expires":sim.clock+data.delay+data.duration,"state":"arming"})
	# Spent flashes do not reserve gameplay slots, but are also memory bounded.
	while records.size()>PARTY_LIMIT*2:records.pop_front()
	p.charge_time=-1.
	return true
func owner_valid(owner:int)->bool:
	var p=sim.players.get(owner,{})
	return not p.is_empty() and p.hp>0 and not p.get("network_leaving",false)
func tick():
	for record in records:
		if not owner_valid(record.owner):record.expires=sim.clock;continue
		if record.expires<=sim.clock or record.state=="spent" or sim.clock<record.ready:continue
		record.state="armed"
		if record.item=="snare_trap" and not sim.enemies.values().any(func(e):return e.hp>0 and Geometry.circle(e,record.pos,record.radius) and sim.map.line_clear(record.pos,e.pos)):continue
		activate(record)
	records=records.filter(func(r):return r.expires>sim.clock)
func activate(record:Dictionary):
	# Mark before damage callbacks: this cast can activate only once.
	record.state="spent";record.expires=sim.clock+EFFECT_SECONDS
	var p=sim.players[record.owner];var data=Items.ITEMS[record.item]
	sim.events.append({"type":"tactical_tool","owner":p.id,"item":record.item,"pos":record.pos})
	sim.awareness.emit(p.id,record.pos,int(data.noise))
	if record.item=="lure_stone":return
	var amount=roundi(float(data.damage)+sim.damage_for(p)*float(data.attack_factor))
	var budget={"value":float(data.stagger),"count":1,"spent":{},"created":record.created,"dot":false,"source":record.item,"kind":"tool"}
	var context=Stagger.context(budget)
	for enemy in sim.enemies.values():
		if not Geometry.circle(enemy,record.pos,record.radius):continue
		if not sim.combat.hit(p,enemy,amount,record.pos,context):continue
		if record.item=="snare_trap" and not enemy.get("boss",false):
			sim.combat.jobs.status(p,enemy,"root",1.5,context)
			sim.combat.jobs.status(p,enemy,"slow",4.,context)
func snapshot()->Array:
	var result=[];var origins=[]
	for player in sim.players.values():
		if owner_valid(player.id):origins.append(Vision.cell_at(player.pos))
	var radius=int(sim.map.environment.get("sight",Vision.RADIUS))
	for record in records:
		if not owner_valid(record.owner) or record.expires<=sim.clock:continue
		var cell=Vision.cell_at(record.pos)
		if origins.any(func(origin):return Vector2(origin).distance_squared_to(Vector2(cell))<=radius*radius and Vision.ray_visible(sim.map,origin,cell)):
			result.append(record.duplicate(true))
	return result
static func configuration()->Dictionary:
	return {"owner_limit":OWNER_LIMIT,"party_limit":PARTY_LIMIT,"effect_seconds":EFFECT_SECONDS,"scope":"map_local","authority":"host","target":"aim_direction_fixed_distance_walkable_line_clear","owner_loss":"remove_without_refund","friendly_fire":false,"visibility":"current_party_sight","boss_control":"stagger_only","placement_cost":"after_validation","save":"inventory_only"}
