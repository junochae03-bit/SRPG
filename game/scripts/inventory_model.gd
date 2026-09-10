extends RefCounted

const Content = preload("res://scripts/content.gd")
const WIDTH = 10
const HEIGHT = 12
const CAPACITY = WIDTH * HEIGHT
const MAX_POTIONS = 20
const MAX_MATERIALS = 999999

static func find_item(p: Dictionary, id: String) -> Dictionary:
	for item in all_items(p):
		if item.id==id:return item
	return {}

static func all_items(p: Dictionary) -> Array:
	var result=p.inventory.duplicate()
	if p.potions>0:result.append({"id":"@potion","name":"회복 물약","category":"consumable","bonus":60,"rarity":0,"count":p.potions})
	for key in p.get("materials",{}):
		if p.materials[key]>0:result.append({"id":"@mat:"+key,"name":Content.MATERIALS.get(key,key),"category":"material","bonus":0,"rarity":0,"count":p.materials[key]})
	return result

static func is_equipped(p: Dictionary, id: String) -> bool:
	return p.get("equipment",{}).values().has(id)

static func bag_items(p: Dictionary) -> Array:
	return all_items(p).filter(func(item):return not is_equipped(p,item.id))

static func can_place(p: Dictionary, id: String, at: Vector2i, rotated: bool) -> bool:
	var item=find_item(p,id)
	if item.is_empty() or is_equipped(p,id):return false
	var size_value=Content.item_size(item,rotated)
	var wanted=Rect2i(at,size_value)
	if at.x<0 or at.y<0 or at.x+size_value.x>WIDTH or at.y+size_value.y>HEIGHT:return false
	for other in bag_items(p):
		if other.id==id or not p.bag_positions.has(other.id):continue
		var saved=p.bag_positions[other.id]
		var occupied=Rect2i(Vector2i(saved.x,saved.y),Content.item_size(other,saved.rotated))
		if wanted.intersects(occupied):return false
	return true

static func sort_bag(p:Dictionary)->bool:
	var items=bag_items(p)
	if items.size()>CAPACITY or items.any(func(item):return Content.item_size(item,false)!=Vector2i.ONE):return false
	var category={"weapon":0,"armor":1,"accessory":2,"consumable":3,"material":4}
	items.sort_custom(func(a,b):
		var left=int(category.get(a.get("category",""),5));var right=int(category.get(b.get("category",""),5))
		if left!=right:return left<right
		if int(a.get("rarity",0))!=int(b.get("rarity",0)):return int(a.get("rarity",0))>int(b.get("rarity",0))
		if str(a.name)!=str(b.name):return str(a.name)<str(b.name)
		return str(a.id)<str(b.id))
	var positions={}
	for i in range(items.size()):positions[items[i].id]={"x":i%WIDTH,"y":int(i/WIDTH),"rotated":false}
	p.bag_positions=positions
	return true

static func first_fit(p: Dictionary, id: String) -> Dictionary:
	for rotate in [false]:
		for y in range(HEIGHT):
			for x in range(WIDTH):
				if can_place(p,id,Vector2i(x,y),rotate):return {"x":x,"y":y,"rotated":rotate}
	return {}

static func initialize(p: Dictionary):
	p["equipment"]=p.get("equipment",{})
	for slot in Content.SLOTS:p.equipment[slot]=p.equipment.get(slot,"")
	if p.get("equipped","")!="":p.equipment.weapon=p.equipped
	p["bag_positions"]=p.get("bag_positions",{})
	p["materials"]=p.get("materials",{})
	for item in p.inventory:preload("res://scripts/equipment_catalog.gd").normalize(item,p)
	var valid_ids=[]
	for item in bag_items(p):valid_ids.append(item.id)
	for id in p.bag_positions.keys():
		if not valid_ids.has(id):p.bag_positions.erase(id)
	# Keep valid user placements. Only repair missing or conflicting positions.
	var old=p.bag_positions.duplicate(true)
	p.bag_positions.clear()
	for item in bag_items(p):
		if old.has(item.id):
			var place=old[item.id]
			if can_place(p,item.id,Vector2i(int(place.get("x",-1)),int(place.get("y",-1))),bool(place.get("rotated",false))):
				p.bag_positions[item.id]={"x":int(place.x),"y":int(place.y),"rotated":false}
		if not p.bag_positions.has(item.id):
			var found=first_fit(p,item.id)
			if not found.is_empty():p.bag_positions[item.id]=found

