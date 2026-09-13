extends RefCounted
# Pure values shared by cast previews and runtime. Never import combat owners.
const RULES={
	"warrior":{"label":"기본 직업 액티브 위력·회복·방어 효과","cap":.15},
	"ranger":{"label":"기본 직업 액티브 위력·회복·방어 효과","cap":.15},
	"mage":{"label":"기본 직업 액티브 위력·회복·방어 효과","cap":.15},
	"rogue":{"label":"기본 직업 액티브 위력·회복·보호막","cap":.15},
	"fighter":{"label":"기본 직업 액티브 위력·회복·보호막","cap":.15},
	"tank":{"label":"스킬 무력화·보호막","cap":.25,"secondary":.15},
	"runesword":{"label":"룬 소비 기술 피해","cap":.25},
	"swordsman":{"label":"자기 공격 강화 기술 효과","cap":.15},
	"summoner":{"label":"소환수 타격·생명력","cap":.20,"secondary":.15},
	"elementalist":{"label":"시전 준비가 있는 원소 기술 피해","cap":.25},
	"healer":{"label":"기술 회복·보호막·공격 지원 강화","cap":.20,"secondary":.10},
	"sniper":{"label":"차지·관통 사격 피해","cap":.25},
	"hunter":{"label":"출혈 피해·출혈 대상 처형","cap":.20,"secondary":.15},
	"explorer":{"label":"일반 적 제어 지속","cap":.15,"secondary":.10,"display_secondary_only":true,"pending":"이동·공격 속도 지원 강화는 해당 버프 연결 후 적용"},
	"thief":{"label":"방어 감소·취약 효과","cap":.10,"pending":"독 지속 피해는 독 시스템 연결 후 적용"},
	"reaper":{"label":"강공격·강공격 기술 피해","cap":.25},
	"gambler":{"label":"현재 패 정산 공격 피해","cap":.20,"pending":"7장 포커 족보 개편은 별도 설계"},
	"infighter":{"label":"몰아침 유지 중 피해","cap":.20},
	"breaker":{"label":"차지·패링 반격 피해","cap":.25},
	"martialist":{"label":"연무 마무리 기술 피해","cap":.25}
}
static func ratio(p:Dictionary)->float:
	var points=maxf(0,float(p.get("stats",{}).get("specialization",0))+float(p.get("gear_stats",{}).get("specialization",0)))
	return points/(points+60.)
static func bonus(p:Dictionary,secondary:bool=false)->float:
	return ratio(p)*float(RULES.get(p.get("class_id",""),{}).get("secondary" if secondary else "cap",0.))
static func ultimate(node:Dictionary)->bool:
	return node.get("ultimate",false) or node.get("is_ultimate",false) or node.get("category","")=="ultimate"
static func description(p:Dictionary)->String:
	var rule=RULES.get(p.get("class_id",""),{})
	var secondary_only=bool(rule.get("display_secondary_only",false))
	var result=str(rule.get("label","직업 효과 없음"))+" +%.1f%%"%(bonus(p,secondary_only)*100.)
	if rule.has("secondary") and not secondary_only:result+=" / 보조 +%.1f%%"%(bonus(p,true)*100.)
	return result
static func apply_base(p:Dictionary,node:Dictionary,s:Dictionary)->Dictionary:
	if ultimate(node) or p.get("class_id","") not in ["warrior","ranger","mage"]:return s
	var factor=1.+bonus(p)
	for key in ["multiplier","heal"]:s[key]*=factor
	s.barrier=minf(.8,s.barrier*factor)
	return s
static func apply_job(p:Dictionary,node:Dictionary,s:Dictionary)->Dictionary:
	if ultimate(node):return s
	var job=str(p.get("class_id",""));var mode=str(node.get("mode",""));var factor=1.+bonus(p);var other=1.+bonus(p,true)
	var enhance_power=false
	match job:
		"rogue","fighter":
			enhance_power=true;s.heal*=factor;s.regen*=factor;s.shield*=factor
		"tank":s.shield*=other
		"runesword":enhance_power=int(node.get("rune_cost",0))>0
		"swordsman":
			if mode in ["buff_attack","stance","empower","enchant"]:s.buff*=factor
		"summoner":s.pet_power*=factor;s.pet_hp*=other
		"elementalist":enhance_power=float(node.get("windup",0))>0
		"healer":
			s.heal*=factor;s.regen*=factor;s.shield*=factor
			if mode in ["chant","buff_attack","buff_crit","buff_crit_damage","haste"]:s.buff*=other
		"sniper":enhance_power=mode.begins_with("charge") or mode in ["shot","fan","root_shot","slow_shot","bleed_shot","pull_shot","execute_shot","piercing","pierce_shot","piercing_shot"]
		"explorer":
			if mode=="haste":s.buff*=factor
		"reaper":enhance_power=mode.begins_with("heavy")
		"gambler":enhance_power=mode.begins_with("settle")
		"breaker":
			enhance_power=mode.begins_with("charge");s.counter_power*=factor
		"martialist":enhance_power=mode=="finisher"
	if enhance_power:s.power*=factor
	return s
static func stagger_factor(p:Dictionary)->float:
	return 1.+bonus(p) if p.get("class_id","")=="tank" else 1.
static func heavy_factor(p:Dictionary)->float:
	return 1.+bonus(p) if p.get("class_id","") in ["reaper","breaker"] else 1.
static func rush_factor(p:Dictionary)->float:
	return 1.+bonus(p)*clampf(float(p.get("job_state",{}).get("rush",0))/10.,0.,1.) if p.get("class_id","")=="infighter" else 1.
static func periodic_factor(p:Dictionary,status:String)->float:
	if p.get("class_id","")=="hunter" and status=="bleed":return 1.+bonus(p)
	return 1.
static func execute_factor(p:Dictionary,node:Dictionary,enemy:Dictionary)->float:
	if not ultimate(node) and p.get("class_id","")=="hunter" and "execute" in str(node.get("mode","")) and enemy.get("job_status",{}).has("bleed"):return 1.+bonus(p,true)
	return 1.
static func control_duration(p:Dictionary,enemy:Dictionary,status:String,seconds:float)->float:
	if p.get("class_id","")=="explorer" and not enemy.get("boss",false) and not enemy.get("raid",false) and status in ["slow","stun","root"]:return seconds*(1.+bonus(p,true))
	return seconds
static func debuff_value(p:Dictionary,status:String,base:float)->float:
	return base*(1.+bonus(p)) if p.get("class_id","")=="thief" and status in ["break_armor","vulnerable"] else base
