extends RefCounted
const Equipment=preload("res://scripts/equipment_catalog.gd")
const Inventory=preload("res://scripts/inventory_model.gd")
const World=preload("res://scripts/world_catalog.gd")
static func sell_price(item:Dictionary)->int:return 5+int(item.bonus)*4+int(item.rarity)*12
static func quote(p:Dictionary,facility:String,operation:String,extra:Dictionary={})->Dictionary:
	var q={"title":"선택한 작업","cost":0,"materials":{},"result":"","reason":"","icon":"interact","item":{},"operation":operation,"extra":extra.duplicate(true)}
	var staged=p.duplicate(true)
	match facility+":"+operation:
		"shop:buy":
			var index=int(extra.get("index",0));var keys=Equipment.BASES.keys()
			if index<0 or index>=keys.size():q.reason="상품을 선택하세요.";return q
			q.item=Equipment.make(keys[index],mini(4,int(p.level/5)),0,"@quote");q.title=q.item.name;q.cost=preload("res://scripts/town_services.gd").price(p,index);q.result="가방에 상품 1개를 받습니다."
			if not Inventory.add_gear(staged,q.item):q.reason="가방에 빈 칸이 필요합니다."
		"shop:sell":
			q.item=Inventory.find_item(p,str(extra.get("item","")));q.title="장비 판매"
			if q.item.is_empty() or q.item.get("category","") not in ["weapon","armor","accessory"]:q.reason="판매할 장비를 선택하세요.";return q
			if Inventory.is_equipped(p,q.item.id):q.reason="장착 중인 장비는 판매할 수 없습니다.";return q
			q.title=q.item.name;q.cost=-sell_price(q.item);q.result="선택한 장비 1개를 넘기고 금화를 받습니다."
		"shop:potion":
			q.title="회복 물약 ×1";q.cost=15;q.icon="potion";q.result="가방의 물약 묶음에 1개 추가됩니다."
			if not Inventory.add_stack(staged,"potion",1):q.reason="물약 묶음 또는 가방이 가득 찼습니다."
		"smith:upgrade","smith:reforge":
			q.item=Inventory.find_item(p,str(extra.get("item","")));q.icon="smith"
			if q.item.is_empty() or q.item.get("category","") not in ["weapon","armor","accessory"]:q.reason="작업할 장비를 선택하세요.";return q
			var level=int(q.item.get("upgrade",0));var upgrade=operation=="upgrade"
			q.title="장비 강화" if upgrade else "옵션 재련"
			q.cost=(level+1)*50 if upgrade else 80;q.materials={"ore":level+1} if upgrade else {"essence":1}
			if upgrade:
				q.result="강화 +%d → +%d\n기본 능력 +%d → +%d\n확정 성공" % [level,level+1,q.item.bonus,q.item.bonus+(2 if q.item.slot=="weapon" else 1)]
				if level>=5:q.reason="최대 강화 +5에 도달했습니다."
			else:q.result="현재 옵션을 제외한 새 옵션 1개\n활력 · 집중 · 수호 · 숨결 · 행운\n장비 종류와 강화 단계는 유지됩니다."
		"alchemy:potion":
			q.title="회복 물약 ×3";q.cost=10;q.materials={"seed":3};q.icon="potion";q.result="물약 3개를 조제합니다."
			if p.potions+3>Inventory.MAX_POTIONS or not Inventory.add_stack(staged,"potion",3):q.reason="물약 3개를 모두 보관할 공간이 필요합니다."
		"alchemy:essence":
			q.title="정원의 정수 ×1";q.cost=40;q.materials={"seed":5,"ore":5};q.icon="alchemy";q.result="장비 재련에 쓰는 정수 1개를 만듭니다."
			if not Inventory.add_stack(staged,"essence",1):q.reason="재료를 보관할 가방 공간이 필요합니다."
		"guild:accept":
			var zone=str(extra.get("zone","forest"))
			if not World.DUNGEONS.has(zone):q.reason="의뢰 지역을 선택하세요.";return q
			q.icon="guild";q.title=World.DUNGEONS[zone].name+" 토벌";q.result="목표: 해당 던전의 적 10마리\n완료 보상: 180 G / 정수 1개"
			if not p.guild_contract.is_empty():q.reason="진행 중인 의뢰를 먼저 완료하세요."
		"guild:claim":
			q.title="토벌 의뢰 보상";q.cost=-180;q.icon="guild";q.result="금화 180 G + 정원 정수 1개"
			if p.guild_contract.is_empty() or p.guild_contract.progress<p.guild_contract.target:q.reason="토벌 목표를 먼저 완료하세요."
			elif not Inventory.add_stack(staged,"essence",1):q.reason="보상 재료를 받을 가방 공간이 필요합니다."
		"inn:rest":q.title="초승달 여관 숙박";q.cost=10;q.icon="inn";q.result="생명력 %d → %d\n기력 %d → %d" % [p.hp,p.max_hp,p.stamina,p.max_stamina]
		_:q.reason="이용할 작업을 선택하세요."
	if q.reason.is_empty() and p.gold<q.cost:q.reason="금화가 %d G 부족합니다." % (q.cost-p.gold)
	for material in q.materials:
		if q.reason.is_empty() and p.materials.get(material,0)<q.materials[material]:q.reason=preload("res://scripts/content.gd").MATERIALS[material]+"이 부족합니다."
	return q
