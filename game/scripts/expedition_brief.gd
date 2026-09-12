extends RefCounted
const Abyss=preload("res://scripts/abyss_catalog.gd")
const Inventory=preload("res://scripts/inventory_model.gd")
const Content=preload("res://scripts/content.gd")

static func supplies(p:Dictionary)->Dictionary:
	var free=Inventory.CAPACITY-Inventory.all_items(p).filter(func(item):return not Inventory.is_equipped(p,item.id)).size()
	return {"potions":int(p.get("potions",0)),"tools":int(p.get("materials",{}).get("tool",0)),"free":free,"skills":p.get("skill_loadout",{}).size(),"weapon":not str(p.get("equipment",{}).get("weapon",p.get("equipped",""))).is_empty()}

static func floor_info(p:Dictionary,floor_number:int,next_seed:int=0)->Dictionary:
	var config=Abyss.config(floor_number)
	var info={"name":config.name,"level":config.level,"raid":config.raid,"terrain":config.terrain,"lore":config.lore,"monsters":config.mobs.duplicate(),"guardian":config.boss if config.raid else config.elite,"material":"seed" if config.terrain=="forest" else "ore","reason":Abyss.locked_reason(p,floor_number)}
	if config.raid:info.monsters=[];info.guardian="raid:%03d"%floor_number
	info.lore="넓은 보스 전용 전장" if config.raid else preload("res://scripts/dungeon_regions.gd").profile(floor_number).summary
	info["goal"]=config.title if config.raid else "수문장 격파 · 다음 층 개방"
	info["reward"]="유니크 보장 · 에픽 이상 가능" if config.raid else "채집 · 정수 · 장비"
	info["scale"]="전장 1곳 · 준비 쉼터" if config.raid else "주 경로 5구역 · 선택 곁방 4곳"
	info["environment"]=preload("res://scripts/expedition_environment.gd").select(next_seed,floor_number) if next_seed!=0 else {}
	info["clue"]="전방 베기 · 고리 파동" if config.raid else "수문장 앞까지 이어지는 길 · 곁방은 선택"
	if config.raid and floor_number>=60:info.clue="고리 뒤 양방향 직선"
	if config.raid and floor_number>=30:info.clue+=" · 후속 폭발"
	# Public biome intel only: never expose the generated seed, hidden centers or reward rolls.
	return info

static func party_status(players:Dictionary,ready:Dictionary,floor_number:int)->Array:
	var rows=[];var ids=players.keys();ids.sort()
	for id in ids:
		var p=players[id];var reason=Abyss.locked_reason(p,floor_number)
		if p.get("down_time",0)>0:reason="구조 필요"
		rows.append({"id":id,"name":p.name,"level":p.level,"ready":ready.get(id,false),"reason":reason})
	return rows