static func move_item(p: Dictionary, id: String, at: Vector2i, rotated: bool) -> bool:
	if not can_place(p,id,at,rotated):return false
	p.bag_positions[id]={"x":at.x,"y":at.y,"rotated":false}
	return true

static func add_gear(p: Dictionary, item: Dictionary) -> bool:
	preload("res://scripts/equipment_catalog.gd").normalize(item,p)
	p.inventory.append(item)
	var place=first_fit(p,item.id)
	if place.is_empty():
		p.inventory.pop_back()
		return false
	p.bag_positions[item.id]=place
	return true

static func equip(p: Dictionary, id: String) -> bool:
	var item=find_item(p,id)
	if item.is_empty() or item.get("category","") not in ["weapon","armor","accessory"]:return false
	var slot=item.get("slot","weapon")
	if not Content.SLOTS.has(slot) or not preload("res://scripts/equipment_catalog.gd").reason(p,item).is_empty():return false
	if p.equipment[slot]==id:return true
	var old=p.equipment[slot]
	var staged=p.duplicate(true)
	staged.equipment[slot]=id
	staged.bag_positions.erase(id)
	if old!="":
		var fit=first_fit(staged,old)
		if fit.is_empty():return false
		staged.bag_positions[old]=fit
	p.equipment=staged.equipment
	p.bag_positions=staged.bag_positions
	p.equipped=p.equipment.weapon
	return true

static func unequip(p: Dictionary, slot: String) -> bool:
	if not p.equipment.has(slot) or p.equipment[slot]=="":return false
	var id=p.equipment[slot]
	var staged=p.duplicate(true)
	staged.equipment[slot]=""
	var fit=first_fit(staged,id)
	if fit.is_empty():return false
	p.equipment[slot]=""
	p.bag_positions[id]=fit
	p.equipped=p.equipment.weapon
	return true

static func stack_limit(kind:String)->int:
	return MAX_POTIONS if kind=="potion" else MAX_MATERIALS if Content.MATERIALS.has(kind) else 0

static func whole_count(value:Variant,maximum:int)->bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=0 and value<=maximum and value==floor(float(value))

static func _stack_quantity_valid(p:Dictionary,kind:String,amount:Variant)->bool:
	var limit=stack_limit(kind)
	if limit<=0 or not whole_count(amount,limit) or amount<=0:return false
	var current=p.get("potions",0) if kind=="potion" else p.get("materials",{}).get(kind,0)
	# 남은 수량과 먼저 비교해 정수 넘침이나 임의 수량 축소를 막습니다.
	return whole_count(current,limit) and int(amount)<=limit-int(current)

static func _stage_stack(p:Dictionary,kind:String,amount:Variant)->Dictionary:
	if not _stack_quantity_valid(p,kind,amount):return {}
	var staged=p.duplicate(true)
	var id="@potion" if kind=="potion" else "@mat:"+kind
	if kind=="potion":
		staged.potions=int(p.potions)+int(amount)
	else:staged.materials[kind]=int(staged.materials.get(kind,0))+int(amount)
	if not staged.bag_positions.has(id):
		var fit=first_fit(staged,id)
		if fit.is_empty():return {}
		staged.bag_positions[id]=fit
	return staged

static func can_add_stack(p:Dictionary,kind:String,amount:Variant)->bool:
	return not _stage_stack(p,kind,amount).is_empty()

static func stack_failure_reason(p:Dictionary,kind:String,amount:Variant)->String:
	var limit=stack_limit(kind)
	if limit<=0 or not (amount is int or amount is float) or not is_finite(float(amount)) or amount<=0 or amount!=floor(float(amount)):return "수량을 확인하세요."
	if not _stack_quantity_valid(p,kind,amount):return ("물약" if kind=="potion" else Content.MATERIALS[kind])+"은 최대 %d개까지 보관할 수 있습니다."%limit
	return "" if can_add_stack(p,kind,amount) else "완성품을 보관할 가방 공간이 필요합니다."

static func add_stack(p:Dictionary,kind:String,amount:Variant)->bool:
	var staged=_stage_stack(p,kind,amount)
	if staged.is_empty():return false
	p.potions=staged.potions
	p.materials=staged.materials
	p.bag_positions=staged.bag_positions
	return true

static func unequip_to(p: Dictionary, slot: String, id: String, at: Vector2i, rotated: bool) -> bool:
	if p.equipment.get(slot,"")!=id or id=="":return false
	var staged=p.duplicate(true)
	staged.equipment[slot]=""
	if not move_item(staged,id,at,rotated):return false
	p.equipment=staged.equipment
	p.bag_positions=staged.bag_positions
	p.equipped=p.equipment.weapon
	return true
