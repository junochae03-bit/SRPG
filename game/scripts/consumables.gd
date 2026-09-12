extends RefCounted
## Stable item IDs; the existing health-potion save field remains compatible.
const ITEMS={
	"potion":{"name":"회복 물약","icon":"consumable","action":"potion","cooldown":2.0,"price":15},
	"mana_potion":{"name":"마나 물약","icon":"stamina","action":"mana_potion","cooldown":2.0,"price":20,"recovery":60.0},
	"power_potion":{"name":"공격 강화 물약","icon":"physical_attack","action":"power_potion","cooldown":2.0,"price":40,"power":0.20,"duration":30.0}
}
const MAX_STACK=20
static func count(p:Dictionary,item:String)->int:
	return int(p.get("potions",0)) if item=="potion" else int(p.get("consumables",{}).get(item,0))
static func bag_id(item:String)->String:return "@potion" if item=="potion" else "@consumable:"+item
static func description(p:Dictionary,item:String)->String:
	if not ITEMS.has(item):return ""
	var effect="생명력 %d 회복"%(60+roundi(float(p.get("max_hp",120))*.2)+int(preload("res://scripts/content.gd").skill_bonus(p,"potion_power")))
	if item=="mana_potion":effect="기력 %d 회복"%ITEMS[item].recovery
	elif item=="power_potion":effect="물리·마법 공격력 +%d%% · %d초"%[ITEMS[item].power*100,ITEMS[item].duration]
	return effect+"\n보유 %d / %d · 물약 공통 대기 %d초"%[count(p,item),MAX_STACK,ITEMS[item].cooldown]
static func unavailable(p:Dictionary,item:String)->String:
	if not ITEMS.has(item):return "등록할 물약을 선택하세요."
	if p.get("hp",0)<=0:return "쓰러진 상태입니다."
	if count(p,item)<=0:return "물약이 없습니다."
	if p.get("potion_cd",0)>0:return "물약 재사용 대기 중입니다."
	if item=="potion" and p.hp>=p.max_hp:return "생명력이 가득 찼습니다."
	if item=="mana_potion" and p.stamina>=p.max_stamina:return "기력이 가득 찼습니다."
	if item=="power_potion" and p.get("job_state",{}).get("buffs",{}).get("potion_attack",{}).get("time",0)>0:return "공격 강화 물약의 효과가 유지 중입니다."
	return ""
static func use(sim,p:Dictionary,item:String)->bool:
	if not unavailable(p,item).is_empty():return false
	if item=="potion":
		var before=int(p.hp)
		p.hp=mini(p.max_hp,p.hp+60+roundi(p.max_hp*.2)+int(sim.Content.skill_bonus(p,"potion_power")))
		sim.notice(p.id,"생명력 +%d"%(p.hp-before));p.potions-=1
	else:
		if item=="mana_potion":
			var before=float(p.stamina);p.stamina=minf(p.max_stamina,p.stamina+ITEMS[item].recovery)
			sim.notice(p.id,"기력 +%d"%roundi(p.stamina-before))
		else:
			sim.combat.jobs.buff(p,"potion_attack",ITEMS[item].power,ITEMS[item].duration)
			sim.notice(p.id,"공격력 +20% · 30초")
		p.consumables[item]-=1
	if count(p,item)==0:p.bag_positions.erase(bag_id(item))
	p.potion_cd=ITEMS[item].cooldown;sim.dirty[p.id]=true
	return true
