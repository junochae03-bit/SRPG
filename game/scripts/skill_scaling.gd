extends RefCounted
# These values drive both the actual cast and the current/next-level display.
const LEGACY={
	"blade_wave":{"mode":"wave","power":1.8,"range":6.0,"count":1},
	"whirlwind":{"mode":"spin","power":.8,"radius":2.7,"count":3},
	"rush":{"mode":"dash","power":1.9,"distance":3.36,"radius":1.1},
	"piercing_shot":{"mode":"piercing","power":2.2,"range":12.0},
	"arrow_rain":{"mode":"rain","power":.75,"radius":2.5,"count":3},
	"retreat_shot":{"mode":"retreat","power":.95,"range":9.0,"count":3,"distance":2.64},
	"frost_nova":{"mode":"frost","power":1.5,"radius":3.0,"slow":2.5},
	"thunder":{"mode":"thunder","power":2.7,"radius":2.1,"stun":.8},
	"blink":{"mode":"blink","power":1.4,"radius":1.9,"distance":2.8}
}
const EFFECT_NAMES={"damage":"공격력","health":"최대 생명력","defense":"방어력","stamina":"최대 기력","heavy_power":"강공격 피해","skill_power":"기술 피해","melee_range":"근접 사거리","range":"사거리","skill_radius":"기술 범위","speed":"이동 속도","attack_haste":"기본 공격 대기 감소","skill_haste":"기술 대기 감소","dodge_discount":"회피 기력 절약","sprint_discount":"달리기 기력 절약/초","heavy_discount":"강공격 기력 절약","skill_discount":"기술 기력 절약","stamina_regen":"기력 회복/초","health_regen":"비전투 생명력 회복/초","critical":"치명타 확률","critical_damage":"치명타 피해","lifesteal":"흡혈 비율","execute":"약화된 적 추가 피해","thorns":"근접 반사 피해","potion_power":"물약 추가 회복","xp_bonus":"획득 경험치","gold_bonus":"획득 금화","dodge_duration":"회피 무적 시간","projectile_speed":"투사체 속도","slow_duration":"감속 지속시간","stun_duration":"기절 지속시간","knockback":"밀치기 거리","elite_damage":"엘리트·보스 추가 피해","pierce":"관통 횟수"}
const PERCENT=["heavy_power","skill_power","critical","critical_damage","lifesteal","execute","xp_bonus","gold_bonus","elite_damage"]
static func profile(node:Dictionary,rank:int,bonuses:Dictionary={})->Dictionary:
	var level=clampi(rank,1,3);var base=LEGACY.get(node.id,node)
	var action=str(node.get("action","skill_f"));var mode=str(base.get("mode","fan"))
	var radius=float(base.get("radius",3.5 if mode=="nova_ring" else 2.6))
	var count=int(base.get("count",1))
	if mode in ["fan","chain","retreat"]:count+=level-1
	elif mode in ["spin","rain","field","nova_ring"]:count+=1 if level==3 else 0
	var slow=float(base.get("slow",1.5 if mode=="field" else 0))
	var stun=float(base.get("stun",.6 if mode=="burst" else 0))
	var gear=bonuses.get("gear",{"force":0.,"reach":0.,"echo":0.})
	var result={"rank":level,"mode":mode,"multiplier":float(base.get("power",1))*[1.0,1.5,2.2][level-1]*(1+bonuses.get("skill_power",0)),
		"radius":radius+[0.0,.45,.95][level-1]+bonuses.get("skill_radius",0),"range":float(base.get("range",6 if mode=="chain" else 8))+level-1,"count":count,
		"distance":float(base.get("distance",0))+(level-1)*.5,"slow":(slow*[1.0,1.35,1.7][level-1]+bonuses.get("slow_duration",0)) if slow>0 else 0.0,
		"stun":(stun*[1.0,1.35,1.7][level-1]+bonuses.get("stun_duration",0)) if stun>0 else 0.0,
		"cost":maxf(5,float(node.get("cost",{"skill_f":20,"skill_v":30,"skill_c":25}.get(action,20)))-bonuses.get("skill_discount",0)),
		"cooldown":bonuses.get("cooldown_factor",1.)*maxf(1,float(node.get("cooldown",{"skill_f":7,"skill_v":11,"skill_c":9}.get(action,7)))*[1.0,.94,.88][level-1]-bonuses.get("skill_haste",0)),
		"heal":[.22,.32,.45][level-1],"duration":[5.0,6.5,8.0][level-1],"barrier":[.4,.5,.6][level-1],"haste_speed":[.25,.4,.55][level-1],"haste_attack":[.3,.4,.5][level-1],"width":.42+.12*(level-1)}
	result.multiplier*=1.+gear.force;result.heal*=1.+gear.force;result.barrier=minf(.8,result.barrier*(1.+gear.force))
	result.radius*=1.+gear.reach;result.range*=1.+gear.reach;result.duration*=1.+gear.echo;result.haste_speed*=1.+gear.echo;result.haste_attack=minf(.7,result.haste_attack*(1.+gear.echo))
	return preload("res://scripts/constellation_effects.gd").resolve(bonuses.get("player",{}),node,result)
static func passive_text(node:Dictionary,rank:int)->String:
	var value=float(node.value)*rank
	return ("+%s%%" % number(value*100)) if node.effect in PERCENT else "+"+number(value)
static func number(value:float)->String:
	return str(roundi(value)) if is_equal_approx(value,round(value)) else ("%.2f" % value).trim_suffix("0").trim_suffix("0").trim_suffix(".")
static func metrics(node:Dictionary,rank:int,damage:float,max_hp:int,bonuses:Dictionary={})->Array:
	if node.effect!="active":return [[EFFECT_NAMES.get(node.effect,node.effect),passive_text(node,rank)]]
	var s=profile(node,rank,bonuses);var rows=[]
	if s.mode=="heal":rows.append(["생명력 회복",str(roundi(max_hp*s.heal))+" ("+number(s.heal*100)+"%)"])
	elif s.mode=="barrier":rows.append(["받는 피해 감소",number(s.barrier*100)+"%"]);rows.append(["지속시간",number(s.duration)+"초"])
	elif s.mode=="haste":rows.append(["이동 속도","+"+number(s.haste_speed*100)+"%"]);rows.append(["공격 대기 감소",number(s.haste_attack*100)+"%"]);rows.append(["지속시간",number(s.duration)+"초"])
	else:
		rows.append(["1회 기본 피해",str(roundi(damage*s.multiplier))])
		if s.count>1:rows.append(["발사·타격·대상 수",str(s.count)])
		if s.mode in ["wave","piercing","retreat","fan","chain"]:rows.append(["사거리",number(s.range)])
		else:rows.append(["효과 반경",number(s.radius)])
		if s.mode in ["dash","retreat","blink"]:rows.append(["이동 거리",number(s.distance)])
		if s.slow>0:rows.append(["감속 지속",number(s.slow)+"초"])
		if s.stun>0:rows.append(["기절 지속",number(s.stun)+"초"])
	rows.append(["재사용 시간",number(s.cooldown)+"초"]);rows.append(["소모 기력",number(s.cost)])
	rows.append_array(preload("res://scripts/constellation_effects.gd").metrics(s))
	if rank==0:
		for row in rows:row[1]="미습득"
	return rows
