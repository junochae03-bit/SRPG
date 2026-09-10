extends RefCounted
## 노드의 투자 등급(type)과 실제 역할(node_kind)은 별도로 관리한다.
const LABELS={"active":"액티브","active_module":"액티브 모듈","character_passive":"캐릭터 패시브","stat_passive":"스탯 패시브"}
const SUPPORT=["heal","regen","field_heal","barrier","haste","shield","ally_dash","wall","cleanse","distribute","return_anchor","parry","parry_counter","parry_knee","meditate","hit_card","hold_card","cut_card","dice","reroll","summon","pet_heal","pet_recall","pet_buff","pet_haste","pet_guard","pet_sacrifice","buff_attack","buff_crit","buff_crit_damage","guard","fortress","share","chant","stand_card","dice_buff","enchant","stance","empower"]
const BEHAVIOR_PASSIVES={
	"tank":[0,1,4],"swordsman":[2],"summoner":[0,5],"healer":[1,5],"hunter":[3],"explorer":[5],
	"reaper":[4,5],"gambler":[1,3,5],"infighter":[3,5],"breaker":[2,3,5],"martialist":[4,5]}
static func annotate(nodes:Array):
	var attacks=nodes.filter(func(n):return n.get("effect","")=="active" and n.get("mode","") not in SUPPORT)
	for n in nodes:
		var kind="stat_passive";var target=""
		if n.effect=="active":kind="active"
		elif n.effect=="upgrade":kind="active_module";target=str(n.target)
		elif n.type in ["notable","keystone"]:
			kind="character_passive"
			if int(n.cluster)==0 and n.type=="notable":kind="active_module";target=str(attacks[0].id)
		elif n.effect in ["pierce","lifesteal","thorns"]:kind="character_passive"
		elif n.effect=="passive" and int(n.get("index",int(str(n.id).right(2))-1)) in BEHAVIOR_PASSIVES.get(n.class_id,[]):kind="character_passive"
		n["node_kind"]=kind;n["node_kind_name"]=LABELS[kind];n["target_active_id"]=target
		n["effect_scope"]="target_active" if kind=="active_module" else "self" if kind=="active" else "character"
		n["concept_id"]=str(n.class_id)+":concept:"+str(n.cluster)
		if not target.is_empty():
			var target_node=nodes.filter(func(other):return other.id==target)[0]
			n["target_active_name"]=target_node.name
			if n.type!="original":
				n.effects_text+=" · 대상: "+target_node.name;n.description=n.effects_text
				n.synergy="대상 액티브를 습득·장착한 뒤 다른 공격 또는 지원 기술과 연결하세요."
				n.tradeoff="지정한 액티브에만 적용됩니다. 같은 공격만 반복하면 연결 효과를 얻지 못합니다."
