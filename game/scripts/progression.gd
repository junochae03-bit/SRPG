extends RefCounted
const NAMES={"strength":"힘","dexterity":"민첩","intelligence":"지능","vitality":"체력"}
const HELP={"strength":"근접 공격력 +2 / 원거리 공격력 +0.5","dexterity":"활 공격력 +2 / 치명타 확률 +0.3%","intelligence":"마법 공격력 +2 / 최대 기력 +1","vitality":"최대 생명력 +10 / 방어력 +0.2"}
static func xp_required(level:int)->int:return 120+80*level+25*level*level
static func initialize(p:Dictionary):
	if not p.has("stats"):p.stats={}
	for key in NAMES:p.stats[key]=int(p.stats.get(key,0))
static func available(p:Dictionary)->int:
	var spent=0
	for n in p.get("stats",{}).values():spent+=int(n)
	return maxi(0,(int(p.level)-1)*3-spent)
static func bonus(p:Dictionary,key:String)->int:return int(p.get("stats",{}).get(key,0))
static func damage(p:Dictionary,weapon:String)->int:
	return roundi(bonus(p,"strength")*(2.0 if weapon in ["sword","axe"] else .5)+bonus(p,"dexterity")*(2.0 if weapon=="bow" else .3)+bonus(p,"intelligence")*(2.0 if weapon=="staff" else .2))
