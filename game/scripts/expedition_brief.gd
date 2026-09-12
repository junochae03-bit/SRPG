extends RefCounted
const Abyss=preload("res://scripts/abyss_catalog.gd")
const Inventory=preload("res://scripts/inventory_model.gd")
const Content=preload("res://scripts/content.gd")

static func supplies(p:Dictionary)->Dictionary:
	var free=Inventory.CAPACITY-Inventory.all_items(p).filter(func(item):return not Inventory.is_equipped(p,item.id)).size()
	return {"potions":int(p.get("potions",0)),"tools":int(p.get("materials",{}).get("tool",0)),"free":free,"skills":p.get("skill_loadout",{}).size(),"weapon":not str(p.get("equipment",{}).get("weapon",p.get("equipped",""))).is_empty()}

static func floor_info(p:Dictionary,floor_number:int)->Dictionary:
	var config=Abyss.config(floor_number)
	var info={"name":config.name,"level":config.level,"raid":config.raid,"terrain":config.terrain,"lore":config.lore,"monsters":config.mobs.duplicate(),"guardian":config.boss if config.raid else config.elite,"material":"seed" if config.terrain=="forest" else "ore","reason":Abyss.locked_reason(p,floor_number)}
	if config.raid:info.monsters=[];info.guardian="raid:%03d"%floor_number
	info.lore="넓은 보스 전용 전장" if config.raid else preload("res://scripts/dungeon_regions.gd").profile(floor_number).summary
	info["goal"]=config.title if config.raid else "수문장 격파 · 다음 층 개방"
	info["reward"]="유니크 보장 · 에픽 이상 가능" if config.raid else "채집 · 정수 · 장비"
	# Public biome intel only: never expose the generated seed, hidden centers or reward rolls.
	return info

static func party_status(players:Dictionary,ready:Dictionary,floor_number:int)->Array:
	var rows=[];var ids=players.keys();ids.sort()
	for id in ids:
		var p=players[id];var reason=Abyss.locked_reason(p,floor_number)
		if p.get("down_time",0)>0:reason="구조 필요"
		rows.append({"id":id,"name":p.name,"level":p.level,"ready":ready.get(id,false),"reason":reason})
	return rows
