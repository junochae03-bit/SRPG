extends SceneTree
const Loot=preload("res://scripts/loot_tables.gd")
const Simulation=preload("res://scripts/simulation.gd")
const Inventory=preload("res://scripts/inventory_model.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run():
	var loot=Loot.new();var rng=RandomNumberGenerator.new();rng.seed=9401
	for kind in loot.tables:
		var counts={};var multiple=0;var trials=50000
		for entry in loot.tables[kind]:counts[entry.key]=0;check(entry.chance>=0 and entry.chance<=1,"valid chance "+kind+entry.key)
		for i in range(trials):
			var rolled=loot.roll(kind,rng)
			if rolled.size()>1:multiple+=1
			for entry in rolled:counts[entry.key]+=1
		for entry in loot.tables[kind]:
			var expected=trials*entry.chance
			var tolerance=maxf(2,6*sqrt(trials*entry.chance*(1-entry.chance)))
			check(absf(counts[entry.key]-expected)<=tolerance,"sample rate within six sigma "+kind+entry.key)
		check(multiple>0,"independent entries allow simultaneous drops "+kind)
		print("DROP_SAMPLE ",kind," ",JSON.stringify(counts))
	var a=RandomNumberGenerator.new();a.seed=74;var b=RandomNumberGenerator.new();b.seed=74
	var same=true
	for i in range(100):same=same and loot.roll("shade",a)==loot.roll("shade",b)
	check(same,"seed replay reproduces all rolls")
	check(loot.roll("unknown",a).is_empty(),"unknown monster has no drop table")
	loot.tables.test=[{"key":"never","chance":0.0},{"key":"always","chance":1.0}]
	var boundary=true
	for i in range(100):boundary=boundary and loot.roll("test",a)==[loot.tables.test[1]]
	check(boundary,"zero and certain probability boundaries")
	var sim=Simulation.new();var p=sim.add_player(1,"전리품 검증");p.pos=Vector2(sim.map.rooms[1]);p.potions=19
	sim.drops["p"]={"owner":1,"pos":p.pos,"expires":99,"item":{"id":"p","name":"회복 물약","category":"consumable","rarity":0,"amount":3}}
	check(sim.action(1,"interact") and p.potions==20 and sim.drops.p.item.amount==2,"partial potion pickup keeps excess on ground")
	check(not sim.action(1,"interact") and sim.drops.p.item.amount==2,"full stack cannot consume remaining drop")
	p.potions=18;check(sim.action(1,"interact") and p.potions==20 and sim.drops.is_empty(),"remaining potion stack collected exactly once")
	for i in range(59):Inventory.add_gear(p,{"id":"fill-"+str(i),"name":"test","category":"accessory","slot":"accessory","rarity":0,"bonus":1})
	sim.drops["seed"]={"owner":1,"pos":p.pos,"expires":99,"item":{"id":"seed","name":"별씨앗","category":"material","material":"seed","rarity":0,"amount":2}}
	check(not sim.action(1,"interact") and sim.drops.has("seed") and not p.materials.has("seed"),"new material at full capacity remains on ground")
	sim.action(1,"discard","fill-0");check(sim.action(1,"interact") and p.materials.seed==2,"freed cell accepts material stack")
	check(Inventory.add_stack(p,"seed",5) and p.materials.seed==7,"existing material stack grows in full bag")
	check(not Inventory.add_stack(p,"seed",-3) and p.materials.seed==7,"negative stack rejected")
	check(not Inventory.add_stack(p,"unknown",1),"unknown material rejected")
	var boss=sim.enemies.values().back();sim.kill(1,boss)
	var ids=[];var valid=true
	for drop in sim.drops.values():
		valid=valid and not ids.has(drop.item.id) and sim.map.walkable(drop.pos);ids.append(drop.item.id)
	check(valid,"multi-drop ids unique and spawn on walkable ground")
	check(sim.drops.values().any(func(d):return d.item.category=="weapon" and d.item.rarity==2),"boss guarantees rare weapon")
	check(sim.drops.values().any(func(d):return d.item.get("material","")=="ore" and d.item.amount==3),"boss guarantees three ore")
	print("LOOT_V04_TESTS checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
