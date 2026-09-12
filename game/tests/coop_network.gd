extends SceneTree
var session
var options={}
var failures=[]
var game
class ProbeSession extends "res://scripts/coop_session.gd":
	var block_save=false
	var block_checkpoints=false
	func write_save(data:Dictionary,path:String)->bool:
		return false if block_save else super.write_save(data,path)
	func publish_checkpoints():
		if not block_checkpoints:super.publish_checkpoints()
func check(ok:bool,message:String):
	if not ok:failures.append(message);printerr(message)
func _initialize():run.call_deferred()
func run():
	for arg in OS.get_cmdline_user_args():
		var pair=arg.trim_prefix("--").split("=",true,1);options[pair[0]]=pair[1]
	if options.get("visual","")=="true":
		game=load("res://main.tscn").instantiate();game.options.mute=true;root.add_child(game);session=game.session
	else:
		session=ProbeSession.new();session.name="Session";root.add_child(session)
	session.save_directory=options.directory
	var sim=preload("res://scripts/simulation.gd").new(531,"town");var p=sim.add_player(1,"연결 검사")
	p.level=100;p.gold=1000;p.tutorial_done=true;sim.recalculate(p)
	preload("res://scripts/inventory_model.gd").add_stack(p,"mana_potion",3);preload("res://scripts/inventory_model.gd").add_stack(p,"power_potion",3)
	var data=sim.persistent(1);data.world_seed=531
	check(session.write_save(data,session.save_path()),"isolated fixture saved")
	var host=options.role=="host"
	check(session.host_room(1,int(options.port)) if host else session.join_room("127.0.0.1",1,int(options.port)),"connection request")
	if options.role=="overflow":
		var deadline=Time.get_ticks_msec()+15000
		while Time.get_ticks_msec()<deadline and session.network_role!="offline":await create_timer(.1).timeout
		check(not session.connected and session.network_role=="offline","seventh player cannot enter full room")
		print("COOP_NETWORK overflow failures=",failures.size());session.queue_free();await process_frame;quit(0 if failures.is_empty() else 1);return
	if host:print("HOST_READY")
	var until=Time.get_ticks_msec()+22000
	while Time.get_ticks_msec()<until and (not session.connected or session.state.players.size()<6):await create_timer(.1).timeout
	check(session.connected and session.state.players.size()==6,"six real peers share world")
	if session.connected and session.state.players.size()==6:
		if host:
			print("SIX_READY")
			check(not session.enter_floor(1) and session.sim.map.zone=="town","unready party cannot travel")
		var before_clock=session.state.clock;session.paused=true
		if not host:
			var before=int(session.state.players[session.local_id].stats.strength)
			session.receive_action.rpc_id(1,100,"stat","strength")
			session.receive_action.rpc_id(1,100,"stat","strength")
			session.sequence=100
			await create_timer(1.).timeout
			check(int(session.state.players[session.local_id].stats.strength)==before+1,"duplicate action applied once")
			check(session.state.players.values().filter(func(other):return other.id!=session.local_id).all(func(other):return not other.has("inventory") and not other.has("gold")),"private inventory omitted")
			# An old reliable action response must not undo a newer world snapshot.
			var revision=session.accepted_revision;var current_clock=session.state.clock
			var stale={"revision":revision-1,"state":{}}
			session.receive_snapshot(var_to_bytes(stale).compress(FileAccess.COMPRESSION_DEFLATE))
			check(session.accepted_revision==revision and session.state.clock==current_clock,"stale state cannot overwrite current world")
			check(session.state.players.values().filter(func(other):return other.id!=session.local_id).all(func(other):return not other.has("materials") and not other.has("potions") and not other.has("consumables") and not other.has("bag_positions")),"private quantities and bag positions omitted")
			if game!=null:
				game.toggle_skills();var tree=game.skill_tree;tree.choice="missing-network-skill";tree.invest_selected()
				check(tree.notice.text=="성장 확인 중…" and not tree.pending_change.is_empty(),"investment waits for authoritative result")
				await create_timer(.5).timeout
				check(tree.pending_change.is_empty() and not tree.notice.text.contains("성장 적용"),"rejected investment never displays success")
				game.toggle_skills()
		await create_timer(2.).timeout
		check(session.state.clock>before_clock+1.,"personal menu does not pause world")
		session.paused=false;session.act("ready","true")
		if host:
			var ready_deadline=Time.get_ticks_msec()+6000
			while Time.get_ticks_msec()<ready_deadline and not session.ready_players.values().all(func(value):return value):await create_timer(.1).timeout
			check(session.enter_floor(1),"ready party enters shared floor")
		await create_timer(3.).timeout
		check(session.sim.map.floor_number==1 and session.state.players.size()==6,"floor changes for every peer")
		# An actual guest request must use the host's room guards and inventory,
		# with personal claims surviving the next compressed world snapshot.
		if host:
			for enemy in session.sim.enemies.values():enemy.hp=0
			var site=session.sim.map.exploration_sites[0]
			for player in session.sim.players.values():player.pos=site.pos
			session.refresh();session.publish_snapshot()
		await create_timer(.7).timeout
		var site=session.state.exploration_sites[0]
		var gathered=int(session.state.players[session.local_id].materials.get(site.material,0))
		session.act("explore",site.generation+":"+site.id+":gather")
		session.act("explore",site.generation+":"+site.id+":gather")
		await create_timer(.7).timeout
		check(session.state.exploration_sites[0].claimed and int(session.state.players[session.local_id].materials.get(site.material,0))==gathered+3,"host-approved room reward once per human")
		if host:
			var hidden=session.sim.map.hidden_regions[0]
			for player in session.sim.players.values():player.pos=hidden.pos
			preload("res://scripts/hidden_rooms.gd").discover(session.sim);session.refresh();session.publish_snapshot()
		await create_timer(.7).timeout
		var hidden=session.sim.map.hidden_regions[0];var hidden_key=hidden.generation+":"+hidden.id
		check(session.state.revealed_regions.has(hidden.id),"secret clue shared across actual network")
		if not host:session.act("explore",hidden_key+":open")
		await create_timer(.7).timeout
		check(session.state.opened_regions.has(hidden.id) and session.sim.map.walkable(hidden.center),"guest request opens geometry on all peers")
		if host:
			for player in session.sim.players.values():player.pos=hidden.center
			session.refresh();session.publish_snapshot()
		await create_timer(.7).timeout
		var essence=int(session.state.players[session.local_id].materials.get("essence",0))
		session.act("explore",hidden_key+":collect");session.act("explore",hidden_key+":collect")
		await create_timer(.7).timeout
		check(int(session.state.players[session.local_id].materials.get("essence",0))==essence+3,"each human receives secret reward exactly once")
		check(session.save_game(),"checkpoint saves local character")
		check(session.parse_save(session.save_path())!=null,"checkpoint passes existing save validator")
	if game!=null and session.connected:
		game.coop_panel.open();await create_timer(.2).timeout;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(options.directory.path_join("coop-panel.png"))
		game.coop_panel.hide()
	# Keep guests alive until every process has observed the same destination.
	await create_timer(2.).timeout
	if session.connected:
		if host:
			check(session.change_map("town",0),"return fixture enters town")
			for player in session.sim.players.values():player.pos=preload("res://scripts/world_catalog.gd").resident_pos("shop")
			session.refresh();session.publish_snapshot()
			if session is ProbeSession:session.block_checkpoints=true
			await create_timer(3.).timeout
			check(await session.leave_room(),"host waits for final disk acknowledgements")
		else:
			var town_deadline=Time.get_ticks_msec()+5000
			while session.connected and session.sim.map.zone!="town" and Time.get_ticks_msec()<town_deadline:await create_timer(.1).timeout
			check(session.sim.map.zone=="town","trade fixture receives shared town")
			var before_player=session.state.players[session.local_id]
			var gold=int(before_player.gold);var potions=int(before_player.potions)
			var quote=preload("res://scripts/service_quote.gd").quote(before_player,"shop","potion",{"quantity":1})
			check(session.act("facility",JSON.stringify({"facility":"shop","operation":"potion","quantity":1})),"purchase immediately before departure")
			check(session.act("facility",JSON.stringify({"facility":"shop","operation":"mana_potion","quantity":1})),"new potion purchase before departure")
			check(session.act("power_potion"),"new potion consumption before departure")
			var endurance=int(session.state.players[session.local_id].stats.endurance)
			session.act("stat","endurance")
			if options.get("exit-mode","")=="host":
				var exit_deadline=Time.get_ticks_msec()+20000
				while session.connected and Time.get_ticks_msec()<exit_deadline:await create_timer(.1).timeout
				check(not session.connected and session.exit_result,"host exit preserves acknowledged client save")
			else:
				if session is ProbeSession:
					session.block_save=true
					check(not await session.leave_room() and session.connected,"failed disk acknowledgement keeps client in room")
					session.block_save=false;await create_timer(.2).timeout
				check(await session.leave_room(),"client leaves after final save acknowledgement")
			check(int(session.parse_save(session.save_path()).stats.endurance)==endurance+1,"action immediately before departure is durable")
			var final_save=session.parse_save(session.save_path())
			check(int(final_save.gold)==gold-int(quote.cost)-20 and int(final_save.potions)==potions+1,"purchase immediately before departure is durable")
			check(int(final_save.consumables.mana_potion)==4 and int(final_save.consumables.power_potion)==2,"new consumable purchase and consumption survive final authoritative checkpoint")
	print("COOP_NETWORK ",options.role," failures=",failures.size())
	if game!=null:game.queue_free()
	else:session.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
