extends RefCounted
const World=preload("res://scripts/world_catalog.gd")
const Abyss=preload("res://scripts/abyss_catalog.gd")
const CAPS=[0,1,1,2,2,2,3,3,3,3]
const NAMES=["안정","경계","험지","극한"]
const HEALTH_PER_RANK=.10
const DROP_PER_RANK=.15
const ESSENCE_PER_RANK=2
static func cap(depth:int)->int:
	return 0 if depth<=0 or depth%10==0 else CAPS[clampi(int((depth-1)/10),0,9)]
static func normalize(depth:int,value:int)->int:return clampi(value,0,cap(depth))
static func info(depth:int,value:int)->Dictionary:
	var rank=normalize(depth,value)
	return {"rank":rank,"cap":cap(depth),"name":NAMES[rank],"extra_enemies":rank*2,"health_factor":1.+rank*HEALTH_PER_RANK,"drop_bonus":rank*DROP_PER_RANK,"guardian_essence":rank*ESSENCE_PER_RANK}
static func details(depth:int,value:int)->String:
	var data=info(depth,value)
	return "지역 기본 배치 · 추가 위험 없음" if data.rank==0 else "증원 %d마리 · 적 체력 +%d%%"%[data.extra_enemies,roundi((data.health_factor-1.)*100.)]
static func reward(depth:int,value:int)->String:
	var data=info(depth,value)
	return "채집 · 정수 · 장비" if data.rank==0 else "드랍 확률 ×%.2f · 수문장 정수 +%d"%[1.+data.drop_bonus,data.guardian_essence]
static func change_plan(sim,owner:int,argument:String)->bool:
	if owner!=1 or sim.map.zone!="town":return false
	if sim.players[owner].hp<=0:return false
	var data=JSON.parse_string(argument)
	if not data is Dictionary or data.size()!=2 or not data.has("floor") or not data.has("risk"):return false
	for key in ["floor","risk"]:
		if not (data[key] is int or data[key] is float) or not is_finite(float(data[key])) or data[key]!=floor(data[key]):return false
	var depth=int(data.floor);var rank=int(data.risk)
	if depth<1 or depth>100 or rank<0 or rank>cap(depth):return false
	if not Abyss.locked_reason(sim.players[owner],depth).is_empty():return false
	if sim.departure_plan.floor==depth and sim.departure_plan.risk==rank:return true
	sim.departure_plan={"floor":depth,"risk":rank,"revision":int(sim.departure_plan.revision)+1}
	return true
static func add_encounters(map):
	var rank=int(map.risk_level)
	if rank<=0:return
	var cfg=Abyss.config(map.floor_number);var rng=RandomNumberGenerator.new();rng.seed=map.seed_value+82091
	var rooms=[2,3,5,6]
	for i in range(rooms.size()-1,0,-1):
		var j=rng.randi_range(0,i);var previous=rooms[i];rooms[i]=rooms[j];rooms[j]=previous
	rooms.push_front(7)
	var used:Array[Vector2]=[]
	for encounter in map.encounters:used.append(encounter.pos)
	var support=cfg.mobs.filter(func(kind):return World.ENEMIES[kind].ai in ["ranged","healer"])
	var frontline=cfg.mobs.filter(func(kind):return World.ENEMIES[kind].ai not in ["ranged","healer"])
	if support.is_empty():support=cfg.mobs.duplicate()
	if frontline.is_empty():frontline=cfg.mobs.duplicate()
	for index in range(rank*2):
		var room=int(rooms[int(index/2)]);var center=Vector2(map.rooms[room])
		var at=map.find_encounter_position(center+Vector2(-3.5 if index%2==0 else 3.5,2.),map.rooms[room],used);used.append(at)
		var pool=support if index%2==0 else frontline
		var kind=cfg.elite if rank==3 and index==5 else pool[rng.randi_range(0,pool.size()-1)]
		map.encounters.append({"role":"normal","kind":kind,"pos":at,"room":room,"mob_index":0,"formation":3,"risk_reinforcement":true})
static func scale_enemy(enemy:Dictionary,rank:int):
	if rank<=0 or enemy.get("training",false):return
	var factor=1.+rank*HEALTH_PER_RANK
	enemy["risk_rank"]=rank;enemy["risk_base_health"]=enemy.max_hp
	enemy.max_hp=roundi(enemy.max_hp*factor);enemy.hp=enemy.max_hp
static func guardian_drop(sim,owner:int,enemy:Dictionary):
	var rank=int(sim.map.risk_level)
	if rank<=0 or not enemy.get("guardian",false):return
	sim.serial+=1
	var id="risk-%d-%d-%d"%[sim.map.seed_value,owner,sim.serial]
	var item={"id":id,"category":"material","material":"essence","name":sim.Content.MATERIALS.essence,"rarity":0,"bonus":0,"amount":rank*ESSENCE_PER_RANK}
	sim.drops[id]={"item":item,"pos":enemy.pos,"owner":owner,"expires":sim.clock+300.}
static func configuration()->Dictionary:
	return {"caps_by_chapter":CAPS,"names":NAMES,"health_per_rank":HEALTH_PER_RANK,"drop_bonus_per_rank":DROP_PER_RANK,"guardian_essence_per_rank":ESSENCE_PER_RANK,"extra_enemies":"2 * rank","placement":"paired_support_and_frontline_at_guardian_approach_then_optional_wings","seed_offset":82091,"geometry":"unchanged","party_scaling":"applied_after_risk_health_independently","raid_rank":0,"first_chapter_rank":0,"choice":"host_in_town_with_ready_reset_and_revision_ack","persistence":"expedition_only_reset_on_town_return","grade_changes":false}
