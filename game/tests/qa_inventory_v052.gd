extends SceneTree
const I=preload("res://scripts/inventory_model.gd")
const C=preload("res://scripts/content.gd")
const E=preload("res://scripts/equipment_catalog.gd")
const Sim=preload("res://scripts/simulation.gd")
const Local=preload("res://scripts/local_session.gd")
const Operations=preload("res://scripts/town_operations.gd")
const Quote=preload("res://scripts/service_quote.gd")
const World=preload("res://scripts/world_catalog.gd")
var checks=0
var failures=[]
var directory=""
var saved_index=0
func _initialize():run.call_deferred()
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures.append(message);push_error(message)
func blank(p:Dictionary):
	p.inventory=[];p.equipment={};p.equipped="";p.bag_positions={};p.materials={};p.potions=0;I.initialize(p)
func roundtrip(sim,name:String):
	var data=sim.persistent(1);data.world_seed=20260910
	var local=Local.new();var path=directory+"/case-%d.json"%saved_index;saved_index+=1
	check(local.write_save(data,path),"write boundary save "+name)
	var restored=local.parse_save(path)
	check(restored!=null and restored.materials==data.materials,"parse exact boundary save "+name);local.free()
func fixture()->Dictionary:
	var sim=Sim.new(20260910,"town");var p=sim.add_player(1,"수량 검증");blank(p)
	p.gold=10000;p.materials={"seed":100,"ore":100,"essence":10};I.initialize(p);return {"sim":sim,"p":p}
func request(sim,p,facility:String,operation:String,extra:Dictionary={})->bool:
	var value=extra.duplicate(true);value.merge({"facility":facility,"operation":operation})
	return sim.action(p.id,"facility",JSON.stringify(value))
func cap_and_quantity():
	var local=Local.new();root.add_child(local);local.set_physics_process(false);local.save_directory=directory+"/session";local.start_game("재료 저장 검증",1)
	check(local.connected,"real local session starts")
	var p=local.sim.players[1];blank(p)
	for kind in C.MATERIALS:
		check(I.add_stack(p,kind,I.MAX_MATERIALS),"exact material cap accepted "+kind)
		check(local.save_game() and local.parse_save(local.save_path())!=null,"material cap survives real save/load "+kind)
		var before=var_to_bytes(p)
		check(not I.can_add_stack(p,kind,1) and var_to_bytes(p)==before,"read-only cap check rejects +1 "+kind)
		check(not I.add_stack(p,kind,1) and var_to_bytes(p)==before,"rejected +1 preserves complete player "+kind)
		check(I.stack_failure_reason(p,kind,1).contains(str(I.MAX_MATERIALS)),"material limit reason reports actual cap "+kind)
		check(local.save_game() and local.parse_save(local.save_path())!=null,"failed overflow cannot poison subsequent save "+kind)
	var probe=p.duplicate(true);probe.materials.ore=I.MAX_MATERIALS-1
	var before=var_to_bytes(probe)
	check(I.can_add_stack(probe,"ore",1.0) and var_to_bytes(probe)==before,"whole JSON numeric quantity checked without mutation")
	check(I.add_stack(probe,"ore",1.0) and probe.materials.ore==I.MAX_MATERIALS,"integral numeric quantity retains exact value")
	for kind in ["potion","ore"]:
		probe=p.duplicate(true);probe.potions=0;probe.materials.ore=0;I.initialize(probe);before=var_to_bytes(probe)
		for amount in [0,-1,1.25,"1",true,false,INF,NAN,1e18,9223372036854775807]:
			check(not I.can_add_stack(probe,kind,amount) and var_to_bytes(probe)==before,"invalid quantity cannot be coerced by preview "+kind+":"+str(amount))
			check(not I.add_stack(probe,kind,amount) and var_to_bytes(probe)==before,"invalid quantity cannot be coerced by addition "+kind+":"+str(amount))
	probe=p.duplicate(true);before=var_to_bytes(probe)
	check(not I.can_add_stack(probe,"unknown",1) and not I.add_stack(probe,"unknown",1) and var_to_bytes(probe)==before,"unknown stack never mutates player")
	for current in [-1,.25,I.MAX_MATERIALS+1]:
		probe=p.duplicate(true);probe.materials.ore=current;before=var_to_bytes(probe)
		check(not I.can_add_stack(probe,"ore",1) and not I.add_stack(probe,"ore",1) and var_to_bytes(probe)==before,"invalid existing material count is not silently normalized "+str(current))
	local.disconnect_game();local.queue_free()
