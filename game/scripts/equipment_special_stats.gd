extends RefCounted
## Pure equipment-only effects. No combat/catalog imports: safe for every preview path.
const VERSION=1
const POINT_CAP=12
const LINES=[0,1,1,2,2]
const POINT_RANGES=[[0,0],[1,1],[1,2],[1,2],[2,3]]
const DEFINITIONS={
	"medicine":{"name":"약학","effect":"potion_recovery","per_point":.003,"description":"HP 물약 회복량"},
	"breathing":{"name":"호흡","effect":"stamina_cost_reduction","per_point":.003,"description":"기력 소모 감소"},
	"concentration":{"name":"집중","effect":"active_cooldown_reduction","per_point":.0015,"description":"일반 액티브 재사용 감소"},
	"tenacity":{"name":"끈기","effect":"slow_duration_reduction","per_point":.004,"description":"받는 둔화 시간 감소"},
	"barrier_craft":{"name":"보호","effect":"outgoing_shield","per_point":.0025,"description":"부여하는 보호막 흡수량"},
	"first_aid":{"name":"응급","effect":"outgoing_heal","per_point":.0025,"description":"시전자 기술 회복량"},
	"staggering":{"name":"파쇄","effect":"stagger_damage","per_point":.0025,"description":"무력화 피해"},
	"composure":{"name":"평정","effect":"normal_hitstun_duration_reduction","per_point":.003,"description":"일반 피격 경직 감소"}
}
static func active_pool()->Array:return DEFINITIONS.keys()
static func whole(value:Variant,low:int,high:int)->bool:
	return (value is int or value is float) and is_finite(float(value)) and value==floor(value) and value>=low and value<=high
static func valid_item(item:Dictionary,allow_preview:bool=false)->bool:
	if item.has("special_stats_preview"):
		return allow_preview and item.special_stats_preview==true and not item.has("special_stats") and not item.has("special_stats_version")
	if not item.has("special_stats") and not item.has("special_stats_version"):return true
	if not whole(item.get("special_stats_version"),VERSION,VERSION) or not item.get("special_stats") is Array:return false
	if not whole(item.get("rarity"),0,4):return false
	var grade=int(item.rarity);var rows=item.special_stats
	if rows.size()!=LINES[grade]:return false
	var seen=[]
	for row in rows:
		if not row is Dictionary or row.size()!=2 or not row.get("id") is String or not DEFINITIONS.has(row.id) or row.id in seen:return false
		if not whole(row.get("points"),POINT_RANGES[grade][0],POINT_RANGES[grade][1]):return false
		seen.append(row.id)
	return true
static func preview(item:Dictionary):
	# Only for newly constructed definitions/quotes, never normalize saved equipment.
	item.erase("special_stats");item.erase("special_stats_version");item["special_stats_preview"]=true
static func generate(item:Dictionary,unique_id:String)->bool:
	if unique_id.is_empty() or unique_id.begins_with("@") or str(item.get("id",""))!=unique_id:return false
	if item.has("special_stats") or item.has("special_stats_version"):return false
	if not whole(item.get("rarity"),0,4):return false
	var grade=int(item.rarity);var pool=active_pool();var rows=[]
	for index in range(LINES[grade]):
		var digest=("equipment-special-v1:"+unique_id+":"+str(index)).sha256_text()
		var selected=digest.substr(0,8).hex_to_int()%pool.size()
		var key=pool[selected];pool.remove_at(selected)
		var limits=POINT_RANGES[grade]
		var value=int(limits[0])+digest.substr(8,8).hex_to_int()%(int(limits[1])-int(limits[0])+1)
		rows.append({"id":key,"points":value})
	item.erase("special_stats_preview");item["special_stats_version"]=VERSION;item["special_stats"]=rows
	return true
static func totals(equipped_items:Array)->Dictionary:
	var result={};var seen=[]
	for item in equipped_items:
		if item.get("id","") in seen or not valid_item(item):continue
		seen.append(item.get("id",""))
		for row in item.get("special_stats",[]):result[row.id]=mini(POINT_CAP,int(result.get(row.id,0))+int(row.points))
	return result
static func points(p:Dictionary,stat_id:String)->int:
	if not DEFINITIONS.has(stat_id):return 0
	return clampi(int(p.get("equipment_special_points",{}).get(stat_id,0)),0,POINT_CAP)
static func effect(p:Dictionary,effect_id:String)->float:
	for key in DEFINITIONS:
		if DEFINITIONS[key].effect==effect_id:return points(p,key)*float(DEFINITIONS[key].per_point)
	return 0.
static func option_text(item:Dictionary)->String:
	if item.get("special_stats_preview",false):
		return "세부 옵션 %d줄 · 제작/획득 시 확정"%LINES[clampi(int(item.get("rarity",0)),0,4)] if int(item.get("rarity",0))>0 else ""
	if not valid_item(item):return ""
	var rows:PackedStringArray=[]
	for row in item.get("special_stats",[]):
		var d=DEFINITIONS[row.id]
		rows.append("%s +%d · %s %.2f%%"%[d.name,row.points,d.description,int(row.points)*float(d.per_point)*100.])
	return "\n".join(rows)
static func stamina_cost(p:Dictionary,base:float)->float:return maxf(0,base)*(1.-effect(p,"stamina_cost_reduction"))
static func slow_duration(p:Dictionary,base:float)->float:return maxf(0,base)*(1.-effect(p,"slow_duration_reduction"))
static func hurt_duration(p:Dictionary,base:float,existing_factor:float=1.)->float:
	return maxf(0,base)*maxf(.70,existing_factor*(1.-effect(p,"normal_hitstun_duration_reduction")))
static func shield(p:Dictionary,base:float)->float:return base*(1.+effect(p,"outgoing_shield"))
static func healing(p:Dictionary,base:float)->float:return base*(1.+effect(p,"outgoing_heal"))
static func stagger(p:Dictionary,base:float)->float:return base*(1.+effect(p,"stagger_damage"))
static func ultimate(node:Dictionary)->bool:return node.get("ultimate",false) or node.get("is_ultimate",false) or node.get("category","")=="ultimate"
static func profile(p:Dictionary,node:Dictionary,values:Dictionary,cooldown_reference:float=-1.)->Dictionary:
	if ultimate(node):return values
	if values.has("cost"):values.cost=stamina_cost(p,values.cost)
	var reduction=effect(p,"active_cooldown_reduction")
	if values.has("cooldown") and reduction>0:
		# Rank/passive changes belong to the skill's baseline; percentage CDR shares one cap.
		var base=cooldown_reference if cooldown_reference>=0 else float(node.get("cooldown",values.cooldown))
		var floor_seconds=base*.60
		values.cooldown=maxf(floor_seconds,values.cooldown*(1.-reduction))
	for key in ["heal","regen","recall_heal"]:
		if values.has(key):values[key]=healing(p,values[key])
	for key in ["shield","sacrifice_ratio"]:
		if values.has(key):values[key]=shield(p,values[key])
	return values
static func configuration()->Dictionary:
	return {"version":VERSION,"designed_count":18,"active_roll_pool":active_pool(),"definitions":DEFINITIONS,"status":"eight_effects_connected","tuning":"proposed_initial_values","lines_by_rarity":LINES,"points_by_rarity":POINT_RANGES,"per_stat_cap":POINT_CAP,"activation":"equipped_immediately_no_upgrade_gate","generation":"host_unique_item_id_sha256_once_then_persist","legacy":"missing_fields_preserved_no_retroactive_roll","preview":"unresolved_rows_never_promised","cooldown_total_reduction_cap":.40,"normal_hurt_total_reduction_cap":.30}
