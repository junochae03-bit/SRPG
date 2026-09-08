extends SceneTree

const Inventory = preload("res://scripts/inventory_model.gd")
const Content = preload("res://scripts/content.gd")
var checks=0
var failures=0

func _initialize():run.call_deferred()

func check(value: bool, description: String):
	checks+=1
	if not value:
		failures+=1
		push_error("FAIL: "+description)

func gear(id: String, weapon: String) -> Dictionary:
	return {"id":id,"name":weapon,"weapon_type":weapon,"category":"weapon","slot":"weapon","bonus":2,"rarity":0}

func run():
	var p={"inventory":[gear("sword","sword"),gear("bow","bow")],"potions":5,"equipped":"","materials":{}}
	Inventory.initialize(p)
	check(p.bag_positions.size()==3,"legacy gear and potion stack get positions")
	check(Content.item_size(p.inventory[0])==Vector2i.ONE,"sword occupies one cell")
	check(Content.item_size(p.inventory[1],true)==Vector2i.ONE,"bow occupies one cell even with legacy rotation flag")
	var old=p.bag_positions.sword.duplicate()
	check(not Inventory.move_item(p,"sword",Vector2i(10,0),false),"right edge rejects item")
	check(p.bag_positions.sword==old,"rejected move preserves position")
	var bow=p.bag_positions.bow
	check(not Inventory.move_item(p,"sword",Vector2i(bow.x,bow.y),false),"occupied cells reject overlap")
	check(Inventory.move_item(p,"bow",Vector2i(4,3),true),"weapon fits one free cell")
	check(Inventory.equip(p,"bow") and p.equipped=="bow","weapon equipment slot works")
	check(not p.bag_positions.has("bow"),"equipped weapon no longer takes bag space")
	check(not Inventory.move_item(p,"bow",Vector2i(6,0),false),"equipped item cannot also move into grid")
	check(Inventory.equip(p,"sword") and p.bag_positions.has("bow"),"swap returns old weapon to bag")
	check(Inventory.unequip(p,"weapon") and p.equipped=="","unequip returns item to a free position")
	check(Inventory.add_stack(p,"seed",4),"new material stack fits")
	var seed_position=p.bag_positions["@mat:seed"].duplicate()
	check(Inventory.add_stack(p,"seed",7) and p.materials.seed==11,"materials merge into one stack")
	check(p.bag_positions["@mat:seed"]==seed_position,"stack merge preserves grid placement")
	check(not Inventory.add_stack(p,"potion",100) and p.potions==5,"oversized potion addition fails without loss")
	check(Inventory.add_stack(p,"potion",15) and p.potions==20,"exact potion capacity accepted")
	check(not Inventory.add_stack(p,"potion",1),"full potion stack rejects additional pickup")
	var q={"inventory":[],"potions":5,"equipped":"legacy-0"}
	for i in range(12):q.inventory.append({"id":"legacy-"+str(i),"name":"기존 무기","bonus":5,"rarity":1})
	Inventory.initialize(q)
	check(q.inventory.size()==12 and q.equipment.weapon=="legacy-0","old twelve-item save retains gear and equipped id")
	check(q.bag_positions.size()==12,"all eleven bag weapons and potion stack fit after migration")
	var full={"inventory":[gear("equipped","bow")],"potions":0,"equipped":"equipped"}
	Inventory.initialize(full)
	for i in range(60):
		check(Inventory.add_gear(full,{"id":"ring-"+str(i),"name":"반지","category":"accessory","slot":"accessory","bonus":1,"rarity":0}),"fill cell "+str(i))
	check(not Inventory.unequip(full,"weapon") and full.equipped=="equipped","full bag prevents equipment loss on unequip")
	check(not Inventory.add_gear(full,gear("overflow","axe")) and full.inventory.size()==61,"failed pickup leaves ownership unchanged")
	var saved=var_to_bytes(full)
	check(not Inventory.move_item(full,"ring-0",Vector2i(-1,0),false) and var_to_bytes(full)==saved,"negative placement is atomic")
	print("INVENTORY_GRID_TESTS checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
