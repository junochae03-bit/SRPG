extends SceneTree
const Craft=preload("res://scripts/exploration_crafting.gd")
const Rewards=preload("res://scripts/exploration_material_rewards.gd")
const Sim=preload("res://scripts/simulation.gd")
var checks=0
var failures=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func run():
	var sim=Sim.new(841,"town");var p=sim.add_player(1,"제작 검사")
	p.level=100;p.pos=preload("res://scripts/world_catalog.gd").FACILITIES.smith.pos
	check(Craft.Data.materials().size()>=60,"all exploration materials registered")
	for key in Craft.Data.materials():
		check(Craft.Content.MATERIALS[key]==Craft.Data.materials()[key].name and Craft.Inventory.stack_limit(key)==99,"name and stack contract "+key)
	for key in Craft.Data.recipes():
		var row=Craft.Data.recipes()[key];p.inventory=[];p.materials={};p.bag_positions={};p.gold=1000000;p.class_id=row.job
		for material in row.materials:check(Craft.Inventory.add_stack(p,material,99),"prepare ingredient "+key)
		var before=p.duplicate(true);var q=Craft.quote(p,key)
		check(q.reason.is_empty() and p==before,"quote is valid and pure "+key)
		check(sim.action(1,"facility",JSON.stringify({"facility":"smith","operation":"craft_equipment","recipe":key})),"real facility craft "+key)
		check(p.inventory.size()==1 and p.inventory[0].rarity==int(row.rarity) and p.inventory[0].upgrade==0 and p.gold==before.gold-int(row.gold),"one output and exact cost "+key)
		check(p.inventory[0].get("resonance","")==q.item.get("resonance","") and Craft.item(row,"different-instance").get("resonance","")==q.item.get("resonance",""),"preview and output resonance match "+key)
		for material in row.materials:check(p.materials[material]==99-int(row.materials[material]),"exact ingredients "+key)
	var selected=Craft.Data.recipes().keys()[0];var recipe=Craft.Data.recipes()[selected]
	p.inventory=[];p.bag_positions={};p.materials={};p.gold=1000000;p.class_id=recipe.job
	for key in recipe.materials:Craft.Inventory.add_stack(p,key,99)
	Craft.Inventory.initialize(p)
	while Craft.Inventory.bag_items(p).size()<Craft.Inventory.CAPACITY:
		var id="full-"+str(p.inventory.size());Craft.Inventory.add_gear(p,Craft.Equipment.make("sword",0,0,id,"none",p.class_id))
	var before=p.duplicate(true)
	check(not Craft.quote(p,selected).reason.is_empty() and not Craft.use(sim,p,{"facility":"smith","operation":"craft_equipment","recipe":selected}) and p==before,"full bag rejects without any cost")
	p.inventory=[];p.bag_positions={};p.class_id="mage" if recipe.job!="mage" else "warrior"
	check(not Craft.quote(p,selected).reason.is_empty(),"wrong class cannot craft locked equipment")
	var rng=RandomNumberGenerator.new();rng.seed=555
	for floor_id in range(1,101):
		var raid=Rewards.roll(floor_id,"raid_clear",rng)
		check(raid.values().reduce(func(total,amount):return total+amount,0)>=2,"raid guaranteed core "+str(floor_id))
		for material in raid:check(int(Craft.Data.materials()[material].tier)==int((floor_id-1)/10),"floor keeps region material")
	check(Rewards.roll(0,"normal_kill",rng).is_empty(),"tutorial has no dungeon material rolls")
	var site={"id":"gather-test"};sim.map.floor_number=1
	check(Rewards.site_rewards(sim,p,site,"gather")==Rewards.site_rewards(sim,p,site,"gather"),"failed collection cannot reroll material amounts")
	print("EXPLORATION_CRAFTING_V071 checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
