extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Quote=preload("res://scripts/service_quote.gd")
const I=preload("res://scripts/inventory_model.gd")
const E=preload("res://scripts/equipment_catalog.gd")
const W=preload("res://scripts/world_catalog.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func operation(sim,p,facility:String,kind:String,extra:Dictionary={})->bool:
	p.pos=W.FACILITIES[facility].pos
	var payload=extra.duplicate();payload.merge({"facility":facility,"operation":kind})
	return sim.action(1,"facility",JSON.stringify(payload))
func run():
	var sim=Sim.new(20260910,"town");var p=sim.add_player(1,"서비스 검증")
	p.gold=10000;p.materials={"seed":100,"ore":100,"essence":10};p.potions=0;I.initialize(p)
	var q=Quote.quote(p,"shop","potion",{"quantity":10});check(q.cost==150 and q.outputs.potion==10,"batch price and output visible")
	check(operation(sim,p,"shop","potion",{"quantity":10}) and p.potions==10 and p.gold==9850,"actual ten potion purchase")
	var before=sim.persistent(1).duplicate(true)
	check(not operation(sim,p,"shop","potion",{"quantity":-5}) and sim.persistent(1)==before,"negative quantity rejected atomically")
	check(not operation(sim,p,"alchemy","potion",{"quantity":5}) and sim.persistent(1)==before,"overflow craft charges no gold or materials")
	check(operation(sim,p,"alchemy","potion",{"quantity":3}) and p.potions==19 and p.gold==9820 and p.materials.seed==91,"nine potion craft exact exchange")
	p.hp=20;p.stamina=5;q=Quote.quote(p,"inn","resupply")
	check(q.cost==25 and q.outputs.potion==1,"inn charges only missing potions and rest")
	check(operation(sim,p,"inn","resupply") and p.potions==20 and p.hp==p.max_hp and p.stamina==p.max_stamina,"inn restores and resupplies")
	var old_gold=p.gold;var old_ore=p.materials.ore
	check(operation(sim,p,"alchemy","ore",{"quantity":5}) and p.materials.ore==old_ore+15 and p.gold==old_gold-100,"bulk ore transmutation")
	var seeds=p.materials.seed;old_ore=p.materials.ore;old_gold=p.gold
	check(operation(sim,p,"guild","supply") and p.materials.seed==seeds-10 and p.materials.ore==old_ore-5 and p.gold==old_gold+300,"guild supply consumes displayed ingredients for reward")
	check(operation(sim,p,"guild","accept",{"zone":"forest"}),"accept normal contract")
	p.guild_contract.progress=4
	check(operation(sim,p,"guild","cancel") and p.guild_contract.is_empty(),"abandon contract explicitly")
	var gear=E.make("head",0,2,"salvage-one","vigor","warrior");gear.upgrade=3;I.add_gear(p,gear)
	q=Quote.quote(p,"smith","salvage",{"item":gear.id});check(q.outputs.ore==8 and q.outputs.essence==1,"salvage grade/upgrade preview")
	old_ore=p.materials.ore;var old_essence=p.materials.essence
	check(operation(sim,p,"smith","salvage",{"item":gear.id}) and I.find_item(p,gear.id).is_empty() and p.materials.ore==old_ore+8 and p.materials.essence==old_essence+1,"salvage exchanges only selected equipment")
	gear=E.make("sword",0,1,"keep-equipped","focus","warrior");I.add_gear(p,gear);I.equip(p,gear.id);before=sim.persistent(1).duplicate(true)
	check(not operation(sim,p,"smith","salvage",{"item":gear.id}) and sim.persistent(1)==before,"worn equipment protected")
	p.gold=0;p.materials={"seed":0,"ore":0,"essence":0};before=sim.persistent(1).duplicate(true)
	for pair in [["alchemy","ore"],["alchemy","essence"],["shop","potion"],["inn","resupply"],["guild","supply"]]:
		check(not operation(sim,p,pair[0],pair[1]) and sim.persistent(1)==before,"insufficient resources atomic "+str(pair))
	# Far-away service requests are rejected before staging.
	p.gold=100;p.potions=0;p.pos=sim.map.spawn
	var request={"facility":"shop","operation":"potion","quantity":5}
	check(not sim.action(1,"facility",JSON.stringify(request)),"merchant requires physical proximity")
	# Save round-trip validates new service outcomes with the existing save schema.
	var path=ProjectSettings.globalize_path("res://../runtime/town-v052-test.json");var file=FileAccess.open(path,FileAccess.WRITE);var saved=sim.persistent(1);saved.world_seed=20260910;file.store_string(JSON.stringify(saved));file.close()
	var local=preload("res://scripts/local_session.gd").new();var restored=local.parse_save(path)
	check(restored!=null and restored.gold==p.gold and restored.materials==p.materials,"service results survive normal save parsing");local.free()
	inventory_edge_cases()
	print("TOWN_SERVICES_V052 checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)

func inventory_edge_cases():
	# One freed gear cell cannot fit two new material stacks. The first output
	# succeeds on the staging copy, then the second must roll the entire trade back.
	var sim=Sim.new(20260910,"town");var p=sim.add_player(1,"보관 검증")
	p.inventory=[];p.equipment={};p.equipped="";p.bag_positions={};p.potions=0;p.materials={"seed":0,"ore":0,"essence":0};p.gold=100
	I.initialize(p)
	for index in range(I.CAPACITY):check(I.add_gear(p,E.make("head",0,2 if index==0 else 0,"full-bag-%d"%index,"none","warrior")),"fill salvage boundary cell %d"%index)
	var before=sim.persistent(1).duplicate(true)
	var preview=Quote.quote(p,"smith","salvage",{"item":"full-bag-0"})
	check(preview.outputs.size()==2 and not preview.reason.is_empty(),"two-stack salvage quote rejects one available cell")
	check(sim.persistent(1)==before,"failed two-output quote is read-only")
	check(not operation(sim,p,"smith","salvage",{"item":"full-bag-0"}) and sim.persistent(1)==before,"second salvage output failure preserves gear gold materials and placements")
	# Consuming both final ingredient stacks frees their cells before the new
	# essence stack is allocated, even though the bag was full before crafting.
	sim=Sim.new(20260911,"town");p=sim.add_player(1,"조제 검증")
	p.inventory=[];p.equipment={};p.equipped="";p.bag_positions={};p.potions=0;p.materials={"seed":5,"ore":5,"essence":0};p.gold=100
	I.initialize(p)
	for index in range(I.CAPACITY-2):check(I.add_gear(p,E.make("head",0,0,"craft-bag-%d"%index,"none","warrior")),"fill craft boundary cell %d"%index)
	check(p.bag_positions.size()==I.CAPACITY,"full craft fixture includes two ingredient cells")
	preview=Quote.quote(p,"alchemy","essence",{"quantity":1})
	check(preview.reason.is_empty(),"quote reuses fully consumed ingredient cells")
	check(operation(sim,p,"alchemy","essence",{"quantity":1}) and p.gold==60 and p.materials.seed==0 and p.materials.ore==0 and p.materials.essence==1,"full-bag craft consumes exact final ingredients and succeeds")
	check(p.inventory.size()==I.CAPACITY-2 and p.bag_positions.size()==I.CAPACITY-1 and not p.bag_positions.has("@mat:seed") and not p.bag_positions.has("@mat:ore") and p.bag_positions.has("@mat:essence"),"craft preserves all gear and transfers output into freed storage")
