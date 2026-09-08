extends RefCounted

const Content = preload("res://scripts/content.gd")
const WIDTH = 10
const HEIGHT = 6
const MAX_POTIONS = 20

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
	for item in p.inventory:Content.normalize_item(item)
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
	Content.normalize_item(item)
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
	if not Content.SLOTS.has(slot):return false
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

static func add_stack(p: Dictionary, kind: String, amount: int) -> bool:
	if amount<=0 or (kind!="potion" and not Content.MATERIALS.has(kind)):return false
	var staged=p.duplicate(true)
	var id="@potion" if kind=="potion" else "@mat:"+kind
	if kind=="potion":
		if p.potions+amount>MAX_POTIONS:return false
		staged.potions=p.potions+amount
	else:staged.materials[kind]=int(staged.materials.get(kind,0))+amount
	if not staged.bag_positions.has(id):
		var fit=first_fit(staged,id)
		if fit.is_empty():return false
		staged.bag_positions[id]=fit
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
