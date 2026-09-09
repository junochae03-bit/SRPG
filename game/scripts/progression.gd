extends RefCounted
const NAMES={"strength":"힘","endurance":"내구","technique":"기술","agility":"민첩","magic":"마력"}
const HELP={"strength":"물리 공격력 +2 / 활·단검·권격 포함","endurance":"물리·마법 방어력 각각 +2","technique":"스킬 재사용 시간 감소 / 최대 40%에 점감","agility":"공격 속도·이동 속도 증가 / 점감 적용","magic":"마법 공격력 +2 / 마법사 계열·룬소드"}
static func xp_required(level:int)->int:return 120+80*level+25*level*level
static func migrate(p:Dictionary):
	if int(p.get("schema_version",6))<6:
		p["stats"]={};p["stats_refunded"]=true
static func initialize(p:Dictionary):
	if not p.has("stats"):p.stats={}
	for key in NAMES:p.stats[key]=int(p.stats.get(key,0))
static func available(p:Dictionary)->int:
	var spent=0
	for key in NAMES:spent+=int(p.get("stats",{}).get(key,0))
	return maxi(0,(int(p.level)-1)*3-spent)
static func bonus(p:Dictionary,key:String)->int:
	return int(p.get("stats",{}).get(key,0))+int(p.get("gear_stats",{}).get(key,0))
static func damage(p:Dictionary,weapon:String)->int:
	return bonus(p,"magic" if weapon=="staff" else "strength")*2
static func magic_user(p:Dictionary)->bool:
	return preload("res://scripts/content.gd").base_class(p.get("class_id","warrior"))=="mage" or p.get("class_id","")=="runesword"
static func cooldown_factor(p:Dictionary)->float:
	var points=float(bonus(p,"technique"));return 1.-.4*points/(points+60.)
static func attack_speed(p:Dictionary)->float:
	var points=float(bonus(p,"agility"));return 1.+.65*points/(points+60.)
static func move_speed(p:Dictionary)->float:
	var points=float(bonus(p,"agility"));return 1.+.3*points/(points+60.)
static func mitigation(p:Dictionary,magical:bool=false)->float:
	var rating=float(p.get("magic_defense" if magical else "defense",0))
	return clampf(rating/(rating+80.+2.*p.level),0.,.70)
static func received(p:Dictionary,amount:float,magical:bool=false)->int:
	return maxi(1,roundi(amount*(1.-mitigation(p,magical))))
