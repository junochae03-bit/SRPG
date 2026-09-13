extends RefCounted
const Data=preload("res://scripts/exploration_crafting_data.gd")
const Inventory=preload("res://scripts/inventory_model.gd")
static func roll(floor_number:int,event:String,rng:RandomNumberGenerator,excluded:Array=[])->Dictionary:
	var result={}
	if floor_number<1 or floor_number>100:return result
	for row in Data.catalog().acquisition:
		if row.event!=event or floor_number<int(row.floor_min) or floor_number>int(row.floor_max) or row.material_id in excluded:continue
		if rng.randf()>=float(row.chance):continue
		result[row.material_id]=int(result.get(row.material_id,0))+rng.randi_range(int(row.amount_min),int(row.amount_max))
	return result
static func enemy(sim,p:Dictionary,e:Dictionary):
	if e.get("training",false) or p.get("network_leaving",false) or sim.map.floor_number<=0:return
	var event="raid_clear" if e.get("raid",false) else "guardian_kill" if e.get("guardian",false) else "elite_kill" if e.get("elite",false) else "normal_kill"
	var rewards=roll(sim.map.floor_number,event,sim.rng,e.get("species_drop_materials",[]))
	for key in rewards:
		sim.serial+=1;var id="exploration-"+str(Time.get_ticks_usec())+"-"+str(sim.serial)
		var item={"id":id,"name":Data.materials()[key].name,"category":"material","material":key,"amount":rewards[key],"bonus":0,"rarity":int(Data.materials()[key].rarity)}
		sim.drops[id]={"item":item,"pos":sim.map.move(e.pos,Vector2.from_angle(sim.serial*2.399)*.4),"owner":p.id,"expires":sim.clock+300.}
static func site_rewards(sim,p:Dictionary,site:Dictionary,event:String)->Dictionary:
	# A failed bag transaction must not reroll a collectible on each retry.
	var rng=RandomNumberGenerator.new();rng.seed=hash(str(sim.map.seed_value)+":"+str(sim.map.floor_number)+":"+str(p.id)+":"+str(site.id)+":"+event)
	return roll(sim.map.floor_number,event,rng)
static func stage_site(sim,p:Dictionary,site:Dictionary,event:String)->String:
	var rewards=site_rewards(sim,p,site,event)
	for key in rewards:
		var amount=rewards[key]
		if not Inventory.add_stack(p,key,amount):return Inventory.stack_failure_reason(p,key,amount)
	return ""
