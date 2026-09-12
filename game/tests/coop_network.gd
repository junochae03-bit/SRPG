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
	var test_floor=12 if options.has("environment") else 1
	var test_seed=531
	if options.has("environment"):
		for value in range(500,600):
			if preload("res://scripts/expedition_environment.gd").select(value+7919,test_floor).id==options.environment:test_seed=value;break
	p.highest_floor=test_floor;p.cleared_floor=test_floor-1
	var data=sim.persistent(1);data.world_seed=test_seed
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
			check(not session.enter_floor(test_floor) and session.sim.map.zone=="town","unready party cannot travel")
		session.act("select_goal",JSON.stringify({"id":"secret","floor":test_floor}))
		await create_timer(.5).timeout
		check(session.state.players[session.local_id].get("expedition_goal",{}).get("kind","")=="secret","each real peer selects an authoritative personal rumor")
		check(session.state.players.values().filter(func(other):return other.id!=session.local_id).all(func(other):return not other.has("expedition_goal")),"other players' goals are omitted from network snapshots")
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
			check(session.enter_floor(test_floor),"ready party enters shared floor")
		await create_timer(3.).timeout
		check(session.sim.map.floor_number==test_floor and session.state.players.size()==6,"floor changes for every peer")
		check(session.sim.map.environment==preload("res://scripts/expedition_environment.gd").select(test_seed+7919,test_floor),"every peer reconstructs the announced environment")
		if options.has("environment"):check(session.sim.map.environment.id==options.environment,"non-neutral environment exercised over ENet")
		# Known host-side fixtures verify the compressed wire fields separately
		# from the six-owner emission/occlusion model tests.
		if host:
			var record={"id":-101,"kind":"rat","name":"조사 표식","pos":session.sim.map.spawn,"max_hp":1,"level":1,"floor":test_floor,"raid":false}
			session.sim.inspection.record(record,session.sim.clock)
			record.pos=Vector2(-100,-100);session.sim.inspection.record(record,session.sim.clock)
			for peer in session.sim.players:
				session.sim.awareness.feedback[peer]={"serial":peer,"pos":session.sim.players[peer].pos,"radius":6,"until":session.sim.clock+5.}
			session.refresh();session.publish_snapshot()
		await create_timer(.6).timeout
		check(session.state.get("noise",{}).get("serial",0)==session.local_id,"compressed ENet snapshot carries only this peer's noise pulse")
		check(session.state.get("corpses",[]).size()==1 and session.state.corpses[0].pos==session.sim.map.spawn,"compressed ENet snapshot omits unseen corpse record")
		# Actual reliable tool requests: every peer owns one paid trap; replayed
		# sequence numbers cannot deploy or consume a second one.
		if host:
			for enemy in session.sim.enemies.values():enemy.hp=0
			for player in session.sim.players.values():
				player.pos=session.sim.map.spawn;player.aim=Vector2.RIGHT
				preload("res://scripts/inventory_model.gd").add_stack(player,"snare_trap",5)
			session.refresh();session.publish_snapshot()
		await create_timer(.6).timeout
		if host:
			check(session.act("snare_trap"),"host tool request accepted")
			check(not session.act("snare_trap"),"host rapid duplicate rejected")
		else:
			session.sequence+=1
			session.receive_action.rpc_id(1,session.sequence,"snare_trap","")
			session.receive_action.rpc_id(1,session.sequence,"snare_trap","")
		await create_timer(.8).timeout
		check(session.state.players[session.local_id].consumables.get("snare_trap",0)==4,"replayed tool sequence spends exactly one owned item")
		var deployed=session.state.get("tactical_tools",[])
		check(deployed.size()==6 and deployed.filter(func(tool):return tool.owner==session.local_id).size()==1,"compressed world has six tools with distinct owners")
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
		check(session.state.exploration_sites[0].claimed and int(session.state.players[session.local_id].materials.get(site.material,0))==gathered+int(site.gather_amount),"host-approved room reward once per human")
		if host:
			var challenge_site=session.sim.map.exploration_sites[4]
			for player in session.sim.players.values():player.pos=challenge_site.pos
			session.refresh();session.publish_snapshot()
		await create_timer(.7).timeout
		var challenge_site=session.state.exploration_sites[4]
		var challenge_key=challenge_site.generation+":"+challenge_site.id
		var challenge_essence=int(session.state.players[session.local_id].materials.get("essence",0))
		session.act("explore",challenge_key+":challenge");session.act("explore",challenge_key+":challenge")
		await create_timer(.7).timeout
		check(session.state.exploration_sites[4].challenge_state=="active","concurrent human requests share one active challenge")
		if host:
			var wave=session.sim.exploration_challenges[challenge_site.id]
			check(wave.size()==int(challenge_site.challenge_count) and session.sim.enemies.size()==23+wave.size(),"six simultaneous requests create only one wave")
			for id in wave:
				var enemy=session.sim.enemies[id]
				check(enemy.max_hp==roundi(enemy.solo_health*preload("res://scripts/party_rules.gd").health_factor(6)),"network wave starts at six-player health")
				enemy.hp=0
			session.refresh();session.publish_snapshot()
		await create_timer(.7).timeout
		session.act("explore",challenge_key+":collect");session.act("explore",challenge_key+":collect")
		await create_timer(.7).timeout
		check(session.state.exploration_sites[4].claimed and int(session.state.players[session.local_id].materials.get("essence",0))==challenge_essence+int(challenge_site.challenge_reward),"each human claims challenge reward exactly once over ENet")
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
		check(int(session.state.players[session.local_id].materials.get("essence",0))==essence+3+int((test_floor-1)/10),"each human receives secret reward exactly once")
		check(session.state.players[session.local_id].expedition_goal.stage==3,"personal rumor completes through shared opening and private reward over ENet")
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
			check(session.sim.players.values().all(func(player):return player.get("expedition_report",{}).get("first_floor",0)==test_floor),"host settled all six private expedition reports")
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
			check(before_player.get("expedition_report",{}).get("first_floor",0)==test_floor and before_player.expedition_report.elapsed>0.,"guest receives authoritative expedition report")
			check(session.state.players.values().all(func(player):return not player.has("expedition_journal") and (player.id==session.local_id or not player.has("expedition_report"))),"network snapshot hides authority ledger and other private reports")
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
			check(final_save.expedition_goal.kind=="secret" and final_save.expedition_goal.stage==3,"completed personal rumor survives authoritative departure checkpoint")
			check(int(final_save.gold)==gold-int(quote.cost)-20 and int(final_save.potions)==potions+1,"purchase immediately before departure is durable")
			check(int(final_save.consumables.mana_potion)==4 and int(final_save.consumables.power_potion)==2,"new consumable purchase and consumption survive final authoritative checkpoint")
	print("COOP_NETWORK ",options.role," failures=",failures.size())
	if game!=null:game.queue_free()
	else:session.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
