extends RefCounted
## New services share one quote/staging path: no charge unless every output fits.
const Inventory=preload("res://scripts/inventory_model.gd")
const Consumables=preload("res://scripts/consumables.gd")
const Equipment=preload("res://scripts/equipment_catalog.gd")
const LABELS={"seed":"별씨앗","ore":"광석","essence":"정수","potion":"회복 물약","tool":"탐사 도구","mana_potion":"마나 물약","power_potion":"공격 강화 물약"}
const DEFAULT_INN_OPERATION="resupply_small"
const INN_RESUPPLY_TARGETS={"resupply_small":5,"resupply":Inventory.MAX_POTIONS}
const OPERATIONS=["smith:salvage","shop:potion","shop:mana_potion","shop:power_potion","shop:tool","alchemy:potion","alchemy:mana_potion","alchemy:power_potion","alchemy:essence","alchemy:ore","guild:supply","guild:cancel","inn:resupply_small","inn:resupply"]
static func handles(facility:String,operation:String)->bool:return facility+":"+operation in OPERATIONS
static func describe(p:Dictionary,facility:String,operation:String,extra:Dictionary={})->Dictionary:
	var q={"title":"선택한 작업","cost":0,"materials":{},"outputs":{},"result":"","reason":"","icon":facility,"item":{},"operation":operation,"extra":extra.duplicate(true)}
	if not handles(facility,operation):q.reason="이용할 작업을 선택하세요.";return q
	var raw=extra.get("quantity",1)
	if not (raw is int or raw is float) or not is_finite(float(raw)) or float(raw)!=floor(float(raw)):q.reason="수량을 확인하세요.";return q
	var quantity=int(raw)
	if extra.has("target_quantity"):
		if facility!="alchemy" or operation not in ["potion","mana_potion","power_potion","essence","ore"]:q.reason="목표 재고는 조합식에서만 지정할 수 있습니다.";return q
		var target=extra.target_quantity
		if not Inventory.whole_count(target,Inventory.stack_limit(operation)) or target<1:q.reason="목표 재고 수량을 확인하세요.";return q
		var current=Consumables.count(p,operation) if Consumables.ITEMS.has(operation) else int(p.materials.get(operation,0))
		var batch=1 if operation=="essence" else 3
		q.target_quantity=int(target);q.current_quantity=current
		if current>=int(target):
			q.title=LABELS[operation];q.icon=Consumables.ITEMS[operation].icon if Consumables.ITEMS.has(operation) else operation
			q.result="현재 %d개 / 목표 %d개 · 목표 달성"%[current,int(target)];q.reason=q.result;return q
		quantity=ceili(float(int(target)-current)/batch)
		q.final_quantity=current+quantity*batch;q.batches=quantity
		q.result="현재 %d → 제작 후 %d · 목표 %d\n%d개 단위 × %d회\n"%[current,q.final_quantity,int(target),batch,quantity]
		if q.final_quantity>Inventory.stack_limit(operation):q.reason="%d개 단위 제작 시 재고 %d개가 보관 상한 %d개를 넘습니다."%[batch,q.final_quantity,Inventory.stack_limit(operation)];return q
	elif quantity not in ([1,5,10] if facility=="shop" else [1,3,5] if facility=="alchemy" else [1]):q.reason="수량을 확인하세요.";return q
	match facility+":"+operation:
		"smith:salvage":
			q.item=Inventory.find_item(p,str(extra.get("item","")))
			if q.item.is_empty() or q.item.get("category","") not in ["weapon","armor","accessory"]:q.reason="분해할 장비를 선택하세요.";return q
			if Inventory.is_equipped(p,q.item.id):q.reason="착용 중인 장비는 분해할 수 없습니다.";return q
			q.title="장비 분해";q.outputs.ore=1+int(q.item.rarity)*2+int(q.item.get("upgrade",0))
			if int(q.item.rarity)>=2:q.outputs.essence=int(q.item.rarity)-1
			q.result=q.item.name+" → 분해\n";q.icon="ore"
		"shop:potion":q.title="회복 물약 ×%d"%quantity;q.cost=15*quantity;q.outputs.potion=quantity;q.icon="potion"
		"shop:mana_potion","shop:power_potion":
			q.title=Consumables.ITEMS[operation].name+" ×%d"%quantity;q.cost=Consumables.ITEMS[operation].price*quantity;q.outputs[operation]=quantity;q.icon=Consumables.ITEMS[operation].icon
		"alchemy:mana_potion","alchemy:power_potion":
			q.title=Consumables.ITEMS[operation].name+" ×%d"%(3*quantity);q.cost=(15 if operation=="mana_potion" else 30)*quantity;q.materials.seed=3*quantity
			q.materials["essence" if operation=="mana_potion" else "ore"]=(1 if operation=="mana_potion" else 2)*quantity;q.outputs[operation]=3*quantity;q.icon=Consumables.ITEMS[operation].icon
		"shop:tool":q.title="탐사 도구 ×%d"%quantity;q.cost=25*quantity;q.outputs.tool=quantity;q.icon="smith"
		"alchemy:potion":q.title="회복 물약 ×%d"%(3*quantity);q.cost=10*quantity;q.materials.seed=3*quantity;q.outputs.potion=3*quantity;q.icon="potion"
		"alchemy:essence":q.title="정원의 정수 ×%d"%quantity;q.cost=40*quantity;q.materials={"seed":5*quantity,"ore":5*quantity};q.outputs.essence=quantity;q.icon="essence"
		"alchemy:ore":q.title="광석 ×%d"%(3*quantity);q.cost=20*quantity;q.materials.seed=5*quantity;q.outputs.ore=3*quantity;q.icon="ore"
		"guild:supply":q.title="탐사물 납품";q.cost=-300;q.materials={"seed":10,"ore":5};q.result="금화 +300 G";q.icon="gold"
		"guild:cancel":
			q.title="의뢰 포기";q.result="현재 토벌 의뢰 종료\n진행도 초기화 · 보상 없음"
			if p.guild_contract.is_empty():q.reason="진행 중인 의뢰가 없습니다."
		"inn:resupply_small","inn:resupply":
			var target=int(INN_RESUPPLY_TARGETS[operation]);var missing=maxi(0,target-int(p.potions))
			q.title="소규모 보급" if operation==DEFAULT_INN_OPERATION else "원정 준비"
			q.cost=10+15*missing;q.icon="inn";q.target_potions=target
			if missing>0:q.outputs.potion=missing
			q.result="생명력 %d → %d\n기력 %d → %d\n물약 %d → %d"%[p.hp,p.max_hp,p.stamina,p.max_stamina,p.potions,int(p.potions)+missing]
	if operation not in INN_RESUPPLY_TARGETS:
		for key in q.outputs:q.result+=("\n" if not q.result.is_empty() and not q.result.ends_with("\n") else "")+LABELS[key]+" +"+str(q.outputs[key])
	if q.reason.is_empty() and p.gold<q.cost:q.reason="금화 %d G 부족"%(q.cost-p.gold)
	for key in q.materials:
		if q.reason.is_empty() and int(p.materials.get(key,0))<int(q.materials[key]):q.reason=LABELS[key]+" %d개 부족"%(int(q.materials[key])-int(p.materials.get(key,0)))
	return q
static func stage(p:Dictionary,facility:String,operation:String,extra:Dictionary={})->Dictionary:
	var q=describe(p,facility,operation,extra)
	if not q.reason.is_empty():return {"quote":q,"player":{}}
	var staged=p.duplicate(true)
	staged.gold-=q.cost
	for key in q.materials:staged.materials[key]-=q.materials[key]
	if operation=="salvage":
		var id=str(q.item.id);staged.inventory=staged.inventory.filter(func(item):return item.id!=id);staged.bag_positions.erase(id)
	Inventory.initialize(staged)
	for key in q.outputs:
		if not Inventory.add_stack(staged,key,int(q.outputs[key])):
			q.reason=Inventory.stack_failure_reason(staged,key,q.outputs[key])
			return {"quote":q,"player":{}}
	if facility=="guild" and operation=="cancel":staged.guild_contract={}
	if facility=="inn":staged.hp=staged.max_hp;staged.stamina=staged.max_stamina
	return {"quote":q,"player":staged}
static func quote(p:Dictionary,facility:String,operation:String,extra:Dictionary={})->Dictionary:return stage(p,facility,operation,extra).quote
