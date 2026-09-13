extends RefCounted
## Stable item IDs; the existing health-potion save field remains compatible.
const ITEMS={
	"potion":{"name":"회복 물약","icon":"consumable","action":"potion","cooldown":2.0,"price":15},
	"mana_potion":{"name":"기력 물약","icon":"stamina","action":"mana_potion","cooldown":2.0,"price":20,"recovery":60.0},
	"power_potion":{"name":"공격 강화 물약","icon":"physical_attack","action":"power_potion","cooldown":2.0,"price":40,"power":0.20,"duration":30.0},
	"lure_stone":{"name":"유인 돌","icon":"sound","action":"lure_stone","cooldown":3.0,"price":12,"tool":true,"distance":5.0,"radius":.5,"delay":.45,"duration":1.0,"noise":12},
	"snare_trap":{"name":"올가미 덫","icon":"trap","action":"snare_trap","cooldown":3.0,"price":35,"tool":true,"distance":1.6,"radius":1.3,"delay":1.0,"duration":30.0,"noise":4,"damage":40,"attack_factor":.5,"stagger":24.0},
	"fire_bottle":{"name":"화염병","icon":"fire","action":"fire_bottle","cooldown":3.0,"price":45,"tool":true,"distance":4.0,"radius":2.5,"delay":.65,"duration":1.0,"noise":10,"damage":60,"attack_factor":1.2,"stagger":16.0}
}
const MAX_STACK=20
static func health_recovery(p:Dictionary)->int:
	var base=60+roundi(float(p.get("max_hp",120))*.2)+int(preload("res://scripts/content.gd").skill_bonus(p,"potion_power"))
	return roundi(base*(1.+preload("res://scripts/equipment_special_stats.gd").effect(p,"potion_recovery")))
static func count(p:Dictionary,item:String)->int:
	return int(p.get("potions",0)) if item=="potion" else int(p.get("consumables",{}).get(item,0))
static func bag_id(item:String)->String:return "@potion" if item=="potion" else "@consumable:"+item
static func cooldown_key(item:String)->String:return "tool_cd" if ITEMS.get(item,{}).get("tool",false) else "potion_cd"
static func description(p:Dictionary,item:String)->String:
	if not ITEMS.has(item):return ""
	var effect="생명력 %d 회복"%health_recovery(p)
	if item=="mana_potion":effect="기력 %d 회복"%ITEMS[item].recovery
	elif item=="power_potion":effect="물리·마법 공격력 +%d%% · %d초"%[ITEMS[item].power*100,ITEMS[item].duration]
	elif item=="lure_stone":effect="바라보는 방향 5칸 앞에 투척\n착지 소리로 주변 적 유인 · 파티 최대 4마리"
	elif item=="snare_trap":effect="앞쪽 바닥에 설치 · 1초 뒤 작동\n피해 40 + 기본 공격력의 50%%\n접근한 적을 1.5초 속박 · 4초 둔화\n보스는 속박 대신 무력화 피해 %.2f"%preload("res://scripts/equipment_special_stats.gd").stagger(p,ITEMS[item].stagger)
	elif item=="fire_bottle":effect="바라보는 방향 4칸 앞에 투척\n0.65초 뒤 반경 2.5칸 폭발\n피해 60 + 기본 공격력의 120%%\n보스 무력화 피해 %.2f · 아군 피해 없음"%preload("res://scripts/equipment_special_stats.gd").stagger(p,ITEMS[item].stagger)
	return effect+"\n보유 %d / %d · %s 공통 대기 %d초"%[count(p,item),MAX_STACK,"도구" if ITEMS[item].get("tool",false) else "물약",ITEMS[item].cooldown]
static func unavailable(p:Dictionary,item:String)->String:
	if not ITEMS.has(item):return "등록할 소모품을 선택하세요."
	if p.get("hp",0)<=0:return "쓰러진 상태입니다."
	if count(p,item)<=0:return "소모품이 없습니다."
	if p.get(cooldown_key(item),0)>0:return "도구 재사용 대기 중입니다." if ITEMS[item].get("tool",false) else "물약 재사용 대기 중입니다."
	if item=="potion" and p.hp>=p.max_hp:return "생명력이 가득 찼습니다."
	if item=="mana_potion" and p.stamina>=p.max_stamina:return "기력이 가득 찼습니다."
	if item=="power_potion" and p.get("job_state",{}).get("buffs",{}).get("potion_attack",{}).get("time",0)>0:return "공격 강화 물약의 효과가 유지 중입니다."
	return ""
static func use(sim,p:Dictionary,item:String)->bool:
	if not unavailable(p,item).is_empty():return false
	if ITEMS[item].get("tool",false) and not sim.tactical.place(p,item):return false
	if item=="potion":
		var before=int(p.hp)
		p.hp=mini(p.max_hp,p.hp+health_recovery(p))
		sim.notice(p.id,"생명력 +%d"%(p.hp-before));p.potions-=1
	else:
		if item=="mana_potion":
			var before=float(p.stamina);p.stamina=minf(p.max_stamina,p.stamina+ITEMS[item].recovery)
			sim.notice(p.id,"기력 +%d"%roundi(p.stamina-before))
		elif item=="power_potion":
			sim.combat.jobs.buff(p,"potion_attack",ITEMS[item].power,ITEMS[item].duration)
			sim.notice(p.id,"공격력 +20% · 30초")
		p.consumables[item]-=1
	if count(p,item)==0:p.bag_positions.erase(bag_id(item))
	p[cooldown_key(item)]=ITEMS[item].cooldown;sim.dirty[p.id]=true
	return true
