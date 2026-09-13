extends RefCounted
## Shared places offer personal choices, evaluated against current owned state.
const Inventory=preload("res://scripts/inventory_model.gd")
const Content=preload("res://scripts/content.gd")
const SEED_OFFSET=103331
const DEFINITIONS={
	"herbalist":{"kind":"cache","name":"약초 그루터기","icon":"seed","art":"autumn_mushroom_stump","choices":["brew","herbs"]},
	"sealed_supplies":{"kind":"cache","name":"잠긴 보급 상자","icon":"bag","art":"flood_shipwreck_crate","choices":["unlock","scrap"]},
	"blood_altar":{"kind":"shrine","name":"생명의 제단","icon":"essence","art":"core_core_altar","choices":["sacrifice","mend"]},
	"echo_shrine":{"kind":"shrine","name":"메아리의 등불","icon":"stamina","art":"nebula_astral_lantern","choices":["channel","focus"]}
}
static func configuration()->Dictionary:
	return {"definitions":DEFINITIONS,"seed_offset":SEED_OFFSET,"placement":"replace_existing_cache_or_shrine_without_extra_rooms","selection":"two_variants_and_original_equal_weight_per_kind","claims":"one_choice_per_player_per_generated_floor","cost_validation":"current_authoritative_personal_state","transaction":"stage_all_costs_and_rewards_before_commit","save_version":7,"reconnect":"not_yet_supported","rules":{"brew":{"seed":2,"potions":3},"herbs":"seed 3+tier","unlock":{"tool":1,"essence":"5+tier"},"scrap":"ore 2+tier","sacrifice":{"max_hp_cost":.2,"essence":"4+tier","cannot_kill":true},"mend":{"max_hp_recovery":.3},"channel":{"stamina_cost":40,"essence":"3+tier"},"focus":{"max_stamina_recovery":.6}}}
static func select(map,site:Dictionary)->String:
	var pool=[""]
	for key in DEFINITIONS:
		if DEFINITIONS[key].kind==site.kind:pool.append(key)
	if pool.size()==1:return ""
	var rng=RandomNumberGenerator.new();rng.seed=map.seed_value+SEED_OFFSET+int(site.room)*193
	return pool[rng.randi_range(0,pool.size()-1)]
static func choices(site:Dictionary)->Array:
	return DEFINITIONS.get(site.get("event",""),{}).get("choices",[])
static func quote(p:Dictionary,site:Dictionary,choice:String)->Dictionary:
	var result={"choice":choice,"text":"","reason":"","cost":{},"reward":{},"hp":0,"stamina":0}
	if choice not in choices(site):result.reason="선택할 수 없는 행동입니다.";return result
	var tier=int(site.tier)
	match choice:
		"brew":result.cost={"seed":2};result.reward={"potion":3};result.text="별씨앗 2 → 물약 3"
		"herbs":result.reward={"seed":3+tier};result.text="약초 채집 · 별씨앗 +%d"%(3+tier)
		"unlock":result.cost={"tool":1};result.reward={"essence":5+tier};result.text="도구 1 → 정수 %d"%(5+tier)
		"scrap":result.reward={"ore":2+tier};result.text="부품 회수 · 광석 +%d"%(2+tier)
		"sacrifice":
			result.hp=-maxi(1,ceili(p.max_hp*.2));result.reward={"essence":4+tier};result.text="HP %d → 정수 %d"%[-result.hp,4+tier]
			if p.hp<=-result.hp:result.reason="생명력이 부족합니다."
		"mend":
			result.hp=mini(p.max_hp-p.hp,maxi(1,roundi(p.max_hp*.3)));result.text="생명력 +%d"%result.hp
			if result.hp<=0:result.reason="생명력이 가득 찼습니다."
		"channel":
			result.stamina=-40;result.reward={"essence":3+tier};result.text="기력 40 → 정수 %d"%(3+tier)
			if p.stamina<40:result.reason="기력 40이 필요합니다."
		"focus":
			result.stamina=minf(p.max_stamina-p.stamina,maxf(1.,p.max_stamina*.6));result.text="기력 +%d"%roundi(result.stamina)
			if result.stamina<=0:result.reason="기력이 가득 찼습니다."
	if not result.reason.is_empty():return result
	var staged=p.duplicate(true)
	for material in result.cost:
		if int(staged.materials.get(material,0))<int(result.cost[material]):result.reason=Content.MATERIALS[material]+" %d개가 필요합니다."%int(result.cost[material]);return result
		staged.materials[material]-=int(result.cost[material])
		if staged.materials[material]==0:staged.bag_positions.erase("@mat:"+material)
	for item in result.reward:
		if not Inventory.add_stack(staged,item,result.reward[item]):result.reason=Inventory.stack_failure_reason(staged,item,result.reward[item]);return result
	staged.hp+=result.hp;staged.stamina+=result.stamina
	result["staged"]=staged
	return result
static func describe(site:Dictionary):
	var definition=DEFINITIONS[site.event]
	site.name=definition.name;site.icon=definition.icon;site["event_art"]=definition.art
static func detail(p:Dictionary,site:Dictionary)->String:
	match site.event:
		"herbalist":return "택 1 · 물약 %d · 별씨앗 %d"%[p.potions,int(p.materials.get("seed",0))]
		"sealed_supplies":return "택 1 · 보유 탐사 도구 %d"%int(p.materials.get("tool",0))
		"blood_altar":return "택 1 · 생명력 %d / %d"%[p.hp,p.max_hp]
		"echo_shrine":return "택 1 · 기력 %d / %d"%[roundi(p.stamina),roundi(p.max_stamina)]
	return ""
static func use(sim,p:Dictionary,site:Dictionary,choice:String)->bool:
	var offer=quote(p,site,choice)
	if not offer.reason.is_empty():sim.notice(p.id,offer.reason);return false
	for key in ["hp","stamina","potions","materials","bag_positions"]:p[key]=offer.staged[key]
	if not sim.exploration_claims.has(p.id):sim.exploration_claims[p.id]={}
	sim.exploration_claims[p.id][site.id]=choice;sim.dirty[p.id]=true
	sim.notice(p.id,offer.text)
	return true