func transactions():
	for pair in [["alchemy","ore","ore",I.MAX_MATERIALS-1],["alchemy","essence","essence",I.MAX_MATERIALS],["guild","claim","essence",I.MAX_MATERIALS],["smith","salvage","essence",I.MAX_MATERIALS]]:
		var f=fixture();var p=f.p;p.pos=World.FACILITIES[pair[0]].pos;p.materials[pair[2]]=pair[3]
		var extra={"quantity":1}
		if pair[1]=="claim":p.guild_contract={"zone":"forest","progress":10,"target":10}
		if pair[1]=="salvage":
			var item=E.make("head",0,2,"cap-salvage","vigor","warrior");check(I.add_gear(p,item),"salvage fixture gear owned");extra.item=item.id
		I.initialize(p);var before=var_to_bytes(p)
		var quote=Quote.quote(p,pair[0],pair[1],extra)
		check(not quote.reason.is_empty() and var_to_bytes(p)==before,"overflow quote is denied and read-only "+pair[1])
		if Operations.handles(pair[0],pair[1]):
			var staged=Operations.stage(p,pair[0],pair[1],extra)
			check(staged.player.is_empty() and not staged.quote.reason.is_empty() and var_to_bytes(p)==before,"overflow stage publishes no partial result "+pair[1])
		check(not request(f.sim,p,pair[0],pair[1],extra) and var_to_bytes(p)==before,"overflow transaction keeps gold inputs gear contract and placement "+pair[1])
		roundtrip(f.sim,pair[1]+" rejected")
	# 광석을 먼저 만든 뒤 정수에서 실패해도 원본 장비와 광석이 모두 보존됩니다.
	var f=fixture();var p=f.p;p.pos=World.FACILITIES.alchemy.pos;p.materials.ore=I.MAX_MATERIALS-3;p.materials.seed=5;p.gold=20;I.initialize(p)
	var before=var_to_bytes(p);var quote=Quote.quote(p,"alchemy","ore",{"quantity":1})
	check(quote.reason.is_empty() and var_to_bytes(p)==before,"exact-cap recipe preview remains available")
	check(request(f.sim,p,"alchemy","ore",{"quantity":1}) and p.gold==0 and p.materials.seed==0 and p.materials.ore==I.MAX_MATERIALS,"exact-cap recipe exchanges full displayed amounts")
	roundtrip(f.sim,"exact recipe")
	f=fixture();p=f.p
	for facility in ["shop","alchemy"]:
		p.pos=World.FACILITIES[facility].pos;before=var_to_bytes(p)
		for amount in [1.25,"1",true,null,INF,NAN,-1]:
			var staged=Operations.stage(p,facility,"potion",{"quantity":amount})
			check(staged.player.is_empty() and not staged.quote.reason.is_empty() and var_to_bytes(p)==before,"service quantity is not rounded or coerced "+facility+":"+str(amount))
func pickup_and_capacity():
	var sim=Sim.new(20260910);var p=sim.add_player(1,"획득 경계");blank(p);p.pos=Vector2(sim.map.rooms[1])
	check(I.add_stack(p,"ore",I.MAX_MATERIALS-1),"nearly full material fixture")
	sim.drops.cap={"owner":1,"pos":p.pos,"expires":99,"item":{"id":"cap","name":"광석","category":"material","material":"ore","rarity":0,"amount":2}}
	var before=var_to_bytes(p);var ground=var_to_bytes(sim.drops)
	check(not sim.action(1,"interact") and var_to_bytes(p)==before and var_to_bytes(sim.drops)==ground,"overflow ground drop remains whole and uncollected")
	sim.drops.cap.item.amount=1
	check(sim.action(1,"interact") and p.materials.ore==I.MAX_MATERIALS and sim.drops.is_empty(),"exact-cap ground pickup accepted once")
	roundtrip(sim,"ground pickup")
	p.materials.ore=I.MAX_MATERIALS-1
	for index in range(I.CAPACITY-I.bag_items(p).size()):check(I.add_gear(p,E.make("head",0,0,"cap-fill-%d"%index,"none","warrior")),"fill capacity "+str(index))
	check(I.bag_items(p).size()==I.CAPACITY,"capacity fixture is actually full")
	before=var_to_bytes(p)
	check(not I.can_add_stack(p,"seed",1) and not I.add_stack(p,"seed",1) and var_to_bytes(p)==before,"new stack fails full-grid checks atomically")
	check(I.can_add_stack(p,"ore",1) and var_to_bytes(p)==before,"existing stack below cap needs no new slot")
	check(I.add_stack(p,"ore",1) and p.materials.ore==I.MAX_MATERIALS and p.bag_positions.size()==I.CAPACITY,"existing stack reaches cap without changing occupancy")
	before=var_to_bytes(p);check(not I.can_add_stack(p,"ore",1) and not I.add_stack(p,"ore",1) and var_to_bytes(p)==before,"existing full-grid stack still observes quantity cap")
func run():
	directory=ProjectSettings.globalize_path("res://../runtime/qa-inventory-v052/"+str(Time.get_ticks_usec()));DirAccess.make_dir_recursive_absolute(directory)
	cap_and_quantity();transactions();pickup_and_capacity()
	var file=FileAccess.open("res://../artifacts/qa-inventory-v052.json",FileAccess.WRITE);file.store_string(JSON.stringify({"suite":"qa_inventory_v052","checks":checks,"failures":failures},"\t"));file.close()
	await process_frame;print("QA_INVENTORY_V052 checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
