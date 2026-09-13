extends RefCounted
## Bounded, map-local death records. Inspection never rolls or transfers loot.
const MAX_CORPSES=64
const NEARBY_CORPSES=3
const CORPSE_DISTANCE=8.0
const Attacks=preload("res://scripts/monster_attacks.gd")
const Status=preload("res://scripts/status_markers.gd")
const Vision=preload("res://scripts/dungeon_vision.gd")
const STATUS_NAMES={"slow":"둔화","stun":"기절·무력화","taunt":"도발","armor_break":"방어 파괴","root":"속박","bleed":"출혈","blind":"실명","vulnerable":"취약","weaken":"약화"}
static var pattern_cache={}
var corpses:Array=[]
var serial=0
var sight_context=[]
var sight_records:Array=[]
func record(enemy:Dictionary,clock:float):
	if enemy.get("training",false):return
	serial+=1
	var corpse={"record_id":serial,"source_id":enemy.id,"died_at":clock,"hp":0}
	for key in ["kind","name","pos","max_hp","level","floor","raid","boss","elite"]:
		if enemy.has(key):corpse[key]=enemy[key]
	corpses.append(corpse)
	if corpses.size()>MAX_CORPSES:corpses.pop_front()
func snapshot(map,players:Dictionary)->Array:
	var origins=[]
	for player in players.values():
		if player.hp>0 and not player.get("network_leaving",false):origins.append(Vision.cell_at(player.pos))
	origins.sort()
	var radius=int(map.environment.get("sight",Vision.RADIUS))
	var next=[map.get_instance_id(),map.revision,serial,origins,radius]
	if next!=sight_context:
		sight_context=next;sight_records=[]
		for corpse in corpses:
			var cell=Vision.cell_at(corpse.pos)
			for origin in origins:
				if Vector2(origin).distance_squared_to(Vector2(cell))<=radius*radius and Vision.ray_visible(map,origin,cell):
					sight_records.append(corpse);break
	return sight_records.duplicate(true)
static func codex_id(enemy:Dictionary)->String:
	return "raid:%03d"%int(enemy.floor) if enemy.get("raid",false) and int(enemy.get("floor",0))>0 else str(enemy.kind)
static func nearby(records:Array,origin:Vector2,vision)->Array:
	var visible=records.filter(func(c):return c.pos.distance_to(origin)<=CORPSE_DISTANCE and vision.sees(c.pos))
	visible.sort_custom(func(a,b):return a.pos.distance_squared_to(origin)<b.pos.distance_squared_to(origin))
	return visible.slice(0,NEARBY_CORPSES)
static func attack_shapes(enemy:Dictionary)->String:
	var key=codex_id(enemy)+(":raid" if enemy.get("raid",false) else ":normal")
	if pattern_cache.has(key):return pattern_cache[key]
	var shapes=[]
	for sequence in range(3):
		var source=enemy.duplicate(true);source.pos=Vector2.ZERO;source.pattern=sequence;source.phase=2
		var areas=Attacks.raid_pattern(source,Vector2.RIGHT*3) if enemy.get("raid",false) else Attacks.pattern(enemy.kind,Vector2.ZERO,Vector2.RIGHT*3,sequence)
		for area in areas:
			var shape={"line":"직선","circle":"원형","cone":"부채꼴","ring":"고리"}.get(area.shape,"")
			if not shape.is_empty() and not shapes.has(shape):shapes.append(shape)
	# Legacy tutorial bosses resolve their circular strike in Simulation.tick;
	# raid bosses also replace every fourth cast with a straight wall charge.
	if shapes.is_empty():shapes.append("원형")
	if enemy.get("raid",false) and not shapes.has("직선"):shapes.append("직선")
	var value=" · ".join(shapes)
	pattern_cache[key]=value
	return value
static func description(enemy:Dictionary)->Dictionary:
	var alive=enemy.get("hp",0)>0
	return {"name":str(enemy.name),"subtitle":"LV.%d · %s%s"%[int(enemy.level),"레이드" if enemy.get("raid",false) else "보스" if enemy.get("boss",false) else "엘리트" if enemy.get("elite",false) else "일반", "" if alive else " · 처치됨"],"health":"%d / %d"%[maxi(0,int(enemy.hp)),int(enemy.max_hp)],"shapes":attack_shapes(enemy),"defense":preload("res://scripts/enemy_defense.gd").description(enemy),"statuses":Status.keys_for(enemy,false),"codex_id":codex_id(enemy)}
static func configuration()->Dictionary:
	return {"max_corpses":MAX_CORPSES,"nearby_corpses":NEARBY_CORPSES,"corpse_distance":CORPSE_DISTANCE,"visibility":"current_party_sight","scope":"map_local","rewards":false}
