extends "res://tests/coop_network.gd"
const Production=preload("res://scripts/production_queue.gd")
const Craft=preload("res://scripts/exploration_crafting.gd")
func extra_town_check(host:bool):
	if host:
		for p in session.sim.players.values():p.pos=Production.World.FACILITIES.alchemy.pos
		session.refresh();session.publish_snapshot()
	await create_timer(.6).timeout
	var before=session.state.players[session.local_id].duplicate(true)
	var request=JSON.stringify({"facility":"alchemy","operation":"production_start","recipe":"alchemy:ore","mode":"count","quantity":1})
	if host:session.act("facility",request)
	else:
		session.sequence+=1;session.receive_action.rpc_id(1,session.sequence,"facility",request);session.receive_action.rpc_id(1,session.sequence,"facility",request)
	await create_timer(2.3).timeout
	var p=session.state.players[session.local_id]
	check(p.production.queue.size()==1 and p.production.queue[0].reserved,"duplicate reliable enqueue creates one personal order")
	check(p.gold==before.gold-20 and int(p.materials.seed)==int(before.materials.seed)-5,"production reserves one batch once across ENet")
	check(int(p.materials.ore)==int(before.materials.ore),"output not granted before production time")
	check(session.state.players.values().filter(func(other):return other.id!=session.local_id).all(func(other):return not other.has("production")),"other peers never receive private production records")
	var saved=session.save_game();var loaded=session.parse_save(session.save_path())
	check(saved and loaded!=null and loaded.production.queue.size()==1 and loaded.production.queue[0].elapsed>0,"real authoritative checkpoint persists reserved unfinished order")
	var until=Time.get_ticks_msec()+9000
	while Time.get_ticks_msec()<until and not session.state.players[session.local_id].production.queue.is_empty():await create_timer(.1).timeout
	p=session.state.players[session.local_id]
	check(p.production.queue.is_empty() and int(p.materials.ore)==int(before.materials.ore)+3 and p.gold==before.gold-20,"actual host clock delivers exactly one batch to each owner")
	request=JSON.stringify({"facility":"alchemy","operation":"production_start","recipe":"alchemy:ore","mode":"repeat","quantity":1})
	check(session.act("facility",request),"owner starts repeat work")
	await create_timer(.5).timeout
	p=session.state.players[session.local_id]
	if not p.production.queue.is_empty():
		var id=p.production.queue[0].id;request=JSON.stringify({"facility":"alchemy","operation":"production_cancel","order":id})
		if host:session.act("facility",request)
		else:
			session.sequence+=1;session.receive_action.rpc_id(1,session.sequence,"facility",request);session.receive_action.rpc_id(1,session.sequence,"facility",request)
	await create_timer(.6).timeout
	p=session.state.players[session.local_id]
	check(p.production.queue.is_empty() and p.gold==before.gold-20 and p.materials.seed==int(before.materials.seed)-5,"duplicate reliable cancellation refunds exactly the undelivered batch")
	await phase_barrier("production-cancelled")
	# Keep the inherited guild/floor/departure checks; this is a real six-client
	# session rather than six dictionaries in one simulation.

	await equipment_crafting_check(host)
	print("PRODUCTION_NETWORK_WORK ",options.role," failures=",failures.size())

func equipment_crafting_check(host:bool):
	if host:
		for p in session.sim.players.values():
			p.level=100;p.pos=Production.World.FACILITIES.smith.pos;p.gold=100000
			var key=Craft.Data.recipes().keys().filter(func(id):return Craft.Data.recipes()[id].job==p.class_id and int(Craft.Data.recipes()[id].rarity)==3)[0]
			for material in Craft.Data.recipes()[key].materials:Production.Inventory.add_stack(p,material,99-int(p.materials.get(material,0)))
		session.refresh();session.publish_snapshot()
	await create_timer(1.).timeout
	var p=session.state.players[session.local_id]
	var key=Craft.Data.recipes().keys().filter(func(id):return Craft.Data.recipes()[id].job==p.class_id and int(Craft.Data.recipes()[id].rarity)==3)[0]
	var before=p.duplicate(true);var quote=Craft.quote(p,key)
	check(quote.reason.is_empty(),"network crafting has valid personal ingredients")
	var request=JSON.stringify({"facility":"smith","operation":"craft_equipment","recipe":key})
	if host:check(session.act("facility",request),"host crafts own equipment")
	else:
		session.sequence+=1;session.receive_action.rpc_id(1,session.sequence,"facility",request);session.receive_action.rpc_id(1,session.sequence,"facility",request)
	await create_timer(1.5).timeout
	p=session.state.players[session.local_id]
	check(p.inventory.size()==before.inventory.size()+1 and p.gold==before.gold-quote.cost,"duplicate craft RPC grants exactly one item and charge")
	var item=p.inventory.back();check(item.rarity==3 and item.resonance==quote.item.resonance,"network craft matches quoted epic option")
	for material in quote.materials:check(p.materials[material]==before.materials[material]-quote.materials[material],"network ingredient charge once "+material)
	var saved=session.save_game();var restored=session.parse_save(session.save_path())
	check(saved and restored!=null and restored.inventory.any(func(gear):return gear.id==item.id),"crafted equipment survives authoritative save")
	check(restored!=null and restored.inventory.any(func(gear):return gear.id==item.id and gear.get("special_stats",[])==item.get("special_stats",[])),"confirmed equipment options survive network save")
	await phase_barrier("equipment-saved")
	if host:
		for actor in session.sim.players.values():actor.pos=Production.World.FACILITIES.alchemy.pos
		session.refresh();session.publish_snapshot()
	await create_timer(.6).timeout

func phase_barrier(phase:String):
	var marker=FileAccess.open(options.directory.path_join(phase),FileAccess.WRITE)
	marker.store_string("ready");marker.close()
	var deadline=Time.get_ticks_msec()+8000
	while Time.get_ticks_msec()<deadline and not range(6).all(func(index):return FileAccess.file_exists(options.directory.get_base_dir().path_join(str(index)+"/"+phase))):await create_timer(.05).timeout
	check(range(6).all(func(index):return FileAccess.file_exists(options.directory.get_base_dir().path_join(str(index)+"/"+phase))),"all peers observed phase "+phase)
