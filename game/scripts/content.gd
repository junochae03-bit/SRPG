extends RefCounted

const WEAPONS = {
	"sword":{"name":"장검","description":"빠르고 정확한 베기","cooldown":0.48,"range":1.8,"multiplier":1.0,"projectile":false,"speed":0.0},
	"axe":{"name":"전투도끼","description":"느리고 넓은 휘두르기","cooldown":0.76,"range":2.1,"multiplier":1.40,"projectile":false,"speed":0.0},
	"bow":{"name":"사냥활","description":"멀리 날아가는 화살","cooldown":0.56,"range":8.0,"multiplier":0.92,"projectile":true,"speed":13.0},
	"staff":{"name":"별 지팡이","description":"적에게 폭발하는 별빛 탄환","cooldown":0.68,"range":6.5,"multiplier":1.08,"projectile":true,"speed":9.0}
}
const SLOTS = ["weapon","head","chest","hands","legs","feet","accessory"]
const SLOT_NAMES = {"weapon":"주 무기","head":"머리","chest":"상의","hands":"장갑","legs":"하의","feet":"신발","accessory":"장신구"}
const MATERIALS = {"seed":"별씨앗","ore":"반짝 광석","essence":"정원의 정수"}
static var CLASSES = {
	"warrior":{"name":"별빛 검사","weapon":"sword","skill":"해오름 베기","description":"근접 공격과 강인한 체력. Q로 주변을 크게 벱니다."},
	"ranger":{"name":"숲의 궁수","weapon":"bow","skill":"바람 화살","description":"빠른 이동과 원거리 공격. Q로 화살을 부채꼴로 발사합니다."},
	"mage":{"name":"별의 마법사","weapon":"staff","skill":"별무리 폭발","description":"충전 공격과 범위 마법. Q로 조준 방향에 별빛 폭발을 일으킵니다."}
}
const GAT_COSTUMES={"gat_addition_01_1":"꽃바람 고양이","gat_addition_05_2":"푸른 선율","gat_addition_10_2":"장미의 시종기사","gat_addition_11_2":"불꽃 요리사","gat_addition_12_1":"눈꽃의 요정","gat_addition_02_2":"새벽의 사제"}
const COSTUMES = {"none":"적용 안 함 · 기본 캐릭터","traveler":"스텔라이브 · 여행자","witch":"스텔라이브 · 별빛 마녀","starlight":"스텔라이브 · 황금 별무리","celestial":"스텔라이브 · 은하의 날개","gat_addition_01_1":"꽃바람 고양이","gat_addition_05_2":"푸른 선율","gat_addition_10_2":"장미의 시종기사","gat_addition_11_2":"불꽃 요리사","gat_addition_12_1":"눈꽃의 요정","gat_addition_02_2":"새벽의 사제"}
const AVATARS=preload("res://scripts/gat_catalog.gd").NAMES
static var SKILLS = preload("res://scripts/skill_catalog.gd").NODES.duplicate(true)
const ACTIONS=["skill_q","skill_f","skill_v","skill_c","skill_z","skill_x"]
static var loaded_jobs=false
static func initialize_jobs():
	if loaded_jobs:return
	loaded_jobs=true
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://data/jobs/catalog.json"))
	CLASSES.merge(data.classes)
	SKILLS.merge(data.nodes)
static func job(p:Dictionary)->bool:
	initialize_jobs()
	return CLASSES.get(p.get("class_id","warrior"),{}).has("base")
static func base_class(key:String)->String:
	initialize_jobs()
	return CLASSES.get(key,{}).get("base",key)
static func max_rank(node:Dictionary)->int:return int(node.get("max_rank",3))

static func base_appearance(p:Dictionary)->bool:return p.get("costume","none")=="none"
static func gat_appearance(p:Dictionary)->bool:return base_appearance(p) or p.get("costume","") in GAT_COSTUMES
static func costume_role(p:Dictionary)->String:return "hero" if p.get("costume","traveler")=="traveler" else p.get("costume","hero")
static func migrate_appearance(p:Dictionary):
	if int(p.get("schema_version",0))<4:
		p["legacy_costume"]=p.get("legacy_costume",p.get("costume","traveler"))
		p["costume"]="none"
		p["avatar"]="auto"

static func item_size(_item: Dictionary, _rotated: bool = false) -> Vector2i:
	return Vector2i.ONE

static func migrate_skills(p:Dictionary):
	if p.get("class_id","warrior")=="warrior" and p.get("skill_ranks",{}).has("combo"):
		p.skill_ranks["heavy_training"]=int(p.skill_ranks.combo)
		p.skill_ranks.erase("combo")

static func normalize_item(item: Dictionary):
	item["category"]=item.get("category","weapon")
	item["slot"]=item.get("slot","weapon" if item.category=="weapon" else "chest")
	item["weapon_type"]=item.get("weapon_type","sword")
	item["bonus"]=int(item.get("bonus",0))
	item["rarity"]=int(item.get("rarity",0))

static func icon_texture(item:Dictionary)->Texture2D:
	var key=item.get("weapon_type","sword")
	match item.get("category","weapon"):
		"armor","accessory":key=item.get("slot","chest")
		"consumable":key="potion"
		"material":key=str(item.get("material",str(item.get("id","")).trim_prefix("@mat:")))
	return preload("res://scripts/item_art.gd").texture(key)

static func skill_bonus(player: Dictionary, effect: String) -> float:
	var total=0.0
	for node in SKILLS.get(player.get("class_id","warrior"),SKILLS.warrior):
		if node.effect==effect:total+=node.value*int(player.get("skill_ranks",{}).get(node.id,0))
	return total

static func available_points(player: Dictionary) -> int:
	var spent=0
	for rank in player.get("skill_ranks",{}).values():spent+=int(rank)
	return maxi(0,int(player.level)-1-spent)

static func can_invest(player: Dictionary, node_id: String) -> bool:
	if available_points(player)<=0:return false
	for node in SKILLS.get(player.get("class_id","warrior"),SKILLS.warrior):
		if node.id!=node_id:continue
		if int(player.skill_ranks.get(node_id,0))>=max_rank(node) or player.level<int(node.get("level",1)):return false
		if node.parents.is_empty():return true
		for parent in node.parents:
			if int(player.skill_ranks.get(parent,0))>=int(node.get("required_rank",1)):return true
		return false
	return false

static func active_node(p:Dictionary,action:String)->Dictionary:
	var assigned=p.get("skill_loadout",{}).get(action,"")
	if assigned!="":
		for node in SKILLS[p.class_id]:
			if node.id==assigned and node.effect=="active":return node
	if job(p):return {}
	for node in SKILLS[p.class_id]:
		if node.get("action","")==action:return node
	return {}
static func action_rank(p:Dictionary,action:String)->int:
	var node=active_node(p,action)
	return int(p.skill_ranks.get(node.get("id",""),0))
