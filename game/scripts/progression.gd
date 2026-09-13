extends RefCounted
const STAT_SCHEMA_VERSION=2
const LEGACY_NAMES={"strength":"힘","endurance":"내구","technique":"기술","agility":"민첩","magic":"마력"}
const LEGACY_KEYS={"strength":"power","magic":"power","endurance":"fortitude","agility":"swiftness","technique":"specialization"}
const NAMES={"power":"위력","vitality":"활력","fortitude":"견고","swiftness":"신속","precision":"정밀","specialization":"특화"}
const SHORT_HELP={"power":"물리 · 마법 공격","vitality":"생명력 · 받는 기술 회복","fortitude":"방어 · 일반 피격 경직 감소","swiftness":"공격 · 이동 · 시전 속도","precision":"치명타 확률 · 피해","specialization":"직업 고유 효과 강화"}
const ICONS={"power":"strength","vitality":"health","fortitude":"endurance","swiftness":"agility","precision":"technique","specialization":"intelligence"}
const HELP={"power":"물리·마법 공격력 각각 +2 / 점","vitality":"최대 생명력 +8 / 점\n받는 기술 회복량 증가 · 최대 15%에 점감","fortitude":"물리·마법 방어력 각각 +2 / 점\n일반 피격 경직 감소 · 최대 20%에 점감","swiftness":"공격·이동·시전 속도 증가\n각각 최대 40% / 20% / 25%에 점감","precision":"치명타 확률·피해 배율 증가\n각각 최대 15%p / 0.30에 점감","specialization":"현재 직업의 고유 전투 효과 강화\n전직 시 효과 교체 · 궁극기 제외"}
static func xp_required(level:int)->int:return 120+80*level+25*level*level
static func migrate(p:Dictionary):
	if int(p.get("stat_schema_version",1))>=STAT_SCHEMA_VERSION:return
	# The budget is derived from level and creation points: clearing investments
	# refunds them without adding a second, reusable pool of points.
	p["stat_migration"]={"from_version":1,"old_stats":p.get("stats",{}).duplicate(true)}
	p["stats"]={};p["stats_refunded"]=true;p["stat_schema_version"]=STAT_SCHEMA_VERSION
static func initialize(p:Dictionary):
	if not p.has("stats"):p.stats={}
	for key in NAMES:p.stats[key]=int(p.stats.get(key,0))
	p["stat_schema_version"]=STAT_SCHEMA_VERSION
static func available(p:Dictionary)->int:
	var spent=0
	for key in NAMES:spent+=int(p.get("stats",{}).get(key,0))
	return maxi(0,(int(p.level)-1)*3+int(p.get("creation_points",0))-spent)
static func bonus(p:Dictionary,key:String)->int:
	return maxi(0,int(p.get("stats",{}).get(key,0))+int(p.get("gear_stats",{}).get(key,0)))
static func gear_values(values:Dictionary)->Dictionary:
	# Convert per item, before summing: legacy strength+magic must not double up.
	var result={}
	for key in values:
		var target=LEGACY_KEYS.get(key,key)
		if target in NAMES:result[target]=maxi(int(result.get(target,0)),maxi(0,int(values[key])))
	return result
static func curve(p:Dictionary,key:String)->float:
	var points=float(bonus(p,key));return points/(points+60.)
static func damage(p:Dictionary,_weapon:String)->int:return bonus(p,"power")*2
static func health(p:Dictionary)->int:return bonus(p,"vitality")*8
static func defense(p:Dictionary)->int:return bonus(p,"fortitude")*2
static func received_healing(p:Dictionary)->float:return 1.+.15*curve(p,"vitality")
static func hurt_duration_factor(p:Dictionary)->float:return 1.-.20*curve(p,"fortitude")
static func cast_speed(p:Dictionary)->float:return 1.+.25*curve(p,"swiftness")
static func cast_time(p:Dictionary,seconds:float,charge_or_ultimate:bool=false)->float:
	return seconds if seconds<=0 or charge_or_ultimate else maxf(.1,seconds/cast_speed(p))
static func critical_chance(p:Dictionary,base:float)->float:return clampf(base+.15*curve(p,"precision"),0.,.85)
static func critical_multiplier(p:Dictionary,base:float)->float:return clampf(base+.30*curve(p,"precision"),1.,3.)
static func magic_user(p:Dictionary)->bool:
	return preload("res://scripts/content.gd").base_class(p.get("class_id","warrior"))=="mage" or p.get("class_id","")=="runesword"
static func cooldown_factor(_p:Dictionary)->float:return 1.
static func attack_speed(p:Dictionary)->float:return 1.+.40*curve(p,"swiftness")
static func move_speed(p:Dictionary)->float:return 1.+.20*curve(p,"swiftness")
static func mitigation(p:Dictionary,magical:bool=false)->float:
	var rating=float(p.get("magic_defense" if magical else "defense",0))
	return clampf(rating/(rating+80.+2.*p.level),0.,.70)
static func received(p:Dictionary,amount:float,magical:bool=false)->int:
	return maxi(1,roundi(amount*(1.-mitigation(p,magical))))
static func configuration()->Dictionary:
	return {"stat_schema_version":STAT_SCHEMA_VERSION,"save_schema_version":7,"names":NAMES,"points_per_level":3,"curve_denominator":60.,"power_attack_per_point":2,"vitality_hp_per_point":8,"vitality_received_skill_heal_cap":.15,"fortitude_defense_per_point":2,"fortitude_normal_hurt_reduction_cap":.20,"swiftness_attack_speed_cap":.40,"swiftness_move_speed_cap":.20,"swiftness_cast_speed_cap":.25,"minimum_noninstant_windup":.1,"windup_excludes":["charge","heavy","channel_duration","hit_interval","ultimate"],"precision_chance_cap":.15,"precision_multiplier_cap":.30,"final_critical_chance_cap":.85,"final_critical_multiplier_cap":3.,"critical_rolls":1,"critical_existing_chance":"1-(1-base)*(1-job)","critical_existing_multiplier":"max(base,job)","migration":{"refund":"clear_old_investments_once_preserve_level_and_creation_budget","audit":"stat_migration.old_stats","legacy_keys":LEGACY_KEYS,"gear_merge":"maximum_per_item_before_sum","item_ids_preserved":true},"specialization_rules":preload("res://scripts/stat_specialization.gd").RULES,"specialization_ultimate":false,"equipment_special_stats":{"designed_count":18,"active_roll_pool":[],"status":"pending_effect_integration"}}
