extends SceneTree
var session
var options={}
var failures=[]
func check(ok:bool,message:String):
	if not ok:failures.append(message);printerr(message)
func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:var pair=arg.trim_prefix("--").split("=",true,1);options[pair[0]]=pair[1]
	run.call_deferred()
func wait_for(predicate:Callable,label:String,timeout_ms:int=10000):
	var end=Time.get_ticks_msec()+timeout_ms
	while Time.get_ticks_msec()<end and not predicate.call():await create_timer(.05).timeout
	check(predicate.call(),label)
func barrier(stage:String):
	var file=FileAccess.open(options.directory.path_join(stage),FileAccess.WRITE);file.store_string("observed");file.close()
	await wait_for(func():return range(6).all(func(i):return FileAccess.file_exists(options.directory.get_base_dir().path_join(str(i)+"/"+stage))),"six observers "+stage)
func run():
	session=preload("res://scripts/coop_session.gd").new();session.name="Session";root.add_child(session);session.save_directory=options.directory
	var sim=preload("res://scripts/simulation.gd").new(531,"town");var p=sim.add_player(1,"연계 검사");p.level=100;p.tutorial_done=true;p.highest_floor=12;p.cleared_floor=11;sim.recalculate(p)
	var saved=sim.persistent(1);saved.world_seed=531;check(session.write_save(saved,session.save_path()),"isolated save")
	var host=options.role=="host"
	check(session.host_room(1,int(options.port)) if host else session.join_room("127.0.0.1",1,int(options.port)),"real connection")
	if options.role=="overflow":
		await wait_for(func():return not session.connected and session.network_role=="offline","capacity rejects seventh",15000)
		var marker=FileAccess.open(options.directory.path_join("capacity_checked"),FileAccess.WRITE);marker.store_string("checked");marker.close()
		print("COMBAT_LIFECYCLE_NETWORK overflow failures=",failures.size());session.queue_free();await process_frame;quit(0 if failures.is_empty() else 1);return
	if host:print("HOST_READY")
	await wait_for(func():return session.connected and session.state.players.size()==6,"six actual peers")
	if host:
		print("SIX_READY")
	await wait_for(func():return FileAccess.file_exists(options.directory.get_base_dir().path_join("6/capacity_checked")),"capacity probe finishes while room stays full",18000)
	if host:
		check(session.change_map("cave",12),"host creates dungeon fixture")
		for actor in session.sim.players.values():
			actor.pos=Vector2(session.sim.map.rooms[1]);actor.invulnerable=100.;actor.constellation_state.last_skill="blade";actor.constellation_state.last_time=30.;actor.constellation_state.move_time=30.;actor.constellation_state.support_time=30.
			session.sim.combat.jobs.buff(actor,"attack",.2,30.)
			actor.lifecycle_stage=1
			session.sim.enemies.clear()
		session.refresh();session.publish_snapshot()
	await wait_for(func():return session.state.players.get(1,{}).get("lifecycle_stage",0)==1,"received initial phase")
	check(session.state.players.values().all(func(actor):return actor.constellation_state.last_time>0 and not actor.job_state.buffs.is_empty()),"all peers see initial personal buffs")
	await barrier("primed")
	if host:
		var victim=session.sim.players[1];victim.hp=1;victim.invulnerable=0.
		var attacker=session.sim.spawn_enemy("rat",victim.pos+Vector2(.4,0),12);attacker.damage=1000.;attacker.speed=0.;attacker.cooldown=100.
		session.sim.monster_attacks.begin(attacker,victim.pos);attacker.windup=.05
		await wait_for(func():return session.sim.players[1].get("down_time",0)>0,"actual enemy windup and lethal impact")
		session.sim.enemies.clear();session.sim.players[1].lifecycle_stage=2;session.refresh();session.publish_snapshot()
	await wait_for(func():return session.state.players.get(1,{}).get("lifecycle_stage",0)==2,"received downed phase")
	var down=session.state.players[1]
	check(down.hp==0 and down.down_time>0 and down.constellation_state.last_time==0 and down.constellation_state.move_time==0 and down.constellation_state.support_time==0 and down.job_state.buffs.is_empty(),"every peer sees cleared downed state")
	check(session.state.players.values().filter(func(actor):return actor.id!=1).all(func(actor):return actor.constellation_state.last_time>0 and not actor.job_state.buffs.is_empty()),"other five players keep buffs")
	await barrier("downed")
	var rescuer=session.state.players.keys().filter(func(id):return id!=1).min()
	if session.local_id==rescuer:check(session.act("interact"),"real guest rescue action")
	await wait_for(func():return session.state.players.get(1,{}).get("hp",0)>0,"replicated rescue completes")
	var revived=session.state.players[1]
	check(revived.down_time==0 and revived.constellation_state.last_time==0 and revived.constellation_state.move_time==0 and revived.constellation_state.support_time==0 and revived.job_state.buffs.is_empty(),"rescue never restores old state on any peer")
	await barrier("rescued")
	if host:check(session.change_map("town",0),"party returns to town")
	await wait_for(func():return session.sim.map.zone=="town","all peers receive town")
	check(session.state.players.values().all(func(actor):return actor.constellation_state.last_time==0 and actor.constellation_state.move_time==0 and actor.constellation_state.support_time==0 and actor.job_state.buffs.is_empty()),"map transition resets every personal effect")
	await barrier("returned")
	var departing=session.state.players.keys().filter(func(id):return id!=1).min()
	var last_survivor=options.get("last-survivor","")=="true"
	if host:
		check(session.change_map("cave",12),"disconnect dungeon fixture")
		session.sim.enemies.clear()
		for actor in session.sim.players.values():
			actor.pos=Vector2(session.sim.map.rooms[1]);actor.invulnerable=100.;actor.lifecycle_stage=3
			session.sim.combat.jobs.buff(actor,"attack",.2,30.)
			if last_survivor and actor.id!=departing:actor.hp=0;actor.down_time=60.
		var boss=session.sim.spawn_enemy("golem",Vector2(session.sim.map.rooms[1])+Vector2(3,0),12,true)
		boss.hp-=10;boss.cooldown=100.;boss.stagger.engaged=true
		for id in [1,departing]:session.sim.combat.launch(session.sim.players[id],"staff",Vector2.RIGHT,10,50,0.,0.)
		session.refresh();session.publish_snapshot()
	await wait_for(func():return session.state.players.get(1,{}).get("lifecycle_stage",0)==3,"disconnect phase replicated")
	check(session.state.projectiles.any(func(shot):return shot.owner==departing) and session.state.projectiles.any(func(shot):return shot.owner==1),"both owners have pending shots before disconnect")
	await barrier("disconnect_ready")
	if session.local_id==departing:
		# Drop transport directly: no orderly departure action or manual peer_left call.
		session.network_peer.close();session.network_role="offline";session.connected=false
		print("COMBAT_LIFECYCLE_NETWORK guest failures=",failures.size());session.queue_free();await process_frame;quit(0 if failures.is_empty() else 1);return
	await wait_for(func():return session.state.players.size()==5 and not session.state.players.has(departing),"actual disconnected peer removed")
	check(not session.state.projectiles.any(func(shot):return shot.owner==departing),"departed owner shots removed over ENet")
	var boss=session.state.enemies.values()[0]
	if last_survivor:check(boss.hp==boss.max_hp,"first peer-removal snapshot contains the reset boss")
	else:
		check(boss.hp<boss.max_hp,"living engaged party keeps encounter")
		check(session.state.projectiles.any(func(shot):return shot.owner==1) and not session.state.players[1].job_state.buffs.is_empty(),"remaining owner effects survive peer disconnect")
	# All snapshots and the guest action above travel through the production ENet session.
	# Shared files synchronize the test harness only; they contain no game state.
	await create_timer(.3).timeout
	print("COMBAT_LIFECYCLE_NETWORK ",options.role," failures=",failures.size())
	session.network_role="offline";session.connected=false;root.multiplayer.multiplayer_peer=null;session.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
